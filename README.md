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
