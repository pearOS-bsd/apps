#include "dock_fit.h"
#define LEGACY_PAD 7.75                /* the constant inside dock_layout.c */
double dock_pad(double ts) { return 3.95 + 0.0859 * ts; }
/* layout with the padding of this tile size; positions RELATIVE to the start of the bar, bar_x = 0 */
static void corrected(DockMetrics *m, const DockItem *items, int n, DockSlot *slots, DockBar *bar)
{
	dock_layout(m, items, n, -1, slots, bar);
	double d = dock_pad(m->tilesize) - LEGACY_PAD, x0 = bar->bar_x;
	for (int i = 0; i < n; i++) { slots[i].x += d - x0; slots[i].cx += d - x0; }
	bar->bar_w += 2 * d; bar->bar_x = 0;
}
static void place(int n, DockSlot *slots, DockBar *bar, double start) { for (int i = 0; i < n; i++) { slots[i].x += start; slots[i].cx += start; } bar->bar_x = start; }
double dock_layout_fit(DockMetrics *m, const DockItem *items, int n, DockSlot *slots, DockBar *bar, double margin)
{
	double limit = m->screen_w - 2 * margin; int want = m->tilesize, ts = want;
	corrected(m, items, n, slots, bar);
	if (bar->bar_w <= limit) { place(n, slots, bar, (m->screen_w - bar->bar_w) / 2); return want; }
	while (ts > 8) { m->tilesize = ts; corrected(m, items, n, slots, bar); if (bar->bar_w <= limit) break; ts--; }
	m->tilesize = ts + 1; if (m->largesize < m->tilesize) m->largesize = m->tilesize;
	corrected(m, items, n, slots, bar);            /* the layout of ts + 1 is too long: scale it down along the axis to exactly the limit */
	double f = limit / bar->bar_w;
	for (int i = 0; i < n; i++) { slots[i].x *= f; slots[i].w *= f; slots[i].cx *= f; }
	bar->bar_w *= f; place(n, slots, bar, margin);
	return (ts + 1) * f;          /* the scaled size of the layout of ts + 1 */
}
