# dock-cocoa

The new Dock: Objective-C on the Cocoa API, one source for a real macOS and for pearOS. Goal and plan: `docs/development/DOCK-REPLACEMENT.md`. The older `apps/dock` (GNUstep, `ws_*`) stays until this one passes the trace comparison (`research/dock-trace/compare.py`).
Status: skeleton (startup services and preference keys only; no window yet).

## Comparison with the real Dock (Mac VM, `research/dock-trace/trace-ours.sh` + `compare.py --order`; 2026-11-16, after the fix of the trace scripts)
An earlier table of this file was wrong: `dtrace -o` appends to an existing file and the scripts read a stale one. Redone with fresh files; two fresh captures of the real Dock are identical (340 lines each).

| kind | real | ours | result |
|---|---|---|---|
| CHECKIN | 2 | 2 | same |
| LOOKUP | 8 | 8 | same, same order |
| XPCSVC | 28 | 28 | same, same order |
| PREF | 46 | 44 | missing `AppleLanguages`, `NSAppNapLaunchDelay` (framework side effects of features not written yet) |
| OPEN | 135 | 14 | the rest is the real Dock's resources, fonts, icon cache, per-tile bundle reads and plugins: features not written yet |

Two facts that shaped the design: the real Dock **does not link AppKit** (it links Foundation, QuartzCore, SkyLight, CoreUI, IconServices, CoreServices, SwiftUICore ...), and it is a bundle (`Contents/Info.plist` with `LSUIElement`); so ours is a bundle and links Foundation only. `make` builds `Dock.app`.
