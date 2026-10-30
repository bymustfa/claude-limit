# Security policy

## Supported versions

ClaudeLimit has no tagged releases yet. Security fixes go to the `main` branch only, so please make
sure you are on the latest `main` before reporting.

## Reporting a vulnerability

Please do **not** open a public issue for security problems.

Report them privately through GitHub instead:
[Report a vulnerability](https://github.com/bymustfa/claude-limit/security/advisories/new)
(Security tab → **Report a vulnerability**).

Include what you found, how to reproduce it and what an attacker could do with it. You should get a
first reply within a week. Once a fix is on `main`, the advisory is published with credit to you,
unless you prefer to stay anonymous.

## Scope

ClaudeLimit runs the local `claude` CLI and stores its readings in
`~/Library/Application Support/ClaudeLimit/usage.db`. It makes no network requests of its own.
Relevant reports include, for example:

- the app running a command other than the intended `claude -p "/usage"`,
- the app reading or writing files outside its data folder,
- anything that leaks usage data off the Mac.

Problems in Claude Code itself should be reported to Anthropic, not here.
