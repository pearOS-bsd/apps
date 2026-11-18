#import "CCControls.h"
#import <dlfcn.h>
#import <objc/message.h>
#import <spawn.h>
#import <ImageIO/ImageIO.h>
#import <crt_externs.h>
#import "CCDraw.h"
#import "CCPlatform.h"

/* ---- catalog (the gallery of the real Edit Controls: categories and suggestions seen on 26.7.2; the sets inside a category are partly guessed) ---- */
static const CCCatalogEntry kCatalog[] = {
	{ CCWifi, "wifi", "Wi-Fi", "Connectivity", "wifi", 2, 1, 0 }, { CCBluetooth, "bluetooth", "Bluetooth", "Connectivity", "bluetooth", 2, 1, 0 }, { CCAirDrop, "airdrop", "AirDrop", "Connectivity", "airdrop", 2, 1, 0 },
	{ CCNowPlaying, "nowplaying", "Now Playing", "Now Playing", "play", 2, 2, 1 }, { CCStageManager, "stage", "Stage Manager", "Desktop & Finder", "stage", 1, 1, 2 },
	{ CCScreenMirroring, "mirror", "Screen Mirroring", "Display & Brightness", "mirror", 1, 1, 3 }, { CCDarkMode, "dark", "Dark Mode", "Display & Brightness", "dark", 1, 1, 3 },
	{ CCScreenshot, "screenshot", "Screenshot", "Screenshot", "camera", 1, 1, 4 }, { CCFocus, "focus", "Focus", "Focus", "moon", 2, 1, 5 },
	{ CCDisplay, "display", "Display", "Display & Brightness", "sun.max", 4, 1, 3 }, { CCSound, "sound", "Sound", "Sound", "speaker.wave", 4, 1, 6 },
	{ CCAlarm, "alarm", "Alarm", "Clock", "alarm", 1, 1, 7 }, { CCStopwatch, "stopwatch", "Stopwatch", "Clock", "stopwatch", 1, 1, 7 }, { CCTimer, "timer", "Timer", "Clock", "timer", 1, 1, 7 },
	{ CCScene, "scene", "Scene or Accessory", "Home", "lightbulb", 2, 2, 8 }, { CCTileWindows, "tile", "Tile Windows Left & Right", "Desktop & Finder", "tile", 2, 1, 2 },
	{ CCRunShortcut, "shortcut", "Run Shortcut", "Shortcuts", "shortcut", 2, 1, 9 }, { CCVoiceMemo, "voicememo", "Voice Memo", "Voice Memos", "waveform", 1, 1, 10 },
	{ CCQuickNote, "quicknote", "Quick Note", "Notes", "note", 1, 1, 11 }, { CCRecognizeMusic, "shazam", "Recognize Music", "Music Recognition", "shazam", 2, 1, 12 },
	{ CCScreenSaver, "screensaver", "Start Screen Saver", "Lock Screen", "screensaver", 2, 2, 13 }, { CCKeyboardBrightness, "kbdbright", "Keyboard Brightness", "Display & Brightness", "keyboard", 4, 1, 3 },
	{ CCLockScreen, "lockscreen", "Lock Screen", "Lock Screen", "lock", 1, 1, 13 }, { CCFastUserSwitching, "fus", "Fast User Switching", "Fast User Switching", "person", 1, 1, 14 },
	{ CCBattery, "battery", "Battery", "Battery", "battery", 2, 1, 15 }, { CCClockMenu, "clock", "Clock", "Clock", "clock", 1, 1, 7 },
};
const CCCatalogEntry *CCCatalog(size_t *n) { if (n) *n = sizeof kCatalog / sizeof *kCatalog; return kCatalog; }
const CCCatalogEntry *CCCatalogFor(CCKind k) { for (size_t i = 0; i < sizeof kCatalog / sizeof *kCatalog; i++) if (kCatalog[i].kind == k) return &kCatalog[i]; return NULL; }
NSArray<NSString *> *CCCategories(void)
{
	return @[ @"All Controls", @"Clock", @"Connectivity", @"Desktop & Finder", @"Display & Brightness", @"Fast User Switching", @"Focus", @"Home", @"Lock Screen", @"Notes", @"Now Playing", @"Screenshot", @"Shortcuts", @"Sound", @"Battery", @"Music Recognition", @"Voice Memos" ];
}

/* ---- grid: 4 columns, pitch measured on the real panel (x 974 1050 1127 1203, rows every 76, cell 63) ---- */
static const CGFloat kX0 = 974, kY0 = 42, kPitchX = 76.33, kPitchY = 76, kCell = 63;
int CCMaxRows(void) { return 8; }
CGRect CCCellRect(int col, int row, int w, int h) { return CGRectMake(round(kX0 + col * kPitchX), kY0 + row * kPitchY, round(w * kCell + (w - 1) * (kPitchX - kCell)), h * kCell + (h - 1) * (kPitchY - kCell)); }

@implementation CCControl
- (const CCCatalogEntry *)entry { return CCCatalogFor(_kind); }
- (CGRect)frame { const CCCatalogEntry *e = [self entry]; return CCCellRect(_col, _row, e->w, e->h); }
@end

@implementation CCLayout
+ (instancetype)shared { static CCLayout *l; if (!l) { l = [CCLayout new]; [l load]; } return l; }
- (void)resetDefaults
{
	_controls = [NSMutableArray array];
	static const struct { CCKind k; int c, r; } d[] = { {CCWifi,0,0}, {CCBluetooth,0,1}, {CCAirDrop,0,2}, {CCNowPlaying,2,0}, {CCStageManager,2,2}, {CCScreenMirroring,3,2}, {CCDarkMode,0,3}, {CCScreenshot,1,3}, {CCFocus,2,3}, {CCDisplay,0,4}, {CCSound,0,5} };
	for (size_t i = 0; i < sizeof d / sizeof *d; i++) { CCControl *c = [CCControl new]; c.kind = d[i].k; c.col = d[i].c; c.row = d[i].r; [_controls addObject: c]; }
}
- (void)load
{
	[self resetDefaults];
	CFPropertyListRef v = CFPreferencesCopyAppValue(CFSTR("pearos.CCLayout"), CFSTR("com.apple.controlcenter"));       /* our key in the real domain; the real layout is stored elsewhere (not found) */
	if (v && CFGetTypeID(v) == CFArrayGetTypeID()) {
		NSMutableArray *list = [NSMutableArray array];
		for (NSDictionary *d in (__bridge NSArray *)v) { if (![d isKindOfClass: [NSDictionary class]]) continue; CCControl *c = [CCControl new]; c.kind = [d[@"k"] intValue]; c.col = [d[@"c"] intValue]; c.row = [d[@"r"] intValue]; if ([c entry]) [list addObject: c]; }
		if (list.count) _controls = list;
	}
	if (v) CFRelease(v);
}
- (void)save
{
	NSMutableArray *a = [NSMutableArray array]; for (CCControl *c in _controls) [a addObject: @{ @"k": @(c.kind), @"c": @(c.col), @"r": @(c.row) }];
	CFPreferencesSetAppValue(CFSTR("pearos.CCLayout"), (__bridge CFArrayRef)a, CFSTR("com.apple.controlcenter")); CFPreferencesAppSynchronize(CFSTR("com.apple.controlcenter"));
}
- (int)rows { int m = 0; for (CCControl *c in _controls) m = MAX(m, c.row + [c entry]->h); return m; }
- (CCControl *)controlAtPoint:(CGPoint)p { for (CCControl *c in _controls) if (CGRectContainsPoint([c frame], p)) return c; return nil; }
- (BOOL)contains:(CCKind)k { for (CCControl *c in _controls) if (c.kind == k) return YES; return NO; }
- (BOOL)fits:(int)col row:(int)row w:(int)w h:(int)h ignoring:(CCControl *)ig
{
	if (col < 0 || row < 0 || col + w > 4 || row + h > CCMaxRows()) return NO;
	for (CCControl *c in _controls) { if (c == ig) continue; const CCCatalogEntry *e = [c entry]; if (col < c.col + e->w && c.col < col + w && row < c.row + e->h && c.row < row + h) return NO; }
	return YES;
}
- (BOOL)add:(CCKind)k
{
	const CCCatalogEntry *e = CCCatalogFor(k); if (!e || [self contains: k]) return NO;
	for (int r = 0; r + e->h <= CCMaxRows(); r++) for (int c = 0; c + e->w <= 4; c++) if ([self fits: c row: r w: e->w h: e->h ignoring: nil]) { CCControl *n = [CCControl new]; n.kind = k; n.col = c; n.row = r; [_controls addObject: n]; [self save]; return YES; }
	return NO;
}
- (void)remove:(CCControl *)c { [_controls removeObject: c]; [self save]; }
- (BOOL)moveControl:(CCControl *)c toCol:(int)col row:(int)row
{
	const CCCatalogEntry *e = [c entry]; if (![self fits: col row: row w: e->w h: e->h ignoring: c]) return NO;
	c.col = col; c.row = row; [self save]; return YES;
}
@end

/* ---- actions ---- */
static void spawn(const char *path, const char *a1, const char *a2, const char *a3) { const char *argv[] = { path, a1, a2, a3, NULL }; pid_t pid; posix_spawn(&pid, path, NULL, NULL, (char *const *)argv, *_NSGetEnviron()); }
static void openApp(const char *name) { spawn("/usr/bin/open", "-a", name, NULL); }
static void *lib(const char *p) { return dlopen(p, RTLD_LAZY); }
static BOOL prefBool(CFStringRef key, CFStringRef app) { CFPropertyListRef v = CFPreferencesCopyAppValue(key, app); BOOL b = v && CFGetTypeID(v) == CFBooleanGetTypeID() && CFBooleanGetValue(v); if (v) CFRelease(v); return b; }
static void setPrefBool(CFStringRef key, CFStringRef app, BOOL b) { CFPreferencesSetAppValue(key, b ? kCFBooleanTrue : kCFBooleanFalse, app); CFPreferencesAppSynchronize(app); }

/* Focus: the DoNotDisturb framework (private; needs the com.apple.private.donotdisturb.* entitlements of the real ControlCenter, listed in docs/development/CONTROLCENTER-REPLACEMENT.md; without them the XPC call fails with BSServiceConnectionErrorDomain 3).
 * Checked on the Mac VM with a probe signed with those entitlements: take / read / invalidate an assertion works. Client identifier: com.apple.controlcenter.dnd (the real one's, Info.plist DNDClientIdentifier). */
static id dndService(void)
{
	static id svc; if (svc) return svc; lib("/System/Library/PrivateFrameworks/DoNotDisturb.framework/DoNotDisturb"); Class C = NSClassFromString(@"DNDModeAssertionService");
	if (C) svc = ((id (*)(Class, SEL, id))objc_msgSend)(C, sel_registerName("serviceForClientIdentifier:"), @"com.apple.controlcenter.dnd"); return svc;
}
/* pearOS: no DoNotDisturb framework; Focus lives in usernoted (d/bsd/usernoted, protocol WSUserNotificationRequests: setFocus: / focusWithReply:), reached over NSXPC as the earlier Control Center did.  Only one mode (on / off). */
@protocol CCUserNotifications <NSObject>
- (void)registerClientWithInfo:(NSDictionary *)info reply:(void (^)(BOOL ok))reply;
- (void)setFocus:(BOOL)on;
- (void)focusWithReply:(void (^)(BOOL on))reply;
@end
static NSXPCConnection *unConn; static BOOL unFocus;
static id<CCUserNotifications> unDaemon(void)
{
	if (!unConn) {
		unConn = [[NSXPCConnection alloc] initWithMachServiceName: @"com.apple.usernoted" options: 0]; unConn.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol: @protocol(CCUserNotifications)];
		unConn.invalidationHandler = ^{ unConn = nil; }; unConn.interruptionHandler = ^{ unConn = nil; }; [unConn resume];
		[[unConn remoteObjectProxy] registerClientWithInfo: @{ @"bundle": @"com.apple.controlcenter", @"name": @"Control Center", @"role": @"shell" } reply: ^(BOOL ok) { (void)ok; }];
	}
	return [unConn remoteObjectProxyWithErrorHandler: ^(NSError *e) { (void)e; unConn = nil; }];
}
static BOOL haveDND(void) { return dndService() != nil; }
NSString *CCFocusActiveMode(void)           /* the mode identifier of the active assertion, nil when no Focus is on */
{
	if (!haveDND()) { [unDaemon() focusWithReply: ^(BOOL on) { unFocus = on; }]; return unFocus ? @"com.apple.donotdisturb.mode.default" : nil; }
	id s = dndService(); NSError *e = nil;
	id a = ((id (*)(id, SEL, NSError **))objc_msgSend)(s, sel_registerName("activeModeAssertionWithError:"), &e); if (!a) return nil;
	id d = ((id (*)(id, SEL))objc_msgSend)(a, sel_registerName("details")); return d ? ((id (*)(id, SEL))objc_msgSend)(d, sel_registerName("modeIdentifier")) : nil;
}
void CCFocusSet(NSString *mode)             /* mode nil: turn the active Focus off */
{
	if (!haveDND()) { unFocus = mode != nil; [unDaemon() setFocus: unFocus]; return; }
	id s = dndService(); NSError *e = nil;
	if (!mode) { ((id (*)(id, SEL, NSError **))objc_msgSend)(s, sel_registerName("invalidateActiveModeAssertionWithError:"), &e); return; }
	id life = ((id (*)(Class, SEL))objc_msgSend)(NSClassFromString(@"DNDModeAssertionLifetime"), sel_registerName("lifetimeForUserRequest"));
	id d = ((id (*)(Class, SEL, id, id, id))objc_msgSend)(NSClassFromString(@"DNDModeAssertionDetails"), sel_registerName("userRequestedAssertionDetailsWithIdentifier:modeIdentifier:lifetime:"), @"com.apple.controlcenter.dnd", mode, life);
	((id (*)(id, SEL, id, NSError **))objc_msgSend)(s, sel_registerName("takeModeAssertionWithDetails:error:"), d, &e);
}
NSString *CCFocusName(NSString *mode)
{
	static NSDictionary *n; if (!n) n = @{ @"com.apple.donotdisturb.mode.default": @"Do Not Disturb", @"com.apple.sleep.sleep-mode": @"Sleep", @"com.apple.focus.personal-time": @"Personal", @"com.apple.focus.work": @"Work", @"com.apple.donotdisturb.mode.driving": @"Driving", @"com.apple.focus.reading": @"Reading", @"com.apple.focus.gaming": @"Gaming", @"com.apple.focus.mindfulness": @"Mindfulness", @"com.apple.focus.fitness": @"Fitness" };
	return n[mode] ?: mode;
}
/* Wi-Fi: CoreWLAN (CWWiFiClient.sharedWiFiClient.interface.powerOn / setPower:error:); nil interface on a machine without a Wi-Fi card */
static id wifiInterface(void) { lib("/System/Library/Frameworks/CoreWLAN.framework/CoreWLAN"); Class C = NSClassFromString(@"CWWiFiClient"); id cl = C ? ((id (*)(Class, SEL))objc_msgSend)(C, sel_registerName("sharedWiFiClient")) : nil; return cl ? ((id (*)(id, SEL))objc_msgSend)(cl, sel_registerName("interface")) : nil; }
/* Bluetooth: IOBluetooth's preference functions (IOBluetoothPreferenceGetControllerPowerState / ...Set...) */
static int btGet(void) { void *h = lib("/System/Library/Frameworks/IOBluetooth.framework/IOBluetooth"); int (*f)(void) = h ? dlsym(h, "IOBluetoothPreferenceGetControllerPowerState") : NULL; if (f) return f(); int p = ccp_bluetooth_power(); return p > 0; }
static void btSet(int on) { void *h = lib("/System/Library/Frameworks/IOBluetooth.framework/IOBluetooth"); void (*f)(int) = h ? dlsym(h, "IOBluetoothPreferenceSetControllerPowerState") : NULL; if (f) f(on); else ccp_bluetooth_set(on); }
/* MediaRemote */
void CCMediaCommand(int cmd) { void *h = lib("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote"); int (*f)(int, id) = h ? dlsym(h, "MRMediaRemoteSendCommand") : NULL; if (f) f(cmd, nil); }
static NSString *npTitle, *npArtist; static CGImageRef npArt; static BOOL npPlaying;
NSString *CCNowPlayingTitle(void) { return npTitle; }
NSString *CCNowPlayingArtist(void) { return npArtist; }
CGImageRef CCNowPlayingArtwork(void) { return npArt; }
BOOL CCNowPlayingIsPlaying(void) { return npPlaying; }
void CCNowPlayingStart(void)
{
	void *h = lib("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote"); if (!h) return;
	void (*info)(dispatch_queue_t, void (^)(CFDictionaryRef)) = dlsym(h, "MRMediaRemoteGetNowPlayingInfo");
	void (*playing)(dispatch_queue_t, void (^)(Boolean)) = dlsym(h, "MRMediaRemoteGetNowPlayingApplicationIsPlaying");
	if (!info) return;
	[NSTimer scheduledTimerWithTimeInterval: 1 repeats: YES block: ^(NSTimer *t) { (void)t;
		info(dispatch_get_main_queue(), ^(CFDictionaryRef d) {
			NSDictionary *n = (__bridge NSDictionary *)d; npTitle = n[@"kMRMediaRemoteNowPlayingInfoTitle"]; npArtist = n[@"kMRMediaRemoteNowPlayingInfoArtist"];
			NSData *art = n[@"kMRMediaRemoteNowPlayingInfoArtworkData"]; if (npArt) { CGImageRelease(npArt); npArt = NULL; }
			if (art) { CGImageSourceRef s = CGImageSourceCreateWithData((__bridge CFDataRef)art, NULL); if (s) { npArt = CGImageSourceCreateImageAtIndex(s, 0, NULL); CFRelease(s); } }
		});
		if (playing) playing(dispatch_get_main_queue(), ^(Boolean p) { npPlaying = p; });
	}];
}
/* brightness: DisplayServices; volume: CoreAudio default output device */
double CCSliderGet(CCKind k)
{
	if (k == CCDisplay) { void *h = lib("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"); int (*f)(uint32_t, float *) = h ? dlsym(h, "DisplayServicesGetBrightness") : NULL; float v = 0; if (f && f(CGMainDisplayID(), &v) == 0) return v; }
	{ double v = k == CCDisplay ? ccp_brightness_get() : k == CCKeyboardBrightness ? ccp_kbd_get() : ccp_volume_get(); if (v >= 0) return v; }       /* FreeBSD: backlight(8) / ACPI, clevo_dchu, mixer(8) */
	NSNumber *n = [[NSUserDefaults standardUserDefaults] objectForKey: k == CCDisplay ? @"pearos.cc.display" : @"pearos.cc.sound"]; return n ? n.doubleValue : 0;
}
void CCSliderSet(CCKind k, double v)
{
	if (k == CCDisplay) { void *h = lib("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"); int (*f)(uint32_t, float) = h ? dlsym(h, "DisplayServicesSetBrightness") : NULL; if (f) f(CGMainDisplayID(), (float)v); }
	if (k == CCDisplay) ccp_brightness_set(v); else if (k == CCKeyboardBrightness) ccp_kbd_set(v); else ccp_volume_set(v);
	[[NSUserDefaults standardUserDefaults] setObject: @(v) forKey: k == CCDisplay ? @"pearos.cc.display" : @"pearos.cc.sound"];          /* TODO(feature): CoreAudio kAudioHardwareServiceDeviceProperty_VirtualMainVolume */
}
NSString *CCStateText(CCKind k)
{
	switch (k) {
	case CCWifi: { id i = wifiInterface(); if (!i) return ccp_wifi_power() > 0 ? @"On" : @"Off"; return ((BOOL (*)(id, SEL))objc_msgSend)(i, sel_registerName("powerOn")) ? @"On" : @"Off"; }
	case CCBluetooth: return btGet() ? @"On" : @"Off";
	case CCAirDrop: { CFPropertyListRef v = CFPreferencesCopyAppValue(CFSTR("DiscoverableMode"), CFSTR("com.apple.sharingd")); NSString *s = v ? (__bridge_transfer NSString *)v : @"Off"; return [s isEqual: @"Off"] ? @"Off" : s; }
	case CCFocus: { NSString *m = CCFocusActiveMode(); return m ? CCFocusName(m) : nil; }
	default: return nil;
	}
}
BOOL CCIsOn(CCKind k)
{
	switch (k) {
	case CCDarkMode: return CCDarkTheme();
	case CCStageManager: return prefBool(CFSTR("GloballyEnabled"), CFSTR("com.apple.WindowManager"));
	case CCWifi: case CCBluetooth: case CCAirDrop: return [CCStateText(k) isEqual: @"On"] || ([CCStateText(k) length] && ![CCStateText(k) isEqual: @"Off"]);
	case CCFocus: return CCFocusActiveMode() != nil;
	default: return NO;
	}
}
void CCPerform(CCKind k)
{
	switch (k) {
	case CCDarkMode: CCSetDarkTheme(!CCDarkTheme()); break;
	case CCStageManager: setPrefBool(CFSTR("GloballyEnabled"), CFSTR("com.apple.WindowManager"), !CCIsOn(k)); break;       /* the Dock/WindowManager picks the preference up on its notification (TODO(verify)) */
	case CCWifi: { id i = wifiInterface(); if (!i) { ccp_wifi_set(!CCIsOn(k)); break; } { NSError *e = nil; ((BOOL (*)(id, SEL, BOOL, NSError **))objc_msgSend)(i, sel_registerName("setPower:error:"), !CCIsOn(k), &e); } break; }
	case CCBluetooth: btSet(!btGet()); break;
	case CCAirDrop: CFPreferencesSetAppValue(CFSTR("DiscoverableMode"), CCIsOn(k) ? CFSTR("Off") : CFSTR("Contacts Only"), CFSTR("com.apple.sharingd")); CFPreferencesAppSynchronize(CFSTR("com.apple.sharingd")); break;
	case CCFocus: CCFocusSet(CCIsOn(k) ? nil : @"com.apple.donotdisturb.mode.default"); break;
	case CCScreenshot: openApp("Screenshot"); break;
	case CCScreenMirroring: spawn("/usr/bin/open", "x-apple.systempreferences:com.apple.Displays-Settings.extension", NULL, NULL); break;
	case CCAlarm: case CCStopwatch: case CCTimer: case CCClockMenu: openApp("Clock"); break;
	case CCVoiceMemo: openApp("Voice Memos"); break;
	case CCQuickNote: openApp("Notes"); break;
	case CCRecognizeMusic: openApp("Shazam"); break;
	case CCScreenSaver: openApp("ScreenSaverEngine"); break;
	case CCRunShortcut: openApp("Shortcuts"); break;
	case CCLockScreen: { void *h = lib("/System/Library/PrivateFrameworks/login.framework/login"); void (*f)(void) = h ? dlsym(h, "SACLockScreenImmediate") : NULL; if (f) f(); break; }
	case CCNowPlaying: CCMediaCommand(2); break;
	default: break;
	}
}

/* ---- detail pages ---- */
@implementation CCRow
+ (instancetype)row:(CCRowType)t title:(NSString *)s on:(BOOL)on action:(void (^)(void))a { CCRow *r = [CCRow new]; r.type = t; r.title = s; r.on = on; r.action = a; return r; }
@end
void CCOpenSettings(NSString *pane) { spawn("/usr/bin/open", [[@"x-apple.systempreferences:" stringByAppendingString: pane] UTF8String], NULL, NULL); }

/* ---- lists inside the pages ---- */
/* CoreAudio through dlsym (pearOS has no CoreAudio yet: then /dev/sndstat through CCPlatform) */
typedef struct { uint32_t selector, scope, element; } CCAddr;
static NSArray *audioOutputs(uint32_t *current)       /* [{id, name}] ; *current = the default output device id (0 unknown) */
{
	void *h = lib("/System/Library/Frameworks/CoreAudio.framework/CoreAudio"); if (!h) return nil;
	int (*size)(uint32_t, const CCAddr *, uint32_t, const void *, uint32_t *) = dlsym(h, "AudioObjectGetPropertyDataSize");
	int (*get)(uint32_t, const CCAddr *, uint32_t, const void *, uint32_t *, void *) = dlsym(h, "AudioObjectGetPropertyData"); if (!size || !get) return nil;
	CCAddr devs = { 'dev#', 'glob', 0 }, def = { 'dOut', 'glob', 0 }, name = { 'lnam', 'glob', 0 }, streams = { 'stm#', 'outp', 0 };
	uint32_t n = 0; if (size(1, &devs, 0, NULL, &n) != 0 || !n) return @[]; uint32_t *ids = malloc(n); if (get(1, &devs, 0, NULL, &n, ids) != 0) { free(ids); return @[]; }
	if (current) { uint32_t d = 0, ds = sizeof d; get(1, &def, 0, NULL, &ds, &d); *current = d; }
	NSMutableArray *out = [NSMutableArray array];
	for (uint32_t i = 0; i < n / sizeof *ids; i++) { uint32_t sn = 0; if (size(ids[i], &streams, 0, NULL, &sn) != 0 || !sn) continue; CFStringRef nm = NULL; uint32_t ns = sizeof nm; get(ids[i], &name, 0, NULL, &ns, &nm); [out addObject: @{ @"id": @(ids[i]), @"name": nm ? (__bridge_transfer NSString *)nm : @"Output" }]; }
	free(ids); return out;
}
static void audioSetDefault(uint32_t dev) { void *h = lib("/System/Library/Frameworks/CoreAudio.framework/CoreAudio"); int (*set)(uint32_t, const CCAddr *, uint32_t, const void *, uint32_t, const void *) = h ? dlsym(h, "AudioObjectSetPropertyData") : NULL; CCAddr def = { 'dOut', 'glob', 0 }; if (set) set(1, &def, 0, NULL, sizeof dev, &dev); }
static NSArray<CCRow *> *soundRows(void)
{
	NSMutableArray *rows = [NSMutableArray arrayWithObject: [CCRow row: CCRowHeader title: @"Output" on: NO action: nil]];
	uint32_t cur = 0; NSArray *outs = audioOutputs(&cur);
	if (outs) for (NSDictionary *d in outs) { uint32_t i = [d[@"id"] unsignedIntValue]; [rows addObject: [CCRow row: CCRowRadio title: d[@"name"] on: i == cur action: ^{ audioSetDefault(i); }]]; }
	else { char nm[16][64]; int dflt = -1, n = ccp_sound_list(nm, 16, &dflt); for (int i = 0; i < n; i++) { int k = i; [rows addObject: [CCRow row: CCRowRadio title: [NSString stringWithUTF8String: nm[i]] on: i == dflt action: ^{ ccp_sound_set(k); }]]; } }
	[rows addObject: [CCRow row: CCRowLink title: @"Sound Settings…" on: NO action: ^{ CCOpenSettings(@"com.apple.Sound-Settings.extension"); }]]; return rows;
}
static NSArray<CCRow *> *wifiRows(void)
{
	NSMutableArray *rows = [NSMutableArray arrayWithObject: [CCRow row: CCRowSwitch title: @"Wi-Fi" on: CCIsOn(CCWifi) action: ^{ CCPerform(CCWifi); }]];
	if (CCIsOn(CCWifi)) {
		[rows addObject: [CCRow row: CCRowHeader title: @"Other Networks" on: NO action: nil]];
		id i = wifiInterface(); NSString *cur = i ? ((id (*)(id, SEL))objc_msgSend)(i, sel_registerName("ssid")) : nil;
		if (i) { NSError *e = nil; NSSet *nets = ((id (*)(id, SEL, id, NSError **))objc_msgSend)(i, sel_registerName("scanForNetworksWithName:error:"), nil, &e);
			for (id n in nets) { NSString *s = ((id (*)(id, SEL))objc_msgSend)(n, sel_registerName("ssid")); if (s.length && rows.count < 9) [rows addObject: [CCRow row: CCRowRadio title: s on: [s isEqual: cur] action: ^{ CCOpenSettings(@"com.apple.wifi-settings-extension"); }]]; } }
		else { char nm[16][64]; int n = ccp_wifi_scan(nm, 8); for (int k = 0; k < n; k++) [rows addObject: [CCRow row: CCRowRadio title: [NSString stringWithUTF8String: nm[k]] on: NO action: ^{ CCOpenSettings(@"com.apple.wifi-settings-extension"); }]]; }
	}
	[rows addObject: [CCRow row: CCRowLink title: @"Wi-Fi Settings…" on: NO action: ^{ CCOpenSettings(@"com.apple.wifi-settings-extension"); }]]; return rows;
}
static NSArray<CCRow *> *bluetoothRows(void)
{
	NSMutableArray *rows = [NSMutableArray arrayWithObject: [CCRow row: CCRowSwitch title: @"Bluetooth" on: CCIsOn(CCBluetooth) action: ^{ CCPerform(CCBluetooth); }]];
	if (CCIsOn(CCBluetooth)) {
		lib("/System/Library/Frameworks/IOBluetooth.framework/IOBluetooth"); Class D = NSClassFromString(@"IOBluetoothDevice");
		NSArray *paired = D ? ((id (*)(Class, SEL))objc_msgSend)(D, sel_registerName("pairedDevices")) : nil;
		for (id d in paired) { if (rows.count >= 8) break; NSString *nm = ((id (*)(id, SEL))objc_msgSend)(d, sel_registerName("name")); BOOL on = ((BOOL (*)(id, SEL))objc_msgSend)(d, sel_registerName("isConnected"));
			[rows addObject: [CCRow row: CCRowRadio title: nm ?: @"Device" on: on action: ^{ if (on) ((int (*)(id, SEL))objc_msgSend)(d, sel_registerName("closeConnection")); else ((int (*)(id, SEL))objc_msgSend)(d, sel_registerName("openConnection")); }]]; }
	}
	[rows addObject: [CCRow row: CCRowLink title: @"Bluetooth Settings…" on: NO action: ^{ CCOpenSettings(@"com.apple.BluetoothSettings"); }]]; return rows;
}
/* Focus modes: DNDModeConfigurationService (same client identifier and entitlements as the assertion service) */
static NSArray<CCRow *> *focusRows(void)
{
	NSString *cur = CCFocusActiveMode(); NSMutableArray *rows = [NSMutableArray arrayWithObject: [CCRow row: CCRowHeader title: @"Focus" on: NO action: nil]]; NSMutableArray *ids = [NSMutableArray array];
	lib("/System/Library/PrivateFrameworks/DoNotDisturb.framework/DoNotDisturb"); Class S = NSClassFromString(@"DNDModeConfigurationService");
	if (S) { id svc = ((id (*)(Class, SEL, id))objc_msgSend)(S, sel_registerName("serviceForClientIdentifier:"), @"com.apple.controlcenter.dnd"); NSError *e = nil; NSArray *cfgs = svc ? ((id (*)(id, SEL, NSError **))objc_msgSend)(svc, sel_registerName("modeConfigurationsReturningError:"), &e) : nil;
		for (id cfg in ([cfgs isKindOfClass: [NSDictionary class]] ? [(NSDictionary *)cfgs allValues] : cfgs)) { id m = ((id (*)(id, SEL))objc_msgSend)(cfg, sel_registerName("mode")); NSString *mid = ((id (*)(id, SEL))objc_msgSend)(m, sel_registerName("modeIdentifier")), *nm = ((id (*)(id, SEL))objc_msgSend)(m, sel_registerName("name")); if (mid && nm && rows.count < 9) { [ids addObject: mid]; NSString *mm = mid; [rows addObject: [CCRow row: CCRowRadio title: nm on: [cur isEqual: mid] action: ^{ CCFocusSet([cur isEqual: mm] ? nil : mm); }]]; } } }
	if (!ids.count) for (NSString *m in @[ @"com.apple.donotdisturb.mode.default", @"com.apple.sleep.sleep-mode", @"com.apple.focus.personal-time", @"com.apple.focus.work" ]) [rows addObject: [CCRow row: CCRowRadio title: CCFocusName(m) on: [cur isEqual: m] action: ^{ CCFocusSet([cur isEqual: m] ? nil : m); }]];
	[rows addObject: [CCRow row: CCRowLink title: @"Focus Settings…" on: NO action: ^{ CCOpenSettings(@"com.apple.Focus-Settings.extension"); }]]; return rows;
}
NSArray<CCRow *> *CCPageRows(CCKind k)
{
	switch (k) {
	case CCWifi: return wifiRows();
	case CCBluetooth: return bluetoothRows();
	case CCAirDrop: {
		NSString *m = CCStateText(CCAirDrop); void (^set)(NSString *) = ^(NSString *v) { CFPreferencesSetAppValue(CFSTR("DiscoverableMode"), (__bridge CFStringRef)v, CFSTR("com.apple.sharingd")); CFPreferencesAppSynchronize(CFSTR("com.apple.sharingd")); };
		return @[ [CCRow row: CCRowHeader title: @"AirDrop" on: NO action: nil], [CCRow row: CCRowRadio title: @"Contacts Only" on: [m isEqual: @"Contacts Only"] action: ^{ set(@"Contacts Only"); }],
			[CCRow row: CCRowRadio title: @"Everyone for 10 Minutes" on: [m isEqual: @"Everyone"] action: ^{ set(@"Everyone"); }], [CCRow row: CCRowLink title: @"AirDrop Settings…" on: NO action: ^{ CCOpenSettings(@"com.apple.Sharing-Settings.extension"); }] ]; }
	case CCFocus: return focusRows();
	case CCSound: return soundRows();
	case CCDisplay: return @[ [CCRow row: CCRowHeader title: @"Display" on: NO action: nil], [CCRow row: CCRowSwitch title: @"Dark Mode" on: CCDarkTheme() action: ^{ CCPerform(CCDarkMode); }], [CCRow row: CCRowLink title: @"Display Settings…" on: NO action: ^{ CCOpenSettings(@"com.apple.Displays-Settings.extension"); }] ];
	default: return nil;
	}
}
