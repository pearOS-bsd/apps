/* The layout against the real Dock measured on the Mac VM (2026-11-16, 1280 x 800 display, screenshot pixels): 25 items = 19 apps | separator | 2 recents | separator | folder + Trash;
 * the real bar spans x 36..1243 (1208 wide), y 729..794 (66 high), tile size 46 (pitch 50).  Tolerance 3 px in x / width (the measurement is by eye on anti-aliased edges), 0 in height.
 * Also checks the shrink rule hypothesis: the largest tile size whose bar is at most 95% of the display is 46. */
#include <stdio.h>
#include <math.h>
#include "../../dock/dock_layout.h"
int main(void)
{
	DockItem it[25]; int n = 0;
	for (int i = 0; i < 19; i++) it[n++].kind = DOCK_APP;
	it[n++].kind = DOCK_SEPARATOR; it[n++].kind = DOCK_APP; it[n++].kind = DOCK_APP; it[n++].kind = DOCK_SEPARATOR; it[n++].kind = DOCK_OTHER; it[n++].kind = DOCK_TRASH;
	int fails = 0, fit = 0;
	for (int ts = 64; ts >= 16; ts--) {
		DockMetrics m = { ts, 99, 0, 1280 }; DockSlot s[25]; DockBar b; dock_layout(&m, it, n, -1, s, &b);
		if (b.bar_w <= 1280 * 0.95) { fit = ts; break; }
	}
	if (fit != 46) { printf("FAIL: the shrink rule gives tile size %d, the real Dock has 46\n", fit); fails++; }
	DockMetrics m = { 46, 99, 0, 1280 }; DockSlot s[25]; DockBar b; dock_layout(&m, it, n, -1, s, &b);
	if (fabs(b.bar_x - 36) > 3 || fabs(b.bar_w - 1208) > 3 || b.bar_h != 66 || b.bottom_margin != 5) { printf("FAIL: bar x %.1f w %.1f h %.0f margin %.0f (real 36 / 1208 / 66 / 5)\n", b.bar_x, b.bar_w, b.bar_h, b.bottom_margin); fails++; }
	printf(fails ? "%d layout checks FAILED\n" : "layout matches the measured real Dock (bar x %.1f w %.1f h %.0f, tile size 46)\n", fails ? fails : 0, b.bar_x, b.bar_w, b.bar_h);
	return fails != 0;
}
