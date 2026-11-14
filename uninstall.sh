#!/bin/bash
set -e

AGENT_PLIST="$HOME/Library/LaunchAgents/com.user.display-autoscaler.plist"
GUI_DOMAIN="gui/$(id -u)"

if launchctl print "$GUI_DOMAIN/com.user.display-autoscaler" >/dev/null 2>&1; then
    echo "[Uninstall] Unloading LaunchAgent..."
    launchctl bootout "$GUI_DOMAIN/com.user.display-autoscaler"
fi

if [ -f "$AGENT_PLIST" ]; then
    rm -f "$AGENT_PLIST"
fi

if [ -f "$HOME/bin/display-autoscaler" ]; then
    echo "[Uninstall] Removing binary..."
    rm -f "$HOME/bin/display-autoscaler"
fi

echo "[Uninstall] Removed the LaunchAgent and executable. Configuration and logs were kept."
