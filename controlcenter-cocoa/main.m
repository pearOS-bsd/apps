/* ControlCenter of pearOS: one source for a real macOS and for pearOS (replaces /System/Library/CoreServices/ControlCenter.app).  Goal and plan: docs/development/CONTROLCENTER-REPLACEMENT.md.
 * Skeleton: same Mach services as the real one at startup (research/cc-trace); status items, panel and behaviour come next. */
#import "CCDraw.h"
#import <Foundation/Foundation.h>
#import "CCServices.h"
#import "CCStatusBar.h"
#import "CCSkyLightStartup.h"
#import "CCPrefs.h"
#import "CCPanel.h"
#import "CCInput.h"
#import "CCControls.h"
int main(int argc, const char *argv[])
{
	@autoreleasepool {
		[CCServices connectAll];
		CCReadPreferences();
		CCSkyLightStartup();
		CCStatusBar *bar = [CCStatusBar new]; [bar start];
		CCPanel *panel = [CCPanel new]; CCInput *input = [[CCInput alloc] initWithPanel: panel controlItemFrame: CGRectMake(1094 + CCDX(), 0, 42, 30) statusBar: bar]; (void)input;
		CCNowPlayingStart();
		if (getenv("CC_OPEN")) [NSTimer scheduledTimerWithTimeInterval: 3 repeats: NO block: ^(NSTimer *t) { (void)t; [panel toggle]; }];       /* test switch: open the panel 3 s after the start, from the run loop (before it, its commit did not always reach the render server on pearOS) */
		if (getenv("CC_WINDOW")) { for (double t = 0; t < atof(getenv("CC_WINDOW")); t += 0.1) [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]]; }
		else [[NSRunLoop currentRunLoop] run];
		(void)argc; (void)argv;
	}
	return 0;
}
