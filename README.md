# RubyMCP

Write tools like Rails classes. RubyMCP handles discovery, request context and Ruby results; the official [MCP Ruby SDK](https://github.com/modelcontextprotocol/ruby-sdk) handles the protocol.

An unpublished MVP. `rubymcp` is a working name; registry availability has not been checked.

```ruby
class FindInvoiceTool < ApplicationTool
  description 'Find an invoice by its number'

  param :number, type: :string, required: true

  def call(number:)
    invoice = self.current_account.invoices.find_by!(number: number)

    { number: invoice.number, status: invoice.status, total: invoice.total }
  end
end
```

## Install

Requires Ruby 3.2+ and Rails 7.2–8.x. The development suite uses Rails 8.1. The SDK dependency is pinned to the 1.4 series.

Until published, point a Rails app at this checkout:

```ruby
# Gemfile
gem 'rubymcp', path: '/absolute/path/to/rubymcp'
```

```sh
bundle install
bin/rails generate rubymcp:install
bin/rails generate rubymcp:tool greeting
```

The install generator creates `ApplicationTool`, an initializer and a `/mcp` route. Restart the Rails server after installation so Rails picks up `app/tools` as an autoload root.

Tools are discovered automatically under `app/tools`, including namespaces, and refreshed when Rails reloads. `GreetingTool` becomes `greeting`; `Admin::GreetingTool` becomes `admin_greeting`. Use the SDK's `tool_name 'custom_name'` to override this. Base classes call `abstract!` to stay out of discovery.

## First request

The generated initializer rejects every request until you configure access. To try a **public greeting tool on localhost**, explicitly replace the context callback:

```ruby
RubyMCP.configure do |config|
  config.name = 'my_app'
  config.context = ->(_request) { {} }
end
```

The generated greeting tool accepts a `message` argument and echoes it:

```sh
curl http://localhost:3000/mcp \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"greeting","arguments":{"message":"Hello"}}}'
```

Point an MCP client's Streamable HTTP connection at `http://localhost:3000/mcp`. The SDK also handles normal client initialisation and `tools/list`.

## Authentication and authorisation

The callback receives a `Rack::Request`. Return a hash of trusted context, or `nil` / `false` for HTTP 401. It runs on every request, including discovery. It must validate credentials rather than trusting caller-provided account IDs.

For example, when your app already has an `ApiToken.authenticate` method that validates a bearer token and returns an account:

```ruby
RubyMCP.configure do |config|
  config.allowed_hosts = ['app.example.com']
  config.context = lambda do |request|
    scheme, token = request.get_header('HTTP_AUTHORIZATION').to_s.split(' ', 2)
    if scheme&.casecmp?('Bearer') && token
      account = ApiToken.authenticate(token)
      { current_account: account } if account
    end
  end
end
```

`ApiToken.authenticate` is application code, not a method supplied by this gem. Context can contain any symbol-keyed values. Tools access `self.context.fetch(:organisation)` or the convenience method `self.current_account`.

The endpoint is a Rack mount: application controller callbacks and controller CSRF protection do not run. Use explicit token authentication for remote tools. For a browser sign-in and consent flow, use the optional Devise + Doorkeeper integration below.

Authorisation belongs in the tool or shared `ApplicationTool`. For Pundit, call `Pundit.authorize(self.current_account, invoice, :show?)`, or include `Pundit::Authorization` in `ApplicationTool` and define `pundit_user`. Account-scoped queries should still use the authenticated account's associations. Components are visible to authenticated callers by default; use the visibility hook below to restrict discovery and invocation.

SDK host/origin checks remain enabled. Add your deployment hostname to `allowed_hosts`. `allowed_origins` can admit additional trusted browser origins; it is not a CORS implementation.

## Devise + Doorkeeper

For an existing Rails app with Devise, RubyMCP can generate an OAuth connection flow. Users follow the client's connection link, sign in with their existing Devise account, approve access, and return to the client. Tools continue to use `self.current_account`.

This optional integration is tested with **Devise 5.0.3 and Doorkeeper 6.0.0.beta2**. Doorkeeper's resource indicators and authorisation-server discovery are prerelease features; the generator deliberately requires that exact beta. These gems are not runtime dependencies for apps using another authentication method.

```ruby
# Gemfile — alongside your existing devise and rubymcp entries
gem 'doorkeeper', '= 6.0.0.beta2'
```

```sh
bundle install
bin/rails generate rubymcp:install # Once, if not already installed
bin/rails generate rubymcp:devise Account --issuer=https://app.example.com
bin/rails db:migrate
```

Pass `User` instead of `Account` if that is your existing Devise model. The generator reads its Devise mapping, including the authentication scope. It does not install Devise, create another account model, or change your password policy. `self.current_account` returns the authenticated record even when the underlying model is `User`.

`--issuer` is the public origin clients reach, without a path. It must use HTTPS except for localhost development. The generated issuer values are literal deployment settings: change both generated initializers together for other environments. This integration targets the default `/mcp` endpoint, a full Rails application with browser sessions, one Devise model, and integer account IDs.

The generator creates:

- Doorkeeper table, PKCE and resource-indicator migrations.
- OAuth configuration using your Devise sign-in, S256 PKCE and one-hour access tokens.
- A RubyMCP bearer-token authenticator and public resource-discovery route.
- A consent controller using your application's layout, plus a readable permission description.
- `config/rubymcp_clients.yml` and a `rubymcp:clients:sync` task for developer-managed client registration.

Restart the app after generation. If your application layout depends on app-specific controller helpers, adapt the generated `ConnectorAuthorizationsController` accordingly. It inherits Doorkeeper's controller and CSRF protection, not your `ApplicationController` callbacks. Record-level authorisation remains in your tools.

### Configure OAuth clients

Edit `config/rubymcp_clients.yml` using the exact HTTPS callback URLs supplied by each MCP client. These example URLs are placeholders:

```yaml
claude:
  name: Claude
  redirect_uris:
    - https://client.example/callback
    - https://client.example/another-callback

another_client:
  name: Another client
  redirect_uris:
    - https://another.example/callback
```

Apply the file to the current environment's database:

```sh
bin/rails rubymcp:clients:sync
```

The command prints each public client ID. Supply that ID in the client's OAuth settings with `https://app.example.com/mcp` as the connector URL; leave the client secret empty. The client proves possession through PKCE. These IDs are public configuration, not secrets.

Keep YAML keys stable: `claude` receives the ID `rubymcp_claude`. Changing its display name or callbacks preserves its ID. Run sync after edits and in each deployed environment. The file is plain YAML, without ERB or aliases. Each entry requires a name and at least one exact HTTPS callback; wildcards, fragments and embedded credentials are rejected.

Sync validates the file and applies database updates in a transaction. Removed callback URLs stop being accepted for new authorisations. Removing a whole client entry does **not** delete the registration or revoke existing connections; use Doorkeeper's revocation controls for that.

For an existing RubyMCP installation, generate only the new configuration:

```sh
bin/rails generate rubymcp:clients
```

To manage a previously registered client, add its existing public ID:

```yaml
claude:
  name: Claude
  client_id: existing-public-client-id
  redirect_uris:
    - https://client.example/callback
```

That ID must already exist and belong to a public client with only the `mcp` scope. The earlier `rubymcp:register_client` task remains available for one-off registrations.

For Claude, use the current callback URL and advanced OAuth settings described in its [custom connector guide](https://support.claude.com/en/articles/11503834-building-custom-connectors-via-remote-mcp). This release supports preregistered clients; it does not provide dynamic registration or Client ID Metadata Documents. End users do not generate or paste access tokens. A live Claude connection still needs verification against a deployed, publicly reachable HTTPS app.

### Access and disconnection

Access requires a non-expired, non-revoked bearer token with the `mcp` scope and the exact MCP resource in its audience. Deleted or inactive Devise accounts are rejected. Cookies and query-string tokens are not accepted at `/mcp`. Token secrets are hashed in the database. Refresh tokens rotate through Doorkeeper, including invalidation of the previous refresh token when its replacement access token is used.

Doorkeeper provides `/oauth/revoke` and the user's `/oauth/authorized_applications` page for revoking connections. Its application-administration routes are omitted; client registration is a developer task. The generated scope allows all exposed tools with the account's existing permissions, so it is not a read-only scope and does not replace policies in individual tools.

Discovery is served at `/.well-known/oauth-protected-resource/mcp` and `/.well-known/oauth-authorization-server`. Unauthenticated MCP responses include the OAuth discovery challenge. An authenticated token missing the `mcp` scope receives HTTP 403.

### Existing Doorkeeper installations

The generator stops before modifying an existing Doorkeeper configuration or migration. To integrate manually, review the [generated OAuth configuration](lib/generators/rubymcp/templates/devise/doorkeeper.rb.tt) and merge its settings into your provider. Add the PKCE and resource-indicator migrations if absent, enable S256 PKCE, configure your existing Devise resource-owner authenticator, and restrict the MCP resource and scope. Non-integer account IDs need matching `resource_owner_id` column types in Doorkeeper's migrations.

Set `RubyMCP.configuration.context` to `RubyMCP::DeviseAuthentication.new(model: 'Account', issuer: 'https://app.example.com')`, require `rubymcp/devise_authentication`, and add the generated resource-metadata route. Adapt the [generated routes and files](lib/generators/rubymcp/devise_generator.rb) for your provider. Re-test existing OAuth clients before changing shared provider settings; the automatic setup is intended for a new provider dedicated to this integration.

## Parameters and results

```ruby
param :query, type: :string, required: true, description: 'Search phrase'
param :limit, type: :integer, minimum: 1, maximum: 100
param :status, type: :string, enum: ['draft', 'paid']
param :tags, type: :array, items: { type: 'string' }
```

Parameters are optional unless `required: true`. Put runtime defaults in the method signature, such as `def call(query:, limit: 20)`. Schema `default:` is metadata and does not supply a Ruby argument. Additional JSON Schema keywords pass through to the SDK. Full `input_schema` and `output_schema` declarations are available too; use one input declaration style per tool. The `param` DSL rejects unknown arguments.

Return a string for text content, or JSON-compatible Ruby data for structured content plus a JSON text fallback. Select the fields you expose; convert Active Record objects yourself. Return `MCP::Tool::Response` directly for richer SDK content. Declared output schemas are validated by the endpoint.

Each invocation creates a fresh tool instance. Context is scoped to its HTTP request and is never stored on a shared server. Inherited parameter schemas are copied, so a subclass cannot mutate its parent's declarations.

Raise `RubyMCP::Tool::Error, 'A helpful message'` for an expected failure a client should see. Unexpected exceptions are reported through `Rails.error` and returned as generic SDK protocol errors. For example, rescue a record lookup failure inside a tool if you want a friendly “Invoice not found” result.

## Visibility

Tools, resources, resource templates and prompts accept a class-level visibility hook. It receives trusted authentication context on every request:

```ruby
class ModerateStartupTool < ApplicationTool
  description 'Moderate a startup submission'
  param :id, type: :integer, required: true

  def self.visible?(context:)
    context.fetch(:current_account).admin?
  end

  def call(id:)
    startup = self.current_account.startups.find(id)
    Pundit.authorize(self.current_account, startup, :moderate?)
    # Apply the app's moderation action here.
    { id: startup.id }
  end
end
```

Hidden components are omitted from discovery and cannot be invoked through the endpoint. Visibility defaults to true for authenticated callers. Define shared rules on the corresponding application base class. Visibility controls the capability; keep record-level policies and account-scoped queries inside `call`. Do not derive roles from tool arguments or other unverified request data.

## Resources and resource templates

Resources expose addressable context; tools perform operations. Generate a fixed resource or a template for record-specific URIs:

```sh
bin/rails generate rubymcp:resource portfolio
bin/rails generate rubymcp:resource_template startup
```

```ruby
# app/resources/portfolio_resource.rb
class PortfolioResource < ApplicationResource
  uri 'app://portfolio'
  description 'The signed-in account’s startup portfolio'

  def call
    self.current_account.startups.limit(50).collect do |startup|
      { id: startup.id, name: startup.name }
    end
  end
end

# app/resource_templates/startup_resource_template.rb
class StartupResourceTemplate < ApplicationResourceTemplate
  uri_template 'app://startups/{id}'
  description 'A startup profile visible to the signed-in account'

  def call(id:)
    startup = self.current_account.startups.find(id)
    { id: startup.id, name: startup.name }
  end
end
```

A client lists fixed resources using `resources/list`, templates using `resources/templates/list`, and reads either using `resources/read` with a concrete URI such as `app://startups/42`. Templates are not automatically expanded into a list of every database record. The SDK matches simple `{variable}` segments; values arrive as strings without percent-decoding.

Strings become text contents; ordinary Ruby hashes and arrays become JSON contents. Set `mime_type` when needed. Return `MCP::Resource::TextContents`, `MCP::Resource::BlobContents`, or an array of those for explicit SDK content. Each call receives a fresh instance and `self.current_account`. Resource subscriptions are not enabled.

## Prompts

Prompts provide reusable instructions that a supporting client can offer to its user:

```sh
bin/rails generate rubymcp:prompt compare_startups
```

```ruby
class CompareStartupsPrompt < ApplicationPrompt
  description 'Compare two startups using consistent investment criteria'
  param :first, required: true
  param :second, required: true

  def call(first:, second:)
    "Compare #{first} and #{second}. Use available startup tools and resources. " \
      'Assess market, traction, team, funding and risks. Cite evidence and identify missing data.'
  end
end
```

Clients use `prompts/list` and `prompts/get`. MCP prompt arguments are strings; missing required arguments, undeclared arguments and non-string values are rejected. A returned string becomes one user message. For multiple messages, return an array of `MCP::Prompt::Message` objects, or return `MCP::Prompt::Result` directly. Client support determines how resources and prompts appear in its UI.

Generators create `ApplicationResource`, `ApplicationResourceTemplate` and `ApplicationPrompt` as needed and preserve existing base files. All four component directories are discovered and refreshed on Rails reload. Restart the server after first creating a new directory so Rails adds it as an autoload root.

## Background tools and progress

Background execution is optional. It requires Active Record, Active Job, Sidekiq and Redis; ordinary tools, resources and prompts do not require those dependencies. Add Sidekiq to your app if it is not already installed:

```ruby
# Gemfile
gem 'sidekiq', '~> 8.0'
```

```sh
bundle install
bin/rails generate rubymcp:background Account # Or your existing User model
bin/rails db:migrate
bin/rails generate rubymcp:tool compare_startups --background
bundle exec sidekiq -q default
```

Configure Redis as you normally would for Sidekiq. The generated initializer selects Sidekiq for RubyMCP's job class without changing other application jobs. Restart the app and workers after installation.

```ruby
class CompareStartupsTool < ApplicationBackgroundTool
  description 'Compare startups in the background. Check rubymcp_task_status for the result.'
  param :first_id, type: :integer, required: true
  param :second_id, type: :integer, required: true

  def call(first_id:, second_id:)
    first = self.current_account.startups.find(first_id)
    self.report_progress(1, total: 2, message: 'Loaded the first startup')
    second = self.current_account.startups.find(second_id)
    self.report_progress(2, total: 2, message: 'Loaded both startups')
    { first: first.name, second: second.name }
  end
end
```

Calling the tool creates a database task and queues its ID. The immediate structured result contains `task_id`, `status` and `poll_after_seconds`. Call `rubymcp_task_status` with that ID to read progress and, once completed, the final SDK tool response under `result`. `rubymcp_task_cancel` requests cancellation. These are ordinary MCP tools: this release does **not** implement or advertise the experimental MCP Tasks extension, push progress notifications, or require clients to support that extension. The assistant/client must make status calls to observe progress.

`output_schema`, if supplied on a background tool, describes its immediate task snapshot, not the final nested result. Validate your final business result within the tool. Shared `ApplicationTool` methods do not automatically apply to `ApplicationBackgroundTool`; put background visibility and helpers on that base class or share a concern.

The generated context callbacks save the account ID and reload its record in the worker, rejecting inactive Devise accounts. Only IDs are passed to the queue. Tool visibility is checked again before execution and before reading results. Another account cannot read or cancel the task. In tenant-scoped or other custom authentication systems, adapt **all three** callbacks (`task_owner`, `task_context_dump`, `task_context_load`) to preserve and revalidate the complete authorisation boundary, including tenant or OAuth client identity when relevant. Store only JSON-compatible context data, not tokens or request objects.

Cancellation is cooperative: queued work is skipped; running work stops at its next `report_progress` call and its eventual result cannot overwrite the cancelled state. Earlier side effects cannot be undone. Re-delivering an already claimed task does not execute it again. Application exceptions produce a failed task and are reported through `Rails.error`; unexpected exception details are hidden from clients. Failed tasks are not automatically re-executed. A worker killed mid-task can leave it marked working until expiry; inspect worker failures before starting replacement work. This is not an exactly-once guarantee for business side effects.

Task access expires after 24 hours. Schedule `bin/rails rubymcp:tasks:prune` using your app's existing scheduler to delete expired arguments and results. Background tools cannot be enqueued inside an open database transaction: the durable record must be committed before a separate worker reads it.

## Scope

This MVP exposes tools, prompts, resources and resource templates over stateless Streamable HTTP with JSON responses. It uses a fresh SDK server/transport per request. It supports the SDK's tool metadata, annotations, schemas and explicit responses. Optional background tools use a durable database record and Active Job/Sidekiq with status polling. It does not add stdio, long-lived sessions, subscriptions, streaming, or server-to-client interactions. The endpoint disables subscription listening and does not advertise support for it.

## Development

```sh
bundle install
bundle exec rspec
bundle exec rubocop
gem build rubymcp.gemspec
```

Specs exercise actual SDK requests, request context isolation, reloading and generated application boot. OAuth tests create temporary SQLite databases and exercise real Devise sign-in, consent, PKCE, resource binding, refresh, revocation and rejection paths for both Account and User models. Background integration tests exercise the Sidekiq adapter in fake mode, including execution, progress, ownership, cancellation and permission changes. No live Redis server or external MCP client is exercised.