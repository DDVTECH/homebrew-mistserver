# homebrew-mistserver

Homebrew tap for [MistServer](https://mistserver.org) and [MistTray](https://github.com/DDVTECH/MistMacTray).

## Installation

```bash
brew tap ddvtech/mistserver
brew install mistserver
```

Optionally install the macOS menu bar app:

```bash
brew install --cask misttray
```

## Usage

Start as a background service:

```bash
brew services start mistserver
```

Then open http://localhost:4242 in your browser.

Stop:

```bash
brew services stop mistserver
```

Or run in the foreground:

```bash
mistserver
```

## Upgrade

```bash
brew update
brew upgrade mistserver
```

## Logs

```bash
tail -f $(brew --prefix)/var/log/mistserver/mistserver.log
```

## Links

- [MistServer docs](https://docs.mistserver.org)
- [MistServer source](https://github.com/DDVTECH/mistserver)
- [MistTray source](https://github.com/DDVTECH/MistMacTray)

## Formula updates

The nightly workflow checks the latest published MistServer release. The separate
`mistserver-tag` repository dispatch updates from the exact requested tag in
`client_payload.tag`, without requiring a GitHub release or release notes.
The buildsystem's `homebrew-sync.sh TAG` sends that event; it can run independently
or as part of the normal internal `release.sh TAG` command.

Both workflows share the same source-formula bump logic and queue formula updates
without discarding pending runs. An older numeric version never downgrades the
formula. If version names cannot be ordered numerically, nightly leaves the
formula alone; use the exact-tag workflow to select the intended version.
Neither workflow reacts to arbitrary tag pushes or ordinary/customer builds.
An empty exact-tag argument fails instead of falling back to latest release.

Tags follow Git ref rules, not a numeric release-name whitelist. Source URLs and
formula strings are escaped. Formula commits stage only `Formula/mistserver.rb`
and rebase on main to preserve unrelated cask changes; MistTray still uses its
published signed ZIP. Manual workflows are available for either server path.
