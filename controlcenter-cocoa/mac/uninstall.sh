#!/bin/sh
# Back to Apple's ControlCenter: removes our LaunchAgent, enables and starts Apple's job (our app stays in ~/Applications-pearos until you delete it).
UID_="$(id -u)"
launchctl bootout "gui/$UID_/com.pearos.controlcenter" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/com.pearos.controlcenter.plist"
launchctl enable "gui/$UID_/com.apple.controlcenter" 2>/dev/null || true
launchctl bootstrap "gui/$UID_" /System/Library/LaunchAgents/com.apple.controlcenter.plist 2>/dev/null || true
launchctl kickstart "gui/$UID_/com.apple.controlcenter" 2>/dev/null || true; sleep 3; pgrep -lx ControlCenter
