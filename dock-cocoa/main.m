/* Dock: the Dock of pearOS, one source for a real macOS and for pearOS (Foundation + QuartzCore + SkyLight + CoreUI, no AppKit: like the real Dock).  Skeleton: reproduces the startup of the real Dock as seen by a trace
 * (services, preference keys); the window, tiles and behaviour come next (docs/development/DOCK-REPLACEMENT.md). */
#import <Foundation/Foundation.h>
#import "DockPrefs.h"
#import "DockServices.h"
int main(int argc, const char *argv[])
{
	@autoreleasepool {
		/* no AppKit: the real Dock does not link it (otool -L: Foundation, QuartzCore, SkyLight, CoreUI, IconServices, CoreServices ...); loading AppKit makes a process connect to pasteboard / runningboard / linkd */
		[DockServices connectAll];
		/* the strings of the Dock come from the bundle (Resources/en.lproj/Localizable.strings): Foundation reads AppleLanguages / NSTallLocalizedStrings when it localizes */
		(void)[[NSBundle mainBundle] localizedStringForKey: @"dock.options" value: @"Options" table: nil];
		DockPrefs *prefs = [[DockPrefs alloc] initFromPreferences];
		[prefs readSystemKeys];
		[DockServices checkInServer];
		if (getenv("DOCK_LOG")) NSLog(@"dock: %lu preference keys set", (unsigned long)prefs.values.count);
		(void)argc; (void)argv;
	}
	return 0;
}
