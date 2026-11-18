/* The menu-bar extras ControlCenter hosts (Wi-Fi, Bluetooth, Battery, Sound, Focus ...): shown when the preference `NSStatusItem VisibleCC <name>` of com.apple.controlcenter is true AND the hardware exists
 * (the real one hides a Wi-Fi item on a Mac without Wi-Fi; checked on the Mac VM: with the keys set no item appears).  CC_FORCE_EXTRAS=1 shows them anyway (tests). */
#import <Foundation/Foundation.h>
#import "CCControls.h"
@interface CCExtras : NSObject
- (instancetype)initWithAnchorX:(CGFloat)x;       /* extras are laid out right to left, ending at x (the left edge of the Spotlight item) */
- (void)sync;                                      /* creates / removes the windows to match the preferences */
- (BOOL)kindAtPoint:(CGPoint)p kind:(CCKind *)k midX:(CGFloat *)mid;
@end
