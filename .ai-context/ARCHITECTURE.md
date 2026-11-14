# Architecture & Technical Design

## Tech Stack

- **Language:** Swift
- **Compiler:** macOS `swiftc`
- **Frameworks:** Foundation and CoreGraphics
- **Background process:** Per-user LaunchAgent

The app uses CoreGraphics to enumerate modes macOS makes available and to
configure display modes. It does not call private SkyLight APIs or create
display modes.

## Application Flow

1. The LaunchAgent starts `$HOME/bin/display-autoscaler` in the logged-in GUI
   session.
2. The app reads `~/.config/display-autoscaler/config.json`. Invalid or
   unreadable configuration falls back to 2560x1440, HiDPI required, 60 Hz,
   with mirroring off.
3. It registers a CoreGraphics display-reconfiguration callback and checks
   already-active external displays.
4. On connection of a new external display, it filters available modes by
   aspect ratio and HiDPI preference, tries the preferred size and refresh
   rate, then compatible 1080p/720p fallbacks.
5. Mode changes and optional mirroring are applied for the current login
   session only. If mode selection or application fails, it reports the error
   and does not deliberately force a different unsupported mode.
6. It writes diagnostics to
   `~/Desktop/display-diagnostic-report.txt` at launch and when a display is
   connected, then remains alive to receive callbacks.

The app does not poll for hardware, send wake-up signals, or detect a display
that macOS itself does not report.

## Configuration

`preferredWidth` and `preferredHeight` are a pair; if omitted, the app selects
the largest available mode matching the current aspect ratio. `requireHiDPI`
defaults to true. `preferredRefreshRate` defaults to 60 Hz. Mirroring is
disabled unless `enablePresenterMirroring` is explicitly true.
