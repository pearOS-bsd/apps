/* The tiles of the Dock and their layout, from the preferences (domain com.apple.dock) the way the real Dock builds them: Finder first (always), persistent-apps, a separator,
 * persistent-others, the Trash (always). The numbers (pitch, padding, magnification) are in ../dock/dock_layout.c, fitted to measurements of the real Dock. */
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <QuartzCore/QuartzCore.h>
#import "DockPrefs.h"
@interface DockTile : NSObject
@property (copy) NSString *label, *path, *bundleIdentifier, *tileType;
@property CGRect frame;                              /* the tile's slot in window coordinates (top-left origin), set by the layout */
@property CGFloat art;                               /* edge of the icon art */
@property BOOL running;                              /* a running application (the dot under the icon) */
@property (copy) NSDictionary *dict;                /* the tile as it is in the preferences (nil for Finder, running apps not kept, separators, Trash) */
@property int section;                               /* 0 applications | 1 running / recent | 2 folders and Trash */
@property (weak) CALayer *iconLayer;                 /* the layer that shows the icon (set by DockView) */
@property int kind;                                  /* DOCK_APP, DOCK_SEPARATOR, DOCK_OTHER, DOCK_TRASH (dock_layout.h) */
@end
@interface DockModel : NSObject
@property (readonly) NSArray<DockTile *> *tiles;
@property (readonly) int tileSize;                    /* after shrinking to fit the display */
@property (readonly) CGRect barRect;                 /* in window coordinates, origin top-left, window = the display */
+ (NSDictionary *)tileDictionaryForPath:(NSString *)path label:(NSString *)label bundleIdentifier:(NSString *)bid;     /* a new file-tile in the shape of the real Dock's (docs/development/DOCK-CONFIG.md) */
- (instancetype)initWithPrefs:(DockPrefs *)prefs displayBounds:(CGRect)display;
@end
