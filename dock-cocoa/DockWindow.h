/* The window of the Dock: created with SkyLight like the real one (no AppKit).  Skeleton: a window of the bar's size at the bottom of the display, level of the Dock, ordered in. */
#import <Foundation/Foundation.h>
@interface DockWindow : NSObject
@property (readonly) uint32_t windowID;
- (instancetype)initWithFrame:(CGRect)frame level:(int)level;     /* frame in screen points, origin top-left (what SLSNewWindow... takes, checked with CGWindowListCopyWindowInfo) */
- (void)orderIn;
+ (CGRect)mainDisplayBounds;                                         /* SLSGetDisplayBounds of SLSMainDisplayID */
@end
