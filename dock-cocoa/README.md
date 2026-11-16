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

## Content in the window (2026-11-16, checked with a screenshot of the Mac VM)
Recipe that works on macOS 26.7.2 (found by tracing the real Dock with dtrace, then tested): create the layer context first (`+[CAContext contextWithCGSConnection:options:]`), then `SLSNewWindowWithOpaqueShapeAndContext` with **type 5** (the real Dock's value; type 2 gives a window with no content, 0 and 1 fail) and the CAContext **object** as the `context` argument, set the level and order through an `SLSTransaction`, then `-[CAContext setLayer:]` **after** the window exists, then `[CATransaction flush]` with a running run loop. A red layer shows on the real desktop. `DockView.m` builds the bar and one placeholder square per tile from the model; they sit on top of the real Dock's icons within a few pixels (tile size 48 and 24 items here against 46 and 25 in the real one: the downloads tile is not modelled). Icons, the Finder/Trash art, labels, magnification and the wallpaper window come next.

## Icons (2026-11-16, Mac VM screenshot with the real Dock stopped)
Through IconServices like the real Dock (dtrace: `ISBundleIcon initWithBundleURL:`, `ISImageDescriptor initWithSize:scale:`, `ISIcon prepareImagesForImageDescriptors:`): `DockIcons.m` calls the private classes through the Objective-C runtime (dlopen of IconServices; on pearOS the IconServices repository serves the same names). An icon that is not cached arrives later (`getCGImageForImageDescriptor:completion:`), so the tile shows a placeholder first. The Trash and the Downloads folder come from `CoreTypes.bundle` icns (`ISIcnsIcon`); `ISTypeIcon` with a trash UTI returns a "?" document (not understood why; the real Dock's way for the Trash is not traced yet). All 18 apps, Finder, Terminal, the Downloads folder and the Trash show their real icons.
Finding: with the real Dock stopped (`launchctl bootout gui/501/com.apple.Dock.agent`, restore with `bootstrap` + `kickstart`, the job has `RunAtLoad false`) the desktop turns black: **the Dock draws the wallpaper** (its second, desktop-level window). Ours has to do that too.

## Pixel comparison with the real Dock (screenshots of the Mac VM, `research/dock-trace/shot-ours.sh` + `pixdiff.py`; 0 = identical)
| step | whole screen | Dock strip (bottom 80 rows) |
|---|---|---|
| first bar and placeholders | 6.25 | 62 |
| bar colour (black, alpha 0.906 over the white desktop) | 4.43 | 44 |
| 25 items (running apps from LaunchServices) + exact fit (bar 36 -> 1244) + dots | 2.02 | 19.9 |
| icon layer = tile size (38 px visible, like the real one) | 0.54 | 5.04 |
| icons asked at the display's backing scale (1x here), trilinear minification, layers on whole pixels (2x images squeezed into 1x and fractional origins made ours look jagged / soft) | **0.29** | **2.55** |
Above the bar the difference is 0.04: the wallpaper window matches. What still differs: the Calendar icon (the real Dock draws today's date through the app's `docktileplugin`), the badge on System Settings (a notification count), the bar's blurred-material look and its 1 px border.
Ground truth for positions: the real Dock's accessibility tree (a TCC row for Accessibility was added on the Mac VM like the one for screen capture; backup `/Users/alex/TCC.db.backup-before-accessibility`): list x 36, 1208 wide, items 49.9 apart, separators 22.4; `make check` verifies all of them within 0.6 px. The 25th item is the running application "Install Command Line Developer Tools": the section after the first separator is the running applications that are not in the Dock permanently (LaunchServices: `_LSCopyRunningApplicationArray(0xFFFFFFFE)`), then the recents that are not running.

## Hover label (2026-11-16)
`DockHover.m`: a black pill above the tile under the pointer, 27 px high, top 40 px above the bar, pointer 12 px wide ending 9 px above the bar, white 14 pt system-font text; width = text width + 26.6, fitted on four labels of the real Dock (measured on screenshots with the pointer moved by `research/dock-trace/mouse.c`): TV 45, Safari 64, Trash 62, iPhone Mirroring 133 px, all four reproduced to the pixel (position within 1 px). The pointer position is POLLED from CoreGraphics at 60 Hz: scaffolding, the real Dock gets events from SkyLight (`SLSSetBackgroundEventMaskAndShape`, the event port); that path is not traced yet. No fade-in/out timing measured, no click, no drag, no magnification yet.

## Badges (2026-11-16)
The real Dock draws a red circle (measured: 17 px, colour 244 63 53, x = icon right - 19, y = icon top, white bold number) for an application's badge. Where the number comes from in the real Dock (strings of the binary): `DockNotificationCenterBadgeConnection` (a Swift class), `badge_count`, `setStatusLabel:forProcessWithBundleIdentifier:` (running applications: the `StatusLabel` of LaunchServices, set by `NSDockTile.badgeLabel`), `setStatusLabel:forPushNotificationWithBundleID:` (notification badges, through the service `com.apple.usernoted.dock` that the Dock calls and `com.apple.dock.notificationcenter` that it provides), `_badgesDisabledForBundleIdentifiers`.
Ours: the circle is drawn like the real one; the number is read from LaunchServices (`_LSCopyApplicationInformation` -> `StatusLabel`, for running applications; checked with `lsappinfo setinfo -app Terminal StatusLabel="{ label=3 }"`, the badge appears within 1.5 s). NOT done: the push / notification badges. The "1" on System Settings in the real Dock (the application is not running) comes from that path; it is not in usernoted's database (`~/Library/Group Containers/group.com.apple.usernoted/db2/db`, table `app`, column `badge` is empty) and its XPC protocol is not traced (the Dock reads keys `bundle_identifiers`, `message_type`, `status`, `notification`: not enough to decode). To do it: provide `com.apple.dock.notificationcenter` as a real listener (needs MachServices in our launchd job, see dock-switch.sh) and capture what usernoted sends.
The Dock also looks for changes of running applications and badges every 1.5 s (scaffolding).
