#!/bin/sh
# Installs our ControlCenter in place of Apple's on a Mac with SIP and AMFI off (nothing under /System is touched):
#   sh mac/install.sh            build, sign, install the app in ~/Applications-pearos/, TCC rows, a LaunchAgent (com.pearos.controlcenter) and disable Apple's job
#   sh mac/uninstall.sh          back to Apple's ControlCenter
# Needs: Xcode command line tools (clang), sudo (TCC database), the dock-cocoa sources next to this directory (shared window code).
set -e
sudo_() { if [ -n "$PEARPW" ]; then echo "$PEARPW" | sudo -S -p "" "$@"; else sudo "$@"; fi; }      # PEARPW=password for unattended runs (the VM)
H="$(cd "$(dirname "$0")/.." && pwd)"; DEST="$HOME/Applications-pearos"; APP="$DEST/ControlCenter.app"; UID_="$(id -u)"
(cd "$H" && make clean >/dev/null && make) || { echo "build failed"; exit 1; }
mkdir -p "$DEST"; rm -rf "$APP"; cp -R "$H/ControlCenter.app" "$APP"
# the entitlements of Apple's ControlCenter (Focus, Wi-Fi, ... need them); copied from the machine's own binary at install time, not stored here
codesign -d --entitlements :- /System/Library/CoreServices/ControlCenter.app/Contents/MacOS/ControlCenter > "$DEST/ents.plist" 2>/dev/null || true
codesign --force -s - --entitlements "$DEST/ents.plist" "$APP" 2>/dev/null || codesign --force -s - "$APP"
for S in kTCCServiceAccessibility kTCCServiceListenEvent kTCCServicePostEvent; do
  sudo_ sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "insert or ignore into access (service,client,client_type,auth_value,auth_reason,auth_version,flags) values ('$S','com.apple.controlcenter',0,2,4,1,0); update access set csreq=NULL, auth_value=2 where client='com.apple.controlcenter' and service='$S';"
done
sudo_ killall tccd 2>/dev/null || true
PL="$HOME/Library/LaunchAgents/com.pearos.controlcenter.plist"; mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PL" <<PLIST
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict>
<key>Label</key><string>com.pearos.controlcenter</string><key>Program</key><string>$APP/Contents/MacOS/ControlCenter</string>
<key>RunAtLoad</key><true/><key>KeepAlive</key><dict><key>SuccessfulExit</key><false/></dict><key>ProcessType</key><string>App</string><key>ThrottleInterval</key><integer>1</integer>
<key>LimitLoadToSessionType</key><array><string>Aqua</string></array><key>StandardErrorPath</key><string>/tmp/pearos-cc.err</string>
<key>MachServices</key><dict><key>com.apple.controlcenter.ccutil</key><dict/><key>com.apple.SystemBannerService</key><dict/><key>com.apple.SystemBanner</key><dict/>
<key>com.apple.controlcenter.controlcentermodule</key><dict/><key>com.apple.controlcenter.show.toggles</key><dict><key>HideUntilCheckIn</key><true/></dict><key>com.apple.controlcenter.statusitems</key><dict/></dict></dict></plist>
PLIST
launchctl disable "gui/$UID_/com.apple.controlcenter" 2>/dev/null || true       # Apple's job stays off at the next logins
launchctl bootout "gui/$UID_/com.pearos.controlcenter" 2>/dev/null || true
launchctl bootout "gui/$UID_/com.apple.controlcenter" 2>/dev/null || true; sleep 2
launchctl bootstrap "gui/$UID_" "$PL"; sleep 3; pgrep -lx ControlCenter && echo "installed: $APP"
