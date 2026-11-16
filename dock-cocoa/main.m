/* Dock: the Dock of pearOS, one source for a real macOS and for pearOS (Foundation + QuartzCore + SkyLight + CoreUI, no AppKit: like the real Dock).  Skeleton: reproduces the startup of the real Dock as seen by a trace
 * (services, preference keys); the window, tiles and behaviour come next (docs/development/DOCK-REPLACEMENT.md). */
#import <Foundation/Foundation.h>
#import "DockPrefs.h"
#import "DockServices.h"
#import "DockWindow.h"
#import "DockModel.h"
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
		/* like the real Dock: ONE window the size of the display at level 20 (the bar is drawn inside it); its bar geometry comes from the tiles */
		CGRect disp = [DockWindow mainDisplayBounds];
		DockModel *model = [[DockModel alloc] initWithPrefs: prefs displayBounds: disp];
		DockWindow *win = [[DockWindow alloc] initWithFrame: disp level: 20];
		[win orderIn];
		if (getenv("DOCK_LOG")) NSLog(@"dock: window id %u, %lu tiles, bar %@", win.windowID, (unsigned long)model.tiles.count, NSStringFromRect(NSRectFromCGRect(model.barRect)));
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
