# Contributing

Thanks for wanting to help. Issues and pull requests are welcome, in English or Turkish.

## Before you start

- **Bugs and ideas:** open an issue using one of the templates. For anything bigger than a small
  fix, please open an issue first so we can agree on the approach before you write code.
- **Security problems:** do not open an issue; follow [SECURITY.md](SECURITY.md).

## Setup

You need macOS 14 or later, Xcode 26 or later and a logged-in
[Claude Code](https://docs.claude.com/en/docs/claude-code).

```bash
git clone https://github.com/bymustfa/claude-limit.git
cd claude-limit
swift build
swift test
```

If `xcode-select -p` points at the Command Line Tools, prefix the commands with
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

`swift run ClaudeLimit` starts the app without the `.app` bundle (English UI only). To try the real
bundle with translations, run `./scripts/build-app.sh` and open `dist/ClaudeLimit.app`.

## Where things live

- `Sources/ClaudeLimitCore` – parsing the `/usage` output, storage and the weekly/daily model.
  Changes here should come with unit tests in `Tests/ClaudeLimitCoreTests`.
- `Sources/ClaudeLimit` – the SwiftUI menu bar app.
- `Resources/*.lproj` – translations.

## Adding a language

1. Copy `Resources/en.lproj/Localizable.strings` to `Resources/<code>.lproj/Localizable.strings`
   and translate the values (keep the keys as they are).
2. Add the code to the `CFBundleLocalizations` list in `scripts/build-app.sh`.
3. Build the app and check the panel with your macOS language set to the new language.

## Pull requests

- Branch from `main` and keep each PR to one change.
- Make sure `swift build` and `swift test` pass.
- For UI changes, add a screenshot to the PR description.
- Use short, imperative commit messages ("Fix reset time parsing").
- PRs are squash-merged, so the PR title becomes the commit message on `main`.

By contributing you agree that your work is released under the [MIT License](LICENSE) and that you
follow the [Code of Conduct](CODE_OF_CONDUCT.md).
