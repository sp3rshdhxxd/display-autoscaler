# Design: display-autoscaler

`display-autoscaler` is an experimental, no-UI macOS utility written in Swift.
It runs as a per-user LaunchAgent and configures external display modes using
the public CoreGraphics APIs.

## Runtime Flow

1. The LaunchAgent starts the binary in the user's GUI session.
2. The app reads `~/.config/display-autoscaler/config.json`.
3. It registers `CGDisplayRegisterReconfigurationCallback` and inspects
   active external displays at startup.
4. On a new external display connection, it examines modes returned by
   `CGDisplayCopyAllDisplayModes`.
5. Candidate modes are filtered by the current aspect ratio and HiDPI setting.
   The configured logical resolution and nearest refresh rate are preferred.
   If unavailable or not applicable, compatible 1080p or 720p modes are tried.
6. Resolution changes and explicitly enabled mirroring are applied for the
   current login session using CoreGraphics display configuration transactions.
7. The app writes `~/Desktop/display-diagnostic-report.txt` and remains alive
   for future connection callbacks.

The app does not use private SkyLight mode APIs, create modes, poll IOKit, or
send display wake-up signals. It cannot act on a display macOS does not detect.

## Configuration

The configuration path is `~/.config/display-autoscaler/config.json`.

| Key | Behavior |
| --- | --- |
| `preferredWidth`, `preferredHeight` | Positive integers used together as the preferred logical resolution. Omit both to select the largest matching mode. |
| `requireHiDPI` | Excludes modes whose pixel dimensions do not exceed their logical dimensions. Defaults to `true`. |
| `preferredRefreshRate` | Chooses the nearest available refresh rate for the preferred resolution. Defaults to 60 Hz. |
| `enablePresenterMirroring` | Opts into mirroring the external display with the active built-in display. Defaults to `false`. |

Invalid configuration falls back to conservative built-in defaults. If no
compatible mode can be selected or applied, the app logs the issue and leaves
the current mode unchanged.

## Installation

`install.sh` compiles the Swift source, installs the binary in `~/bin`, creates
the per-user LaunchAgent, and copies `config.json.template` only if no live
configuration already exists. `uninstall.sh` unloads the agent and removes the
binary and plist; it keeps the user's configuration and logs.

## Limitations

Available modes and their behavior depend on macOS, the display, and any
adapters or docks in use. The project has no automated hardware test suite.
Test the complete display setup before relying on automatic changes.
