# RubyMCP

**Give AI assistants access to your Rails app.**

Expose tools, resources and prompts with familiar Ruby classes. RubyMCP handles Rails integration and authentication setup; the official [MCP Ruby SDK](https://github.com/modelcontextprotocol/ruby-sdk) handles the protocol.

## Show me the code

```ruby
# app/tools/find_startup_tool.rb
class FindStartupTool < ApplicationTool
  description 'Find a startup by name'
  param :name, type: :string, required: true

  def call(name:)
    startup = self.current_account.startups.find_by!(name: name)

    { name: startup.name, website: startup.website }
  end
end
```

That's a tool. RubyMCP discovers it automatically, validates its arguments and turns the return value into an MCP response. Your app supplies the models and permissions.

## Features

- **Tools:** expose your app's behaviour through ordinary Ruby methods.
- **Resources:** share data through fixed URIs or record-specific templates.
- **Prompts:** define reusable instructions with named arguments.
- **Authentication:** generate a Devise + Doorkeeper sign-in and consent flow.
- **Visibility:** control which tools, resources and prompts each account can access.
- **Background work:** optional Sidekiq jobs with saved progress, results and cancellation through polling tools.
- **Rails conventions:** generators, automatic discovery and development reloading.

## Get started

Requires Ruby 3.2+ and Rails 7.2–8.x. This is an early MVP, not yet published to RubyGems. Install from GitHub:

```ruby
# Gemfile
gem 'rubymcp', github: 'jonathangrinstead/ruby_mcp', branch: 'main'
```

```sh
bundle install
bin/rails generate rubymcp:install
bin/rails generate rubymcp:tool find_startup
```

Replace the generated tool with your application logic, as above. Restart Rails after installation. Your MCP endpoint is `/mcp` and uses Streamable HTTP.

**Requests are rejected until authentication is configured.** Use the Devise integration below, or supply your own credential validation in `config/initializers/rubymcp.rb`. A custom context callback returns `{ current_account: account }` on success or `nil` to reject access; add your public hostname to `config.allowed_hosts`.

## Connect with Devise

For an existing Devise app, add the supported Doorkeeper version:

```ruby
# Gemfile
gem 'doorkeeper', '= 6.0.0.beta2'
```

```sh
bundle install
bin/rails generate rubymcp:devise Account --issuer=https://app.example.com
bin/rails db:migrate
```

Use `User` instead of `Account` if that is your Devise model. The generator targets a full Rails app with browser sessions, integer account IDs and no existing Doorkeeper setup. The exact beta is currently required for OAuth discovery and resource indicators.

Add your client's exact HTTPS callbacks to `config/rubymcp_clients.yml`:

```yaml
my_client:
  name: My AI client
  redirect_uris:
    - https://client.example/callback
```

The callback above is a placeholder. Replace it with the URL supplied by your client, then run:

```sh
bin/rails rubymcp:clients:sync
```

Restart Rails. Configure your client with `https://app.example.com/mcp` and the printed client ID; leave the client secret empty. Users sign in to your app and approve access. Keep YAML keys stable to preserve client IDs when callbacks change.

Authentication identifies the account. Keep account-scoped queries and record-level permission checks in your tools. The MCP endpoint does not run your application's controller callbacks.

## More than tools

```sh
bin/rails generate rubymcp:resource portfolio
bin/rails generate rubymcp:resource_template startup
bin/rails generate rubymcp:prompt compare_startups
```

Restrict any component by defining its visibility hook:

```ruby
def self.visible?(context:)
  context.fetch(:current_account).admin?
end
```

Hidden components are excluded from discovery and direct invocation through the endpoint.

Background tools are optional and require Active Record, Active Job, Sidekiq and Redis. The [background generator](lib/generators/rubymcp/background_generator.rb) creates their configuration and database migration. Progress is retrieved through `rubymcp_task_status`; this MVP does not implement the experimental MCP Tasks extension.

## Status

The MVP includes protocol and generated-app tests. Live external-client and Redis-worker verification is still pending. Automatic OAuth client registration, streaming and resource subscriptions are not included yet. Fuller documentation will follow.

## Contributing

Issues and pull requests are welcome. To run the checks:

```sh
bundle install
bundle exec rspec
bundle exec rubocop
```

## License

[MIT](LICENSE).
