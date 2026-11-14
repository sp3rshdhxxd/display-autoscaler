# Project Overview: display-autoscaler

`display-autoscaler` is an experimental, no-UI macOS utility that runs as a
per-user LaunchAgent. It uses public CoreGraphics APIs to select among display
modes macOS already exposes when an external display is connected.

## What It Does

- Checks active external displays at launch and when a new external display is
  added.
- Tries a configured logical resolution and refresh rate, subject to aspect
  ratio and HiDPI filters.
- Tries compatible 1080p or 720p modes if the preferred mode is unavailable or
  cannot be applied.
- Applies display changes for the current login session only.
- Optionally mirrors an external display with the built-in display. This is
  disabled by default.
- Writes a diagnostics report to the user's Desktop.

## What It Does Not Do

- Create hidden display modes or guarantee that HiDPI modes are available.
- Wake a sleeping display, repair a cable/adapter issue, or detect a display
  that macOS does not see.
- Guarantee a suitable mode for every monitor, adapter, dock, or projector.

Mode selection and actual display behavior depend on macOS and the hardware.
Users should test with their display setup before relying on the utility.
