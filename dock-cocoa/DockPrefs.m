#import "DockPrefs.h"
#import <CoreFoundation/CoreFoundation.h>
@implementation DockPrefs
/* the order of the real Dock's CFPreferencesCopyAppValue calls for the Dock's own keys */
+ (NSArray<NSString *> *)keys
{
	return @[ @"autohide-immutable", @"position-immutable", @"mineffect-immutable", @"contents-immutable", @"static-only", @"min-in-place-immutable", @"minimize-to-application-immutable",
		@"workspaces-edge-modifier-binding", @"wvous-tl-corner", @"wvous-tr-corner", @"wvous-bl-corner", @"wvous-br-corner", @"wvous-tl-modifier", @"wvous-tr-modifier", @"wvous-bl-modifier", @"wvous-br-modifier",
		@"orientation", @"mineffect", @"tilesize", @"largesize", @"magnification", @"autohide", @"launchanim", @"autohide-delay",
		@"digduration-duration", @"digduration-perframe", @"digduration-angle", @"digduration-log",
		@"version", @"static-apps", @"static-others", @"persistent-apps", @"persistent-others", @"recent-apps", @"loc", @"region",
		@"expose-sticky-time", @"force-continuity", @"use-unique-internal-dockextras" ];
}
- (instancetype)initFromPreferences
{
	if (!(self = [super init])) return nil;
	NSMutableDictionary *m = [NSMutableDictionary dictionary];
	for (NSString *k in [DockPrefs keys]) {
		CFPropertyListRef v = CFPreferencesCopyAppValue((__bridge CFStringRef)k, CFSTR("com.apple.dock"));
		if (v) { m[k] = CFBridgingRelease(v); }
	}
	_values = m;
	return self;
}
/* TODO(feature): the real Dock reads these as a side effect of using ImageIO and the Siri / Assistant support (Dock's Siri tile, search); the domains are our reading of the trace, which logs only the key */
- (void)readSystemKeys
{
	CFPropertyListRef v;
	/* the first two the real Dock reads before anything else (language of the session, App Nap delay); the global domain is our reading, the trace logs the key only */
	v = CFPreferencesCopyAppValue(CFSTR("AppleLanguages"), kCFPreferencesAnyApplication); if (v) CFRelease(v);
	v = CFPreferencesCopyAppValue(CFSTR("NSAppNapLaunchDelay"), kCFPreferencesAnyApplication); if (v) CFRelease(v);
	v = CFPreferencesCopyAppValue(CFSTR("IIOEnableOOP"), kCFPreferencesCurrentApplication); if (v) CFRelease(v);
	for (NSString *k in @[ @"Session Language", @"Additional Languages", @"Assistant Enabled" ]) {
		v = CFPreferencesCopyAppValue((__bridge CFStringRef)k, CFSTR("com.apple.assistant.support")); if (v) CFRelease(v);
	}
}
@end
