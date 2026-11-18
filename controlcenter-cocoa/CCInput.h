/* Mouse clicks for the status items and the panel (scaffolding: a CGEvent tap, like dock-cocoa's DockInput; the real ControlCenter gets events from SkyLight). */
#import <Foundation/Foundation.h>
#import "CCPanel.h"
#import "CCStatusBar.h"
@interface CCInput : NSObject
- (instancetype)initWithPanel:(CCPanel *)panel controlItemFrame:(CGRect)f statusBar:(CCStatusBar *)bar;
@end
