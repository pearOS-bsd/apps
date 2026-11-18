/* The bounce of an icon while its application launches (preference `launchanim`, default on).  Measured on the real Dock (Mac VM 26.7.2, tile size 46, Reminders launched from the Terminal, the item's accessibility
 * position sampled every 4 ms, docs/development/DOCK-ANIMATIONS.md): the icon starts to move about 50 ms after the launch request, rises 14.4 px (0.31 of the tile) and falls back in a cycle of about 690 ms (contacts at
 * 639, 1400, 2090, 2770 ms), three cycles for an application that took about 2 s to come up; the height follows h * sin(pi u)^0.5 (u = phase of the cycle: 64 % of the height at u = 0.14, 84 % at 0.25 measured, 0.657 / 0.84 fitted).
 * The bounce ends at the end of the cycle in progress once the application is running. */
#import <Foundation/Foundation.h>
#import "DockModel.h"
@class DockController;
void DockBounceInstall(DockController *controller);
void DockBounceStart(DockTile *tile);        /* called when a tile is opened (does nothing for a running application, a folder or the Trash) */
