/* The layout against the real Dock, measured through its ACCESSIBILITY TREE on the Mac VM (2026-11-16, 1280 x 800): 25 items = 19 apps | separator | Terminal + "Install Command Line Developer Tools"
 * | separator | Downloads + Trash.  Real: list x 36, width 1208, items 49.9 apart starting at x 43.9, separators 22.4 wide, Terminal at 1014.1, Downloads at 1136.3, Trash at 1186.2.
 * Tolerance 0.6 px. */
#include <stdio.h>
#include <math.h>
#include "../dock_fit.h"
int main(void)
{
	DockItem it[25]; int n = 0;
	for (int i = 0; i < 19; i++) it[n++].kind = DOCK_APP;
	it[n++].kind = DOCK_SEPARATOR; it[n++].kind = DOCK_APP; it[n++].kind = DOCK_APP; it[n++].kind = DOCK_SEPARATOR; it[n++].kind = DOCK_OTHER; it[n++].kind = DOCK_TRASH;
	DockMetrics m = { 64, 99, 0, 1280 }; DockSlot s[25]; DockBar b; double ts = dock_layout_fit(&m, it, n, s, &b);
	int fails = 0;
	struct { int idx; double x; const char *what; } want[] = { { 0, 43.9, "Finder" }, { 1, 93.8, "Apps" }, { 18, 941.8, "System Settings" }, { 19, 991.7, "separator" }, { 20, 1014.1, "Terminal" }, { 21, 1064.0, "CLT installer" }, { 22, 1113.9, "separator 2" }, { 23, 1136.3, "Downloads" }, { 24, 1186.2, "Trash" } };
	for (size_t k = 0; k < sizeof want / sizeof *want; k++) {
		/* the slot's x is the left edge of the item; the AX frame starts at the same place */
		if (fabs(s[want[k].idx].x - want[k].x) > 0.6) { printf("FAIL %s: x %.2f, real %.1f\n", want[k].what, s[want[k].idx].x, want[k].x); fails++; }
	}
	if (fabs(b.bar_w - 1208) > 0.6 || fabs(b.bar_x - 36) > 0.6) { printf("FAIL bar x %.2f w %.2f (real 36 / 1208)\n", b.bar_x, b.bar_w); fails++; }
	if (fabs(s[19].w - 22.4) > 0.3 || fabs(s[0].w - 49.9) > 0.3) { printf("FAIL widths: separator %.2f (22.4), item %.2f (49.9)\n", s[19].w, s[0].w); fails++; }
	if (fails) printf("%d layout checks FAILED (tile size %.2f)\n", fails, ts);
	else printf("layout matches the real Dock's accessibility frames (tile size %.3f, bar x %.2f w %.2f, Trash x %.2f)\n", ts, b.bar_x, b.bar_w, s[24].x);
	return fails != 0;
}
