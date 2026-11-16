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
@property (copy) NSString *badge;                    /* the badge text (a count), from the application's StatusLabel; nil for none */
@property BOOL running;                              /* a running application (the dot under the icon) */
@property (copy) NSDictionary *dict;                /* the tile as it is in the preferences (nil for Finder, running apps not kept, separators, Trash) */
@property int section;                               /* 0 applications | 1 running / recent | 2 folders and Trash */
@property (weak) CALayer *iconLayer;                 /* the layer that shows the icon (set by DockView) */
@property int kind;                                  /* DOCK_APP, DOCK_SEPARATOR, DOCK_OTHER, DOCK_TRASH (dock_layout.h) */
@end
@interface DockModel : NSObject
@property (readonly) NSArray<DockTile *> *tiles;
@property (readonly) int orientation;                /* 0 bottom, 1 left, 2 right (preference `orientation`) */
@property (readonly) int tileSize;                    /* after shrinking to fit the display */
@property (readonly) CGRect barRect;                 /* in window coordinates, origin top-left, window = the display */
+ (NSDictionary *)tileDictionaryForPath:(NSString *)path label:(NSString *)label bundleIdentifier:(NSString *)bid;     /* a new file-tile in the shape of the real Dock's (docs/development/DOCK-CONFIG.md) */
- (instancetype)initWithPrefs:(DockPrefs *)prefs displayBounds:(CGRect)display;
@end

/* the coordinate along the tiles: x for the bottom Dock, y for a side Dock */
static inline CGFloat DockAxis(DockModel *m, CGPoint p) { return m.orientation == 0 ? p.x : p.y; }
static inline CGFloat DockTileMin(DockModel *m, DockTile *t) { return m.orientation == 0 ? CGRectGetMinX(t.frame) : CGRectGetMinY(t.frame); }
static inline CGFloat DockTileMax(DockModel *m, DockTile *t) { return m.orientation == 0 ? CGRectGetMaxX(t.frame) : CGRectGetMaxY(t.frame); }
static inline CGFloat DockTileMid(DockModel *m, DockTile *t) { return (DockTileMin(m, t) + DockTileMax(m, t)) / 2; }
