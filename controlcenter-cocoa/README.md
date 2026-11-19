# controlcenter-cocoa

Our ControlCenter: Objective-C on the Cocoa API, one source for a real macOS and for pearOS (`pearos/`). Plan, measurements and status: `docs/development/CONTROLCENTER-REPLACEMENT.md` (pearOS-bsd/docs). Same method as `../dock-cocoa`: trace the real process (`research/cc-trace`), reproduce its services and SkyLight calls, compare.

## Install on a Mac (SIP and AMFI off)
`sh mac/install.sh` builds, signs ad hoc with the entitlements read from Apple's own ControlCenter binary, gives `com.apple.controlcenter` the TCC rows the event tap needs, installs the app in `~/Applications-pearos/`, writes the LaunchAgent `~/Library/LaunchAgents/com.pearos.controlcenter.plist` (same MachServices as Apple's job), disables Apple's job (`launchctl disable gui/UID/com.apple.controlcenter`; nothing under /System changes) and starts ours. `sh mac/uninstall.sh` reverses it. Tested on the Mac VM (install, then uninstall: Apple's job came back running). Run it only on a Mac whose owner accepts the replacement; what is not finished is listed in the development document.

## Build
`make` (needs `../dock-cocoa` for the shared window code). `make check-platform` runs the FreeBSD bindings tests (`CCPlatform.c`) on a FreeBSD machine.

## Building on pearOS (FreeBSD), without a Mac
`sh build-bsd.sh OUTDIR` on the FreeBSD VM (needs `/root/oss` = where `dyld/tools/sdk` was run, llvm with `ld64.lld`, the repositories next to `apps/`): clang for x86_64-apple-macosx, our headers (ravynOS' Foundation / CoreGraphics patched, QuartzCore, SDK, CoreText, IOKit) and `compat/` (the few declarations they lack: xpc, ImageIO, ApplicationServices' event tap API, NSXPCConnection, a handful of CG / CT functions). The frameworks are empty-symbol text stubs: the symbols bind at run time. Two traps found: ravynOS' CoreGraphics headers say `typedef float CGFloat` (the build patches a copy to double, the ABI of the real frameworks), and a call to an undeclared function compiles with the wrong ABI without a warning (the build refuses implicit declarations). Result: the same program as the Mac build; it starts on the Mac and on pearOS (darwinator) and behaves the same. Not yet in `iso/build.sh`.
