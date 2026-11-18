/* The Control Center panel window (level 22) drawn with Core Graphics from the layout model: tiles, sliders, edit mode.  Measured on the real panel (Mac VM 26.7.2, 1280 x 800, research/cc-trace). */
#import <Foundation/Foundation.h>
#import "CCControls.h"
extern NSString *const CCEditModeChanged;
@interface CCPanel : NSObject
@property (readonly) BOOL visible;
@property (readonly) BOOL editing;
- (void)toggle;
- (void)hide;
- (void)redraw;                                           /* after any change of state, layout or appearance */
- (void)setEditing:(BOOL)on;                              /* "Edit Controls" / "Done" */
- (BOOL)addControl:(CCKind)k;                             /* from the gallery */
- (BOOL)containsScreenPoint:(CGPoint)p;
- (BOOL)mouseDown:(CGPoint)p;                             /* YES when the panel used the event */
- (BOOL)mouseDragged:(CGPoint)p;
- (BOOL)mouseUp:(CGPoint)p;
- (void)scrollGallery:(double)dy;
- (void)typeInGallery:(NSString *)s;
@end
