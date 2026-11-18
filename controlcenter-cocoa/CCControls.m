#import "CCControls.h"
#import <dlfcn.h>
#import <objc/message.h>
#import <spawn.h>
#import <crt_externs.h>
#import "CCDraw.h"

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

/* Wi-Fi: CoreWLAN (CWWiFiClient.sharedWiFiClient.interface.powerOn / setPower:error:); nil interface on a machine without a Wi-Fi card */
static id wifiInterface(void) { lib("/System/Library/Frameworks/CoreWLAN.framework/CoreWLAN"); Class C = NSClassFromString(@"CWWiFiClient"); id cl = C ? ((id (*)(Class, SEL))objc_msgSend)(C, sel_registerName("sharedWiFiClient")) : nil; return cl ? ((id (*)(id, SEL))objc_msgSend)(cl, sel_registerName("interface")) : nil; }
/* Bluetooth: IOBluetooth's preference functions (IOBluetoothPreferenceGetControllerPowerState / ...Set...) */
static int btGet(void) { void *h = lib("/System/Library/Frameworks/IOBluetooth.framework/IOBluetooth"); int (*f)(void) = h ? dlsym(h, "IOBluetoothPreferenceGetControllerPowerState") : NULL; return f ? f() : 0; }
static void btSet(int on) { void *h = lib("/System/Library/Frameworks/IOBluetooth.framework/IOBluetooth"); void (*f)(int) = h ? dlsym(h, "IOBluetoothPreferenceSetControllerPowerState") : NULL; if (f) f(on); }
/* MediaRemote */
void CCMediaCommand(int cmd) { void *h = lib("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote"); int (*f)(int, id) = h ? dlsym(h, "MRMediaRemoteSendCommand") : NULL; if (f) f(cmd, nil); }
NSString *CCNowPlayingTitle(void) { return nil; }          /* TODO(feature): MRMediaRemoteGetNowPlayingInfo (asynchronous, block based) */
/* brightness: DisplayServices; volume: CoreAudio default output device */
double CCSliderGet(CCKind k)
{
	if (k == CCDisplay) { void *h = lib("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"); int (*f)(uint32_t, float *) = h ? dlsym(h, "DisplayServicesGetBrightness") : NULL; float v = 0; if (f && f(CGMainDisplayID(), &v) == 0) return v; }
	NSNumber *n = [[NSUserDefaults standardUserDefaults] objectForKey: k == CCDisplay ? @"pearos.cc.display" : @"pearos.cc.sound"]; return n ? n.doubleValue : 0;
}
void CCSliderSet(CCKind k, double v)
{
	if (k == CCDisplay) { void *h = lib("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"); int (*f)(uint32_t, float) = h ? dlsym(h, "DisplayServicesSetBrightness") : NULL; if (f) f(CGMainDisplayID(), (float)v); }
	[[NSUserDefaults standardUserDefaults] setObject: @(v) forKey: k == CCDisplay ? @"pearos.cc.display" : @"pearos.cc.sound"];          /* TODO(feature): CoreAudio kAudioHardwareServiceDeviceProperty_VirtualMainVolume */
}
NSString *CCStateText(CCKind k)
{
	switch (k) {
	case CCWifi: { id i = wifiInterface(); return i && ((BOOL (*)(id, SEL))objc_msgSend)(i, sel_registerName("powerOn")) ? @"On" : @"Off"; }
	case CCBluetooth: return btGet() ? @"On" : @"Off";
	case CCAirDrop: { CFPropertyListRef v = CFPreferencesCopyAppValue(CFSTR("DiscoverableMode"), CFSTR("com.apple.sharingd")); NSString *s = v ? (__bridge_transfer NSString *)v : @"Off"; return [s isEqual: @"Off"] ? @"Off" : s; }
	case CCFocus: return prefBool(CFSTR("pearos.cc.focus"), CFSTR("com.apple.controlcenter")) ? @"Do Not Disturb" : nil;
	default: return nil;
	}
}
BOOL CCIsOn(CCKind k)
{
	switch (k) {
	case CCDarkMode: return CCDarkTheme();
	case CCStageManager: return prefBool(CFSTR("GloballyEnabled"), CFSTR("com.apple.WindowManager"));
	case CCWifi: case CCBluetooth: case CCAirDrop: return [CCStateText(k) isEqual: @"On"] || ([CCStateText(k) length] && ![CCStateText(k) isEqual: @"Off"]);
	case CCFocus: return prefBool(CFSTR("pearos.cc.focus"), CFSTR("com.apple.controlcenter"));
	default: return NO;
	}
}
void CCPerform(CCKind k)
{
	switch (k) {
	case CCDarkMode: CCSetDarkTheme(!CCDarkTheme()); break;
	case CCStageManager: setPrefBool(CFSTR("GloballyEnabled"), CFSTR("com.apple.WindowManager"), !CCIsOn(k)); break;       /* the Dock/WindowManager picks the preference up on its notification (TODO(verify)) */
	case CCWifi: { id i = wifiInterface(); if (i) { NSError *e = nil; ((BOOL (*)(id, SEL, BOOL, NSError **))objc_msgSend)(i, sel_registerName("setPower:error:"), !CCIsOn(k), &e); } break; }
	case CCBluetooth: btSet(!btGet()); break;
	case CCAirDrop: CFPreferencesSetAppValue(CFSTR("DiscoverableMode"), CCIsOn(k) ? CFSTR("Off") : CFSTR("Contacts Only"), CFSTR("com.apple.sharingd")); CFPreferencesAppSynchronize(CFSTR("com.apple.sharingd")); break;
	case CCFocus: setPrefBool(CFSTR("pearos.cc.focus"), CFSTR("com.apple.controlcenter"), !CCIsOn(k)); break;          /* TODO(verify): the real toggle goes through the DoNotDisturb framework */
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
