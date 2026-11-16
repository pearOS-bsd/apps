/* Dock: the Dock of pearOS, one source for a real macOS and for pearOS (Foundation + QuartzCore + SkyLight + CoreUI, no AppKit: like the real Dock).  Skeleton: reproduces the startup of the real Dock as seen by a trace
 * (services, preference keys); the window, tiles and behaviour come next (docs/development/DOCK-REPLACEMENT.md). */
#import <Foundation/Foundation.h>
#import "DockPrefs.h"
#import "DockServices.h"
#import "DockWindow.h"
#import <CoreGraphics/CoreGraphics.h>
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
		/* the window (DOCK_WINDOW=seconds keeps the process alive that long, for the checks on the Mac VM) */
		CGRect disp = [DockWindow mainDisplayBounds]; CGFloat bw = 700, bh = 80;
		DockWindow *win = [[DockWindow alloc] initWithFrame: CGRectMake(disp.origin.x + (disp.size.width - bw) / 2, disp.origin.y + disp.size.height - bh - 5, bw, bh) level: 20];      /* centred at the bottom: SkyLight window origins are top-left based (checked with the window list) */
		[win orderIn];
		if (getenv("DOCK_LOG")) NSLog(@"dock: window id %u", win.windowID);
		if (getenv("DOCK_WINDOW")) {
			CFArrayRef l = CGWindowListCopyWindowInfo(kCGWindowListOptionAll, kCGNullWindowID);
			for (NSDictionary *w in (__bridge NSArray *)l) if ([w[(id)kCGWindowOwnerPID] intValue] == getpid()) NSLog(@"dock: my window %@ level %@ bounds %@", w[(id)kCGWindowNumber], w[(id)kCGWindowLayer], w[(id)kCGWindowBounds]);
			if (l) CFRelease(l);
			[NSThread sleepForTimeInterval: atof(getenv("DOCK_WINDOW"))];
		}
		if (getenv("DOCK_LOG")) NSLog(@"dock: %lu preference keys set", (unsigned long)prefs.values.count);
		(void)argc; (void)argv;
	}
	return 0;
}
