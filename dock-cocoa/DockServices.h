/* The Mach services the real Dock talks to or provides, in the order of its startup (research/dock-trace).  Each step is a real connection, so that a trace of this Dock shows the same
 * look-ups and check-ins.  Where the real Dock gets a connection as a side effect of using a framework, this file makes it explicitly until the feature that causes it is written
 * (every such line is marked TODO(feature)): it is scaffolding, not the final structure. */
#import <Foundation/Foundation.h>
@interface DockServices : NSObject
+ (void)connectAll;                       /* the startup sequence */
+ (void)checkInServer;                    /* com.apple.dock.server (the CoreDock API other programs call) */
@end
