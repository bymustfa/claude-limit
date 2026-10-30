# ClaudeLimit

**English** · [Türkçe](README.tr.md)

A small macOS menu bar app that shows how much of your weekly **Claude Code** limit you have used,
split into a fair share per day.

Claude's weekly limit resets once a week. It is easy to burn most of it in two busy days and be
stuck for the rest of the week. ClaudeLimit turns the weekly percentage into a daily budget so you
can see at a glance whether today you are ahead or behind.

## Features

- Menu bar text like `12 / 14`: percent used today / today's share.
- A panel with one bar per day of the current week, with hover details.
- **Daily share with carry-over:** the remaining weekly budget is divided over the remaining days.
  Use less today and tomorrow's share grows; use more and it shrinks.
- Status at a glance: comfortable, close to the share, or over the share.
- Also shows the 5-hour session limit and when the week resets.
- Optional "Launch at login".
- English and Turkish UI, picked automatically from your macOS language (English is the fallback).

## How it works

Every 10 minutes the app runs `claude -p "/usage"` (the official Claude Code CLI), reads the
weekly and session percentages from its output and stores them in a local SQLite database. Days
change at local midnight; the first and last day of the week absorb the gap to the reset time.
Claude Code reports whole percents, so values can be off by ±1.

## Requirements

- macOS 14 (Sonoma) or later.
- [Claude Code](https://docs.claude.com/en/docs/claude-code) installed and logged in with a
  Claude subscription (Pro / Max) — the `claude` command must work in your terminal.
- To build: Xcode 26 or later (the app uses the macOS 26 glass effect when available).

## Install

```bash
git clone https://github.com/bymustfa/claude-limit.git
cd claude-limit
./scripts/build-app.sh
mv dist/ClaudeLimit.app /Applications/
open /Applications/ClaudeLimit.app
```

The app appears in the menu bar (no Dock icon). Click it and turn on **Launch at login** if you
want it to start automatically.

> If Xcode is not at `/Applications/Xcode.app`, run the script as
> `DEVELOPER_DIR=/path/to/Xcode.app/Contents/Developer ./scripts/build-app.sh`.

> The app is ad-hoc signed, not notarized. If macOS blocks it on first launch, right-click the app
> in Finder and choose **Open**.

## Data and privacy

- Everything stays on your Mac. The app makes no network requests of its own; it only runs the
  `claude` CLI you already use.
- Data lives in `~/Library/Application Support/ClaudeLimit/usage.db`.

## Uninstall

Quit the app from its panel, then:

```bash
rm -rf /Applications/ClaudeLimit.app ~/Library/"Application Support"/ClaudeLimit
```

## Development

```bash
swift build
swift test
swift run ClaudeLimit   # runs without the .app bundle, English UI only
```

If `xcode-select -p` points at the Command Line Tools, prefix these with
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

Project layout:

- `Sources/ClaudeLimitCore` – parsing, storage and the weekly/daily model (unit tested).
- `Sources/ClaudeLimit` – the SwiftUI menu bar app.
- `Resources/*.lproj` – translations, copied into the app by `scripts/build-app.sh`.

Issues and pull requests are welcome. Adding a language means adding one
`Resources/<code>.lproj/Localizable.strings` file and listing the code in `scripts/build-app.sh`.

## License

[MIT](LICENSE)

ClaudeLimit is an independent project and is not affiliated with Anthropic.
