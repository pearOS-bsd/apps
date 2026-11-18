/* The gallery of "Edit Controls" (window level 23, 736 x 670 at 226,45 like the real one): categories on the left, suggestions and controls on the right; a click on a control adds it to the panel. */
#import <Foundation/Foundation.h>
#import "CCControls.h"
@class CCPanel;
@interface CCGallery : NSObject
- (instancetype)initWithPanel:(CCPanel *)panel;
- (void)close;
- (void)redraw;
- (BOOL)containsScreenPoint:(CGPoint)p;
- (BOOL)mouseDown:(CGPoint)p;
- (void)scrollBy:(double)dy;
- (void)typeText:(NSString *)s;                 /* search field; "\b" deletes */
@end
