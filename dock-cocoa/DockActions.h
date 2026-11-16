/* What the Dock does with a tile: open it, quit it, show it in Finder, keep it / remove it. LaunchServices / Apple Events / the preferences; no AppKit. */
#import <Foundation/Foundation.h>
#import "DockModel.h"
void DockOpenTile(DockTile *t);                     /* an application: launch or activate; a folder: open it in Finder; the Trash: open ~/.Trash */
void DockQuitTile(DockTile *t);                     /* the 'quit' Apple Event to the application (by bundle identifier) */
void DockRevealTile(DockTile *t);                   /* open -R: the item selected in a Finder window */
