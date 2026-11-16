/* Fitting the layout to the display like the real Dock. Ground truth: the accessibility tree and screenshots of the real Dock (Mac VM 26.7.2, 1280 x 800, 25 items):
 * bottom: the list starts at x 36 and is 1208 wide (= display - 2 * 36), items 49.9 apart, separators 22.4, first item 7.9 after the list's left edge;
 * left / right: the list starts at y 48 (menu bar 30 + 18) and is 734 long (= 800 - 30 - 2 * 18), items 30.2 apart, first item 6.2 after the list's top edge.
 * So when the tiles do not fit, the tile size shrinks CONTINUOUSLY until the bar is exactly (available length - 2 * margin) long.  The padding before the first item grows with the tile size
 * (7.9 at 46, 6.2 at 26.2: pad = 3.95 + 0.0859 * size, two points).  dock_layout.c works with an integer tile size and a fixed padding: this file corrects both. */
#ifndef DOCK_FIT_H
#define DOCK_FIT_H
#include "../dock/dock_layout.h"
#define DOCK_SIDE_MARGIN 36.0          /* bottom Dock: along the width */
#define DOCK_EDGE_MARGIN 18.0          /* side Dock: along the height, from the menu bar and from the bottom edge */
/* m->screen_w = the length of the axis the tiles run along (width, or height minus the menu bar); margin at both ends.  Returns the (fractional) tile size; fills slots[n] and bar
 * (bar_x = start along the axis, bar_w = length along the axis, bar_h = thickness) with positions along the axis, measured from the start of the axis. */
double dock_layout_fit(DockMetrics *m, const DockItem *items, int n, DockSlot *slots, DockBar *bar, double margin);
double dock_pad(double tilesize);
#endif
