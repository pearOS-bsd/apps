/* ControlCenter of pearOS: one source for a real macOS and for pearOS (replaces /System/Library/CoreServices/ControlCenter.app).  Goal and plan: docs/development/CONTROLCENTER-REPLACEMENT.md.
 * Skeleton: same Mach services as the real one at startup (research/cc-trace); status items, panel and behaviour come next. */
#import <Foundation/Foundation.h>
#import "CCServices.h"
#import "CCStatusBar.h"
#import "CCSkyLightStartup.h"
int main(int argc, const char *argv[])
{
	@autoreleasepool {
		[CCServices connectAll];
		CCSkyLightStartup();
		CCStatusBar *bar = [CCStatusBar new]; [bar start];
		if (getenv("CC_WINDOW")) { for (double t = 0; t < atof(getenv("CC_WINDOW")); t += 0.1) [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]]; }
		else [[NSRunLoop currentRunLoop] run];
		(void)argc; (void)argv;
	}
	return 0;
}
