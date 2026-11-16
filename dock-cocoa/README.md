# dock-cocoa

The new Dock: Objective-C on the Cocoa API, one source for a real macOS and for pearOS. Goal and plan: `docs/development/DOCK-REPLACEMENT.md`. The older `apps/dock` (GNUstep, `ws_*`) stays until this one passes the trace comparison (`research/dock-trace/compare.py`).
Status: skeleton (startup services and preference keys only; no window yet).

## First comparison with the real Dock (2026-11-16, Mac VM, `research/dock-trace/trace-ours.sh` + `compare.py --order`)
| kind | real | ours | result |
|---|---|---|---|
| CHECKIN | 2 | 2 | same |
| LOOKUP | 8 | 8 | same set, other order (ours still looks up `dock.server`/`fonts` at other moments) |
| PREF | 46 | 43 | missing `IIOEnableOOP`, `Session Language`, `Additional Languages`, `Assistant Enabled` (framework side effects of the real Dock's features); extra `AppleReduceDesktopTinting` |
| XPCSVC | 28 | 31 | extra `pasteboard.1`, `runningboard`, `linkd.autoShortcut`: caused by our early `[NSApplication sharedApplication]`; the real Dock does not touch them at startup |
| OPEN | 135 | 26 | most of the difference is the bundle it runs from (`Dock.app/Contents/...`) and the features not written yet (icon cache, fonts, per-tile bundle reads, FaceTime tile) |
