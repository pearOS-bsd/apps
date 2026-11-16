#include "dock_fit.h"
double dock_layout_fit(DockMetrics *m, const DockItem *items, int n, DockSlot *slots, DockBar *bar)
{
	double limit = m->screen_w - 2 * DOCK_SIDE_MARGIN; int want = m->tilesize, ts = want;
	dock_layout(m, items, n, -1, slots, bar);
	if (bar->bar_w <= limit) return want;
	while (ts > 8) { m->tilesize = ts; dock_layout(m, items, n, -1, slots, bar); if (bar->bar_w <= limit) break; ts--; }
	/* the layout of ts + 1 is too wide: scale it down along the Dock to exactly the limit */
	m->tilesize = ts + 1; if (m->largesize < m->tilesize) m->largesize = m->tilesize;
	dock_layout(m, items, n, -1, slots, bar);
	double f = limit / bar->bar_w;
	for (int i = 0; i < n; i++) { slots[i].x *= f; slots[i].w *= f; slots[i].cx *= f; }
	bar->bar_x *= f; bar->bar_w *= f;
	/* re-centre: the scaled bar is exactly `limit` wide, so it starts at the margin */
	double dx = DOCK_SIDE_MARGIN - bar->bar_x; for (int i = 0; i < n; i++) { slots[i].x += dx; slots[i].cx += dx; } bar->bar_x += dx;
	return ts + f;       /* e.g. 45.99: the size the real Dock reports as pitch 49.9 */
}
