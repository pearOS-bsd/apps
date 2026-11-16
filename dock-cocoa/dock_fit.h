/* Fitting the layout to the display like the real Dock. Ground truth: the accessibility tree of the real Dock (Mac VM 26.7.2, 1280 wide, 25 items): the list starts at x 36 and is 1208 wide
 * (= display - 2 * 36), items are 49.9 apart, a separator is 22.4 wide, the first item starts 7.9 after the list's left edge.  So when the tiles do not fit, the tile size shrinks
 * CONTINUOUSLY until the bar is exactly (display - 2 * margin) wide.  dock_layout.c works with an integer tile size: the layout of the next integer size is scaled to fit. */
#ifndef DOCK_FIT_H
#define DOCK_FIT_H
#include "../dock/dock_layout.h"
#define DOCK_SIDE_MARGIN 36.0
/* m->tilesize in: the wanted size; returns the (fractional) tile size used; fills slots[n] and bar for the fitted layout. */
double dock_layout_fit(DockMetrics *m, const DockItem *items, int n, DockSlot *slots, DockBar *bar);
#endif
