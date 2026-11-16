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
| PREF | 46 | 46 | same set (order differs) |
| SLS (SkyLight/CGS first calls) | 149 | 54 | window, level, order and the display queries done; missing 80 public calls: spaces (`SLSSpaceCreate`, `SLSCopySpaces` ...), `SLSWindowQuery*`, `SLSSetWindowProperty`, hot keys, notifications, `SLSSetDockRectWithOrientation`, ... |
| OPEN | 135 | 14 | the rest is the real Dock's resources, fonts, icon cache, per-tile bundle reads and plugins: features not written yet |

Two facts that shaped the design: the real Dock **does not link AppKit** (it links Foundation, QuartzCore, SkyLight, CoreUI, IconServices, CoreServices, SwiftUICore ...), and it is a bundle (`Contents/Info.plist` with `LSUIElement`); so ours is a bundle and links Foundation only. `make` builds `Dock.app`.

## Window (2026-11-16, Mac VM 26.7.2)
Created with `SLSNewWindowWithOpaqueShapeAndContext` (type **2**; 0 and 1 return error 1000), level and order set through `SLSTransaction*`. `CGWindowListCopyWindowInfo` shows our window at X 290, Y 715, 700 x 80, level 20 (the Dock level) on a 1280 x 800 display: centred at the bottom, no AppKit. No content is drawn yet (no layer context). Prototypes in `SkyLightAPI.h` are marked verified or not.

## What the real Dock's windows look like (Mac VM, CGWindowListCopyWindowInfo, 2026-11-16)
Two windows owned by `Dock`, both 1280 x 800 at 0,0 (the whole display): one at layer 20 (the bar is drawn inside it) and one at layer -2147483624 (just below the desktop-icon level: the wallpaper). So ours is one display-sized window at level 20 (`DockWindow`), the wallpaper window comes later.
`DockModel` builds the tile list from the preferences (Finder, persistent-apps, separator, persistent-others, Trash) and the bar rectangle through `../dock/dock_layout.c` (measured on the real Dock). With this Mac's 18 apps it gives 22 tiles and a bar 1345.5 wide on a 1280 display: **too wide**; the real Dock shrinks the tiles until the bar fits, and that rule is not implemented yet (needs a screenshot of the real Dock to measure; the Mac VM screen must be unlocked).

## Measured on the real Dock (screenshot of the Mac VM, 1280 x 800, 2026-11-16)
Bar x 36..1243 (1208 wide), y 729..794 (66 high), 5 px above the bottom; tile pitch 50 (tile size 46); 19 apps | separator | 2 recents | separator | folder + Trash. `make check` (any host) runs `test/layout_check.c` against these numbers: the layout of `dock_layout.c` is within 3 px and the hypothesis "tile size shrinks until the bar is at most 95% of the display" gives 46 as the real Dock does (one data point: more displays and tile counts are needed to confirm).
**Open:** this Mac's prefs give 24 items (one recent in `recent-apps`); the real Dock shows a 25th item after the Terminal tile, a blue circular arrow (a downloads tile, most likely served by the `com.apple.dock.downloads` service): not derivable from the preferences, not modelled.
