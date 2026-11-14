# display-autoscaler

`display-autoscaler` is a small, experimental macOS background utility written in
Swift. It looks for active external displays and selects a display mode from the
modes macOS reports as available. It can optionally mirror an external display
with the built-in display.

It does not create display modes, guarantee HiDPI scaling, wake a sleeping
display, repair HDMI/DisplayPort connections, or guarantee that a selected mode
will look right on every monitor or projector. It uses public CoreGraphics
display APIs for mode selection. macOS and hardware behavior vary; test with
your displays before relying on it for a presentation.

## What it does

- On launch, checks active external displays and tries to select the configured
  resolution and refresh rate.
- On a newly connected display, repeats that mode selection.
- Requires HiDPI modes by default. If the preferred mode is unavailable, it
  tries a listed 1080p or 720p mode that meets the same aspect-ratio and HiDPI
  filters. If no suitable mode exists or applying one fails, it leaves the
  current mode unchanged.
- Writes a diagnostics report to
  `~/Desktop/display-diagnostic-report.txt` at launch and when a display is
  connected.
- Leaves mirroring disabled by default. Enable it explicitly in the config if
  you want the app to mirror the built-in display to an external one.

Display changes are applied for the current login session; the app does not ask
for administrator privileges. The utility has no graphical interface. Its
LaunchAgent output is written to `~/Library/Logs/display-autoscaler.log`.

## Requirements

- macOS with Swift installed (the Xcode Command Line Tools provide `swiftc`).
- An account logged in to the macOS graphical session.

## Install

From the repository directory, run:

```sh
./install.sh
```

The script compiles the app, installs it under `~/bin`, copies the default
configuration if one does not already exist, and loads a LaunchAgent for the
current user. It does not replace an existing config file.

To uninstall:

```sh
./uninstall.sh
```

Uninstall removes the LaunchAgent and executable. It leaves the configuration
and log files in place.

## Configuration

The live configuration is `~/.config/display-autoscaler/config.json`:

```json
{
  "preferredWidth": 2560,
  "preferredHeight": 1440,
  "requireHiDPI": true,
  "preferredRefreshRate": 60,
  "enablePresenterMirroring": false
}
```

`preferredWidth` and `preferredHeight` must both be positive integers or both
be omitted. When provided, the app selects that logical resolution and the
available refresh rate nearest to `preferredRefreshRate`. When omitted, it
chooses the largest listed mode matching the current aspect ratio. With
`requireHiDPI` enabled, non-HiDPI modes are excluded, including fallbacks.
`enablePresenterMirroring` is opt-in because it changes the desktop layout.

Changes to the config are read when the app processes a newly connected
display; restart the LaunchAgent to apply them immediately. To restart it:

```sh
launchctl kickstart -k "gui/$(id -u)/com.user.display-autoscaler"
```

## Limitations

- The app can only choose modes that macOS exposes for the display. It cannot
  unlock hidden modes or promise that macOS will expose a HiDPI option.
- A mode listed by macOS can still fail to apply. In that case the app tries a
  compatible fallback and otherwise leaves the current mode unchanged.
- The app cannot detect or fix a display that macOS does not detect.
- Automatic mirroring and resolution changes can disrupt active work. Keep
  mirroring disabled unless you explicitly want that behavior.
- This project has no automated hardware test suite. Validate it with your
  monitor, adapter, dock, and macOS version before depending on it.
