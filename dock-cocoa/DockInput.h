/* Mouse input of the Dock: click (open), right click (menu), drag (reorder, take out of the Dock), drag of a separator (tile size).
 * SCAFFOLDING: a CGEventTap at the session level that swallows the events that fall on the bar (and the menu). The real Dock gets its events from SkyLight (the window's event shape,
 * SLSSetBackgroundEventMaskAndShape); that path is not traced yet.  Needs the Accessibility and Input Monitoring TCC rows for this binary. */
#import <Foundation/Foundation.h>
@class DockController;
@interface DockInput : NSObject
- (instancetype)initWithController:(DockController *)controller;
@end
