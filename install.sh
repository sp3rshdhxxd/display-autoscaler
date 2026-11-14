#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if ! command -v swiftc >/dev/null 2>&1; then
    echo "[Install] swiftc was not found. Install the Xcode Command Line Tools first." >&2
    exit 1
fi

BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/display-autoscaler.XXXXXX")"
trap 'rm -rf "$BUILD_DIR"' EXIT

echo "[Install] Compiling Swift source..."
swiftc -O "$SCRIPT_DIR/main.swift" -o "$BUILD_DIR/display-autoscaler"

echo "[Install] Installing executable to $HOME/bin..."
mkdir -p "$HOME/bin"
cp "$BUILD_DIR/display-autoscaler" "$HOME/bin/display-autoscaler"

echo "[Install] Setting up configuration directory..."
mkdir -p "$HOME/.config/display-autoscaler"
if [ ! -f "$HOME/.config/display-autoscaler/config.json" ]; then
    cp "$SCRIPT_DIR/config.json.template" "$HOME/.config/display-autoscaler/config.json"
    echo "[Install] Default configuration created at $HOME/.config/display-autoscaler/config.json"
fi

echo "[Install] Creating LaunchAgent plist..."
AGENT_PLIST="$HOME/Library/LaunchAgents/com.user.display-autoscaler.plist"
mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
GUI_DOMAIN="gui/$(id -u)"

if launchctl print "$GUI_DOMAIN/com.user.display-autoscaler" >/dev/null 2>&1; then
    echo "[Install] Stopping the existing LaunchAgent..."
    launchctl bootout "$GUI_DOMAIN/com.user.display-autoscaler"
fi

cat <<EOF > "$AGENT_PLIST"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.display-autoscaler</string>
    <key>ProgramArguments</key>
    <array>
        <string>$HOME/bin/display-autoscaler</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>LimitLoadToSessionType</key>
    <array>
        <string>Aqua</string>
    </array>
    <key>StandardOutPath</key>
    <string>$HOME/Library/Logs/display-autoscaler.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/Library/Logs/display-autoscaler.log</string>
</dict>
</plist>
EOF

plutil -lint "$AGENT_PLIST"
echo "[Install] Loading LaunchAgent..."
launchctl bootstrap "$GUI_DOMAIN" "$AGENT_PLIST"
launchctl kickstart -k "$GUI_DOMAIN/com.user.display-autoscaler"

echo "[Install] Installation completed successfully!"
