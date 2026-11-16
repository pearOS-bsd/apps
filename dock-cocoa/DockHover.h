/* The label above a tile when the pointer is over it. Geometry measured on the real Dock (Mac VM, screenshot, 1280 x 800, tile size 46): a black pill 27 px high whose top is 40 px above the bar's top,
 * the text's width + 26 px wide, centred on the tile, with a 12 px wide, 5 px high pointer ending 9 px above the bar; white text.
 * SCAFFOLDING: the pointer position is polled from CoreGraphics at 60 Hz; the real Dock receives events from SkyLight (SLSSetBackgroundEventMaskAndShape / the event port): to be replaced and traced. */
#import <QuartzCore/QuartzCore.h>
#import "DockModel.h"
@interface DockHover : NSObject
- (instancetype)initWithRoot:(CALayer *)root model:(DockModel *)model;
@end
