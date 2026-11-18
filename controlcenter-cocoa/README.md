# controlcenter-cocoa

Our ControlCenter: Objective-C on the Cocoa API, one source for a real macOS and for pearOS (`pearos/`). Plan, measurements and status: `docs/development/CONTROLCENTER-REPLACEMENT.md` (pearOS-bsd/docs). Same method as `../dock-cocoa`: trace the real process (`research/cc-trace`), reproduce its services and SkyLight calls, compare.

## Install on a Mac (SIP and AMFI off)
`sh mac/install.sh` builds, signs ad hoc with the entitlements read from Apple's own ControlCenter binary, gives `com.apple.controlcenter` the TCC rows the event tap needs, installs the app in `~/Applications-pearos/`, writes the LaunchAgent `~/Library/LaunchAgents/com.pearos.controlcenter.plist` (same MachServices as Apple's job), disables Apple's job (`launchctl disable gui/UID/com.apple.controlcenter`; nothing under /System changes) and starts ours. `sh mac/uninstall.sh` reverses it. Tested on the Mac VM (install, then uninstall: Apple's job came back running). Run it only on a Mac whose owner accepts the replacement; what is not finished is listed in the development document.

## Build
`make` (needs `../dock-cocoa` for the shared window code). `make check-platform` runs the FreeBSD bindings tests (`CCPlatform.c`) on a FreeBSD machine.
