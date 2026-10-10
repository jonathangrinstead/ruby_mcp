# Upgrading to the tools-and-OAuth MVP

This change removes APIs introduced in the earlier MVP. Ordinary tools, their `visible?` hook, the `/mcp` endpoint, OAuth configuration and `rubymcp_clients.yml` remain supported. No database migration is required for an app using only tools and OAuth.

## Removed APIs

- `RubyMCP::BackgroundTool`, `RubyMCP::Background` and its task model, execution job, status and cancellation tools.
- The `rubymcp:background` generator and `rubymcp:tool --background` option.
- `task_owner`, `task_context_dump` and `task_context_load` configuration.
- `RubyMCP::Resource`, `RubyMCP::ResourceTemplate`, `RubyMCP::ResourceContent` and `RubyMCP::Prompt`.
- The resource, resource template and prompt generators and their generated base classes.
- The shared `RubyMCP::Component` module. Context, discovery and visibility now live directly on `RubyMCP::Tool`.

## If you installed background tasks

Before upgrading, finish or cancel outstanding work and stop workers processing RubyMCP tasks. Remove the generated `rubymcp_background.rb` initializer, `rubymcp_background.rake` task file and `ApplicationBackgroundTool`; remove or convert tools inheriting from it to ordinary `ApplicationTool` classes. Remove references to `rubymcp_task_status` and `rubymcp_task_cancel` from clients.

The gem no longer manages background execution, progress or cancellation. Longer-running work can remain part of your application's own job system, with app-specific tools if needed. Remove Sidekiq or Active Job dependencies only if your application does not otherwise use them.

Existing task tables and previously applied migrations are **not deleted automatically**. Retain stored data as needed, then create an application migration to drop unused task tables when you are ready.

## If you installed resources or prompts

Remove the generated base classes and subclasses in `app/resources`, `app/resource_templates` and `app/prompts` before booting the new version. Convert any required functionality into tools: for example, a `startup_profile` tool can return a profile previously exposed as a resource.

Refresh your AI client's tool list after upgrading. Existing OAuth client registrations and tool names remain unchanged.
