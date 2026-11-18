/* The Control Center panel window (level 22) drawn with Core Graphics: tiles, sliders, labels.  Layout measured on the real panel (Mac VM 26.7.2, 1280 x 800, research/cc-trace). */
#import <Foundation/Foundation.h>
@interface CCPanel : NSObject
@property (readonly) BOOL visible;
- (void)toggle;
- (void)hide;
- (void)redraw;                                           /* after an appearance change */
- (BOOL)clickAtScreenPoint:(CGPoint)p;                  /* a click inside the panel: YES when it belongs to the panel */
- (BOOL)containsScreenPoint:(CGPoint)p;
@end
