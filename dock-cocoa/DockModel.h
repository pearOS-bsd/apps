/* The tiles of the Dock and their layout, from the preferences (domain com.apple.dock) the way the real Dock builds them: Finder first (always), persistent-apps, a separator,
 * persistent-others, the Trash (always). The numbers (pitch, padding, magnification) are in ../dock/dock_layout.c, fitted to measurements of the real Dock. */
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "DockPrefs.h"
@interface DockTile : NSObject
@property (copy) NSString *label, *path, *bundleIdentifier, *tileType;
@property CGRect frame;                              /* the tile's slot in window coordinates (top-left origin), set by the layout */
@property CGFloat art;                               /* edge of the icon art */
@property int kind;                                  /* DOCK_APP, DOCK_SEPARATOR, DOCK_OTHER, DOCK_TRASH (dock_layout.h) */
@end
@interface DockModel : NSObject
@property (readonly) NSArray<DockTile *> *tiles;
@property (readonly) int tileSize;                    /* after shrinking to fit the display */
@property (readonly) CGRect barRect;                 /* in window coordinates, origin top-left, window = the display */
- (instancetype)initWithPrefs:(DockPrefs *)prefs displayBounds:(CGRect)display;
@end
