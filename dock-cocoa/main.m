/* Dock: the Dock of pearOS, one source for a real macOS and for pearOS (Cocoa API).  Skeleton: reproduces the startup of the real Dock as seen by a trace
 * (services, preference keys); the window, tiles and behaviour come next (docs/development/DOCK-REPLACEMENT.md). */
#import <Cocoa/Cocoa.h>
#import "DockPrefs.h"
#import "DockServices.h"
int main(int argc, const char *argv[])
{
	@autoreleasepool {
		[NSApplication sharedApplication];
		[DockServices connectAll];
		DockPrefs *prefs = [[DockPrefs alloc] initFromPreferences];
		[DockServices checkInServer];
		if (getenv("DOCK_LOG")) NSLog(@"dock: %lu preference keys set", (unsigned long)prefs.values.count);
		(void)argc; (void)argv;
	}
	return 0;
}
