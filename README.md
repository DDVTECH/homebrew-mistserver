
# homebrew-mistserver
Homebrew formula for building and installing MistServer from source.

## URLs
- MistServer homepage: https://mistserver.org
- MistServer GitHub: https://github.com/DDVTECH/mistserver
- Official docs: https://docs.mistserver.org

## Installation
1. Tap this repo:
```

brew tap ddvtech/mistserver

```
(This resolves to `DDVTECH/homebrew-mistserver`.)

2. Install MistServer:
```

brew install mistserver

```

## Background Service
To run MistServer as a launchd daemon and have it restart at login:
```

brew services start mistserver

```
To stop:
```

brew services stop mistserver

```

## How It Works
- The formula downloads the MistServer source tarball, verifies its SHA256, and builds with Meson/Ninja.
- After building, it installs the `mistserver` binary (renamed from `MistController`) into your Homebrew bin.
- A built-in `service do` block generates a launchd plist so `brew services` can manage it.

## Upgrade
When a new MistServer version is released:
1. Update `url`, `version`, and `sha256` in `Formula/mistserver.rb`.
2. Commit and push.
3. Users run:
```

brew update
brew upgrade mistserver

```

## Logs & Configuration
- Logs live at:
```

\~/Library/Logs/mistserver.log
\~/Library/Logs/mistserver.err.log

```
- Default data/config directories are under:
- Intel macs: `/usr/local/var/mistserver/`
- Apple Silicon: `/opt/homebrew/var/mistserver/`

Consult the official docs for configuration details:  
https://docs.mistserver.org

## Troubleshooting
- If the build fails, ensure you have Meson, Ninja, and pkg-config installed:
```

brew install meson ninja pkg-config

```
- Inspect runtime errors by tailing the logs:
```

tail -f \~/Library/Logs/mistserver.err.log

```
