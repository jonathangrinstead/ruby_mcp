# RubyMCP conventions

Apply the [mmtm Rails style guide](https://github.com/mmtmio/mmtm-rails-style-guide), reading its condensed `CLAUDE.md` and relevant detailed guides. Audited against commit `94c91522fd3c15b2f88374cb42ab2dde38662edd`.

## Gem-specific application

- Keep library code in `lib/rubymcp` and Rails generators in `lib/generators`. The host app owns its models, policies, credentials and frontend; do not impose the full mmtm application stack.
- Preserve Rack, MCP SDK and Rails generator method names and signatures. Use explicit `self.` for method calls in method bodies and generator ERB expressions; retain conventional declaration DSLs such as `param`, `layout` and `class_option`.
- Use single-quoted Ruby strings, explicit arrays, full hash values and `collect`. Retain `String#inspect` when embedding dynamic values into generated Ruby: correct escaping takes precedence over quote style.
- Keep SQLite and subprocess-based generated-app tests. Separate processes verify installation and real OAuth behaviour for both Devise `Account` and `User` without global Rails state leaking between examples. These are generator integration tests, not substitutes for feature specs in consuming apps.
- Tests use RSpec, locals and progressive scenarios. Put object specs in `spec/objects`, JSON endpoint specs in `spec/requests`, and installation specs in `spec/generators`. Hand-built disposable app fixtures do not need FactoryBot or schema annotations.
- Keep development fixture secrets visibly synthetic. User credentials belong to the host application's credentials store. Rake tasks may print client IDs and setup instructions, never bearer tokens or client secrets.
- Preserve existing frozen-string comments; do not require them on new files. No Percy or ERB HTML lint setup is needed unless this gem gains its own view templates.

## Verification

Run `bundle exec rspec`, `bundle exec rubocop` and `git diff --check`. RuboCop includes static generator templates; `.rb.tt` templates must be verified through generated-app specs because they are ERB source, not standalone Ruby.

Use the default `main` branch for PRs unless the task says otherwise; this repository has no sprint branch or required Linear ticket. Include concrete changes, validation and any material gem-specific exceptions in the PR description.
