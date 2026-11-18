#import "CCExtras.h"
#import "CCDraw.h"
#import "CCSkyLight.h"
#import "../dock-cocoa/DockWindow.h"
#import "../dock-cocoa/SkyLightAPI.h"
#import <QuartzCore/QuartzCore.h>
#import <IOKit/ps/IOPowerSources.h>
#import <objc/message.h>

typedef struct { const char *prefName; CCKind kind; const char *glyph; int width; } Extra;
static const Extra kExtras[] = {                                        /* from right to left */
	{ "Battery", CCBattery, "battery", 38 }, { "WiFi", CCWifi, "wifi", 32 }, { "Bluetooth", CCBluetooth, "bluetooth", 30 }, { "Sound", CCSound, "speaker.wave", 32 },
	{ "FocusModes", CCFocus, "moon", 30 }, { "NowPlaying", CCNowPlaying, "play", 30 }, { "ScreenMirroring", CCScreenMirroring, "mirror", 32 }, { "Display", CCDisplay, "sun.max", 30 },
	{ "AirDrop", CCAirDrop, "airdrop", 30 }, { "StageManager", CCStageManager, "stage", 30 }, { "KeyboardBrightness", CCKeyboardBrightness, "keyboard", 32 }, { "UserSwitcher", CCFastUserSwitching, "person", 30 },
};
static BOOL prefOn(const char *name)
{
	NSString *key = [@"NSStatusItem VisibleCC " stringByAppendingString: [NSString stringWithUTF8String: name]];
	CFPropertyListRef v = CFPreferencesCopyAppValue((__bridge CFStringRef)key, CFSTR("com.apple.controlcenter")); BOOL b = v && CFGetTypeID(v) == CFBooleanGetTypeID() && CFBooleanGetValue(v); if (v) CFRelease(v); return b;
}
static BOOL available(CCKind k)
{
	if (getenv("CC_FORCE_EXTRAS") || prefOn("pearos.forceExtras")) return YES;     /* test switch: defaults write com.apple.controlcenter "NSStatusItem VisibleCC pearos.forceExtras" -bool true */
	switch (k) {
	case CCBattery: { CFTypeRef i = IOPSCopyPowerSourcesInfo(); CFArrayRef l = i ? IOPSCopyPowerSourcesList(i) : NULL; BOOL has = l && CFArrayGetCount(l) > 0; if (l) CFRelease(l); if (i) CFRelease(i); return has; }
	case CCWifi: { Class C = NSClassFromString(@"CWWiFiClient"); id cl = C ? ((id (*)(Class, SEL))objc_msgSend)(C, sel_registerName("sharedWiFiClient")) : nil; return cl && ((id (*)(id, SEL))objc_msgSend)(cl, sel_registerName("interface")) != nil; }
	case CCBluetooth: return CCStateText(CCBluetooth) != nil && CFPreferencesCopyAppValue(CFSTR("ControllerPowerState"), CFSTR("/Library/Preferences/com.apple.Bluetooth")) != NULL;
	case CCFocus: return CCIsOn(CCFocus);
	default: return YES;
	}
}

@implementation CCExtras
{ CGFloat anchor; NSMutableDictionary<NSNumber *, DockWindow *> *wins; NSMutableArray<NSValue *> *frames; NSMutableArray<NSNumber *> *kinds; }
- (instancetype)initWithAnchorX:(CGFloat)x { if (!(self = [super init])) return nil; anchor = x; wins = [NSMutableDictionary dictionary]; frames = [NSMutableArray array]; kinds = [NSMutableArray array]; return self; }
- (void)sync
{
	const SkyLightAPI *sl = SkyLightLoad(); const CCSkyLight *cc = CCSkyLightLoad(); if (!sl) return;
	NSMutableArray *want = [NSMutableArray array]; CGFloat x = anchor;
	for (size_t i = 0; i < sizeof kExtras / sizeof *kExtras; i++) if (prefOn(kExtras[i].prefName) && available(kExtras[i].kind)) { x -= kExtras[i].width; [want addObject: @[ @(i), @(x) ]]; }
	NSMutableString *sig = [NSMutableString string]; for (NSArray *w in want) [sig appendFormat: @"%@@%@;", w[0], w[1]];
	static NSString *last; if ([sig isEqual: last]) return; last = [sig copy];
	for (DockWindow *w in wins.allValues) if (sl->ReleaseWindow) sl->ReleaseWindow(sl->MainConnectionID(), w.windowID);
	[wins removeAllObjects]; [frames removeAllObjects]; [kinds removeAllObjects];
	BOOL dark = CCDarkTheme(); int n = 0;
	for (NSArray *w in want) {
		const Extra *e = &kExtras[[w[0] intValue]]; CGRect f = CGRectMake([w[1] doubleValue], 0, e->width, 30);
		DockWindow *win = [[DockWindow alloc] initWithFrame: f level: 25 options: 0x10000]; if (!win) continue;
		CGContextRef c = CCBeginBitmap(f.size, CGPointZero); CCFillGrey(c, dark ? 255 : 0, 1); CGContextSetLineWidth(c, 1.6); CCGlyph(c, [NSString stringWithUTF8String: e->glyph], CGPointMake(f.size.width / 2, 15), 17);
		CALayer *l = [CALayer layer]; l.frame = CGRectMake(0, 0, f.size.width, 30); CGImageRef img = CCEndBitmap(c); l.contents = (__bridge id)img; CGImageRelease(img); [win setRootLayer: l];
		int cid = sl->MainConnectionID(); uint32_t wid = win.windowID; CFTypeRef tx = sl->TransactionCreate(cid);
		if (tx) { sl->TransactionSetWindowLevel(tx, wid, 25); if (cc->RegisterSortedWindow) cc->RegisterSortedWindow(tx, wid, 0x7fffffb0 - 0x10 * n, (__bridge CFStringRef)[NSString stringWithFormat: @"com.pearos.controlcenter.%s", e->prefName], 0x490, 2, e->width, 0); sl->TransactionOrderWindow(tx, wid, 1, 0); sl->TransactionCommit(tx, 1); CFRelease(tx); }
		wins[@(n)] = win; [frames addObject: [NSValue valueWithBytes: &f objCType: @encode(CGRect)]]; [kinds addObject: @(e->kind)]; n++;
	}
}
- (BOOL)kindAtPoint:(CGPoint)p kind:(CCKind *)k midX:(CGFloat *)mid
{
	for (NSUInteger i = 0; i < frames.count; i++) { CGRect f; [frames[i] getValue: &f]; if (CGRectContainsPoint(f, p)) { *k = [kinds[i] intValue]; *mid = CGRectGetMidX(f); return YES; } }
	return NO;
}
@end
