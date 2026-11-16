/* A context menu drawn with layers (no AppKit). Rows have a title, optional check mark, an optional action, an optional submenu; the first row can be a bold title.
 * Look: APPROXIMATE (dark rounded panel, blue highlight): not measured on the real Dock's menu yet. */
#import <QuartzCore/QuartzCore.h>
@interface DockMenuItem : NSObject
@property (copy) NSString *title; @property BOOL enabled, checked, isTitle, isSeparator; @property (copy) void (^action)(void); @property (strong) NSArray<DockMenuItem *> *submenu;
+ (instancetype)item:(NSString *)title action:(void (^)(void))action;
+ (instancetype)separator;
@end
@interface DockMenu : NSObject
@property (readonly) CGRect frame;
@property BOOL leftTop;                    /* the anchor is the panel's top-left corner (a submenu) instead of the bottom centre */
- (instancetype)initWithItems:(NSArray<DockMenuItem *> *)items;
- (void)showInLayer:(CALayer *)root at:(CGPoint)anchorBottomCentre displayHeight:(CGFloat)h;      /* the panel's bottom edge is at the anchor, centred on x, above the tile */
- (void)close;
- (BOOL)containsPoint:(CGPoint)p;
- (void)mouseMovedTo:(CGPoint)p;          /* highlight, open a submenu */
- (BOOL)clickAt:(CGPoint)p;               /* YES when a row was activated (the menu closes) */
@end
