#include <string.h>
#import "CCBento.h"

static NSString *const kBoxesDomain = @"com.apple.controlcenter.bentoboxes", *const kMainDomain = @"com.apple.controlcenter", *const kChronoKey = @"ControlCenterDisplayableChronoControlsProviderConfiguration";

/* a preference as Data: through CFPreferences, else straight from the file (ByHost: the file whose name starts with the domain) */
static NSString *prefFile(NSString *domain, BOOL byHost)
{
	NSString *over = getenv(byHost ? "CC_BENTO_FILE" : "CC_CHRONO_FILE") ? @(getenv(byHost ? "CC_BENTO_FILE" : "CC_CHRONO_FILE")) : nil; if (over) return over;
	NSString *dir = [NSHomeDirectory() stringByAppendingPathComponent: byHost ? @"Library/Preferences/ByHost" : @"Library/Preferences"];
	if (!byHost) return [dir stringByAppendingPathComponent: [domain stringByAppendingString: @".plist"]];
	for (NSString *f in [[NSFileManager defaultManager] contentsOfDirectoryAtPath: dir error: NULL]) if ([f hasPrefix: [domain stringByAppendingString: @"."]] && [f hasSuffix: @".plist"]) return [dir stringByAppendingPathComponent: f];
	return nil;
}
static NSMutableDictionary *readFile(NSString *path) { NSData *d = path ? [NSData dataWithContentsOfFile: path] : nil; if (!d) return nil; id o = [NSPropertyListSerialization propertyListWithData: d options: NSPropertyListMutableContainers format: NULL error: NULL]; return [o isKindOfClass: [NSMutableDictionary class]] ? o : nil; }

@implementation CCBento
{
	NSMutableDictionary *boxFile, *mainFile;                   /* the whole plists, when they were read from files */
	NSString *boxPath, *mainPath;
	NSMutableArray *boxes; NSMutableDictionary *box, *grid, *disp; NSMutableArray *modules, *chronoIds, *instanceIds; NSMutableDictionary *chrono; NSMutableArray *chronoControls;
	NSMutableArray<CCControl *> *placed; NSMutableArray *preserved;      /* elements that this program does not know: written back as they were */
}
- (NSArray<CCControl *> *)controls { return placed; }

static NSData *prefValue(NSString *key, NSString *domain, BOOL byHost, NSMutableDictionary **fileOut, NSString **pathOut)
{
	NSString *path = prefFile(domain, byHost);
	if (!getenv(byHost ? "CC_BENTO_FILE" : "CC_CHRONO_FILE")) {
		CFPropertyListRef v = CFPreferencesCopyValue((__bridge CFStringRef)key, (__bridge CFStringRef)domain, kCFPreferencesCurrentUser, byHost ? kCFPreferencesCurrentHost : kCFPreferencesAnyHost);
		if (v) { id o = CFBridgingRelease(v); if ([o isKindOfClass: [NSData class]]) return o; if ([o isKindOfClass: [NSString class]]) return [(NSString *)o dataUsingEncoding: NSUTF8StringEncoding]; }
	}
	NSMutableDictionary *f = readFile(path); if (!f) return nil; if (fileOut) *fileOut = f; if (pathOut) *pathOut = path;
	id o = f[key]; if ([o isKindOfClass: [NSData class]]) return o; if ([o isKindOfClass: [NSString class]]) return [(NSString *)o dataUsingEncoding: NSUTF8StringEncoding];
	return nil;
}
/* base64 (the open Foundation of the build lacks NSData's) */
static NSData *b64decode(NSString *s)
{
	static signed char t[256]; static BOOL init; if (!init) { memset(t, -1, sizeof t); const char *a = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"; for (int i = 0; i < 64; i++) t[(unsigned char)a[i]] = (signed char)i; init = YES; }
	NSData *in = [s dataUsingEncoding: NSASCIIStringEncoding]; NSMutableData *out = [NSMutableData data]; unsigned acc = 0; int bits = 0; const unsigned char *p = in.bytes;
	for (NSUInteger i = 0; i < in.length; i++) { int v = t[p[i]]; if (v < 0) continue; acc = (acc << 6) | (unsigned)v; bits += 6; if (bits >= 8) { bits -= 8; unsigned char b = (unsigned char)(acc >> bits); [out appendBytes: &b length: 1]; acc &= (1u << bits) - 1; } }
	return out;
}
static NSString *b64encode(NSData *d)
{
	static const char *a = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"; NSMutableString *o = [NSMutableString string]; const unsigned char *p = d.bytes; NSUInteger n = d.length;
	for (NSUInteger i = 0; i < n; i += 3) { unsigned v = p[i] << 16 | (i + 1 < n ? p[i + 1] << 8 : 0) | (i + 2 < n ? p[i + 2] : 0); [o appendFormat: @"%c%c%c%c", a[v >> 18 & 63], a[v >> 12 & 63], i + 1 < n ? a[v >> 6 & 63] : '=', i + 2 < n ? a[v & 63] : '=']; }
	return o;
}
static NSString *newUUID(void) { CFUUIDRef u = CFUUIDCreate(NULL); NSString *s = CFBridgingRelease(CFUUIDCreateString(NULL, u)); CFRelease(u); return s; }
static id jsonMutable(NSData *d) { return d ? [NSJSONSerialization JSONObjectWithData: d options: (NSUInteger)3 /* NSJSONReadingMutableContainers | NSJSONReadingMutableLeaves */ error: NULL] : nil; }
static id plistMutable(NSData *d) { return d ? [NSPropertyListSerialization propertyListWithData: d options: NSPropertyListMutableContainers format: NULL error: NULL] : nil; }
static NSData *plistBinary(id o) { return [NSPropertyListSerialization dataWithPropertyList: o format: NSPropertyListBinaryFormat_v1_0 options: 0 error: NULL]; }

/* size names <-> cells */
static BOOL cellsOfName(NSString *n, int *w, int *h)
{
	static NSDictionary *m; if (!m) m = @{ @"square1x1": @[@1, @1], @"rect2x1": @[@2, @1], @"square2x2": @[@2, @2], @"rect4x1": @[@4, @1], @"rect1x2": @[@1, @2] };
	NSArray *a = m[n]; if (!a) return NO; *w = [a[0] intValue]; *h = [a[1] intValue]; return YES;
}
static NSString *nameOfCells(int w, int h)
{
	if (w == 1 && h == 1) return @"square1x1"; if (w == 2 && h == 1) return @"rect2x1"; if (w == 2 && h == 2) return @"square2x2"; if (w == 4 && h == 1) return @"rect4x1"; if (w == 1 && h == 2) return @"rect1x2"; return nil;
}
static NSString *moduleSizeOf(int w, int h) { return (w == 1 && h == 1) ? @"small" : (w == 2 && h == 1) ? @"medium" : @"large"; }
static NSDictionary *moduleKinds(void)
{
	return @{ @"WiFi": @(CCWifi), @"Bluetooth": @(CCBluetooth), @"AirDrop": @(CCAirDrop), @"NowPlaying": @(CCNowPlaying), @"Display": @(CCDisplay), @"Sound": @(CCSound), @"FocusModes": @(CCFocus),
		@"ScreenMirroring": @(CCScreenMirroring), @"Battery": @(CCBattery), @"KeyboardBrightness": @(CCKeyboardBrightness) };
}
static NSString *moduleIdOf(CCKind k) { for (NSString *m in moduleKinds()) if ([moduleKinds()[m] intValue] == k) return m; return nil; }
/* the chrono controls (extensions) that the catalog knows: a piece of the kind identifier inside the archived identity */
static int chronoKindOf(NSString *b64)
{
	NSData *d = b64decode(b64 ?: @""); if (!d.length) return -1;
	NSString *s = [[NSString alloc] initWithData: d encoding: NSISOLatin1StringEncoding];
	static const struct { const char *piece; int kind; } t[] = { { "display.screen-saver", CCScreenSaver }, { "display.true-tone", CCTrueTone }, { "display.night-shift", CCNightShift }, { "display.dark-mode", CCDarkMode }, { "stagemanager", CCStageManager } };
	for (size_t i = 0; i < sizeof t / sizeof *t; i++) if ([s rangeOfString: @(t[i].piece)].location != NSNotFound) return t[i].kind;
	return -1;
}

+ (instancetype)load
{
	CCBento *b = [CCBento new]; NSMutableDictionary *f = nil; NSString *p = nil;
	NSData *raw = prefValue(@"boxes", kBoxesDomain, YES, &f, &p); if (!raw) return nil; b->boxFile = f; b->boxPath = p;
	b->boxes = jsonMutable(raw); if (![b->boxes isKindOfClass: [NSMutableArray class]] || !b->boxes.count) return nil;
	b->box = b->boxes[0]; b->grid = b->box[@"grid"]; if (![b->grid isKindOfClass: [NSMutableDictionary class]]) return nil;
	NSData *dd = b64decode(b->box[@"displayablesData"] ?: @""); b->disp = plistMutable(dd);
	if (![b->disp isKindOfClass: [NSMutableDictionary class]]) return nil;
	b->instanceIds = b->disp[@"instanceIds"] ?: [NSMutableArray array]; b->disp[@"instanceIds"] = b->instanceIds;
	b->modules = plistMutable(b->disp[@"modules"]) ?: [NSMutableArray array]; b->chronoIds = plistMutable(b->disp[@"chronoControls"]) ?: [NSMutableArray array];
	NSMutableDictionary *mf = nil; NSString *mp = nil; NSData *cr = prefValue(kChronoKey, kMainDomain, NO, &mf, &mp); b->mainFile = mf; b->mainPath = mp;
	b->chrono = jsonMutable(cr); b->chronoControls = [b->chrono isKindOfClass: [NSMutableDictionary class]] ? b->chrono[@"Controls"] : nil;
	NSMutableDictionary *modById = [NSMutableDictionary dictionary]; for (NSDictionary *m in b->modules) { NSString *i = m[@"id"][@"rawValue"]; if (i) modById[i] = m; }
	NSMutableDictionary *chById = [NSMutableDictionary dictionary]; for (NSDictionary *c in b->chronoControls) { NSString *i = [c[@"Identifier"] firstObject]; if (i) chById[i] = c; }
	b->placed = [NSMutableArray array]; b->preserved = [NSMutableArray array];
	for (NSDictionary *e in b->grid[@"elements"]) {
		NSString *i = e[@"id"][@"rawValue"]; int w = 0, h = 0; NSString *sn = [[e[@"size"] allKeys] firstObject]; int kind = -1;
		if (!i || !sn || !cellsOfName(sn, &w, &h)) { [b->preserved addObject: e]; continue; }
		NSDictionary *m = modById[i]; if (m && moduleKinds()[m[@"moduleId"]]) kind = [moduleKinds()[m[@"moduleId"]] intValue];
		else if (chById[i]) kind = chronoKindOf(chById[i][@"ControlIdentity"]);
		if (kind < 0 || !CCCatalogFor((CCKind)kind)) { [b->preserved addObject: e]; continue; }
		CCControl *c = [CCControl new]; c.kind = (CCKind)kind; c.col = [e[@"location"][@"x"] intValue]; c.row = [e[@"location"][@"y"] intValue]; c.instanceId = i;
		const CCCatalogEntry *ce = CCCatalogFor(c.kind); c.w = w == ce->w ? 0 : w; c.h = h == ce->h ? 0 : h; [b->placed addObject: c];
	}
	return b;
}

- (void)saveControls:(NSArray<CCControl *> *)cs
{
	NSMutableArray *els = [NSMutableArray array]; NSMutableSet *occupied = [NSMutableSet set]; NSMutableDictionary *chById = [NSMutableDictionary dictionary];
	for (NSDictionary *c in chronoControls) { NSString *i = [c[@"Identifier"] firstObject]; if (i) chById[i] = c; }
	for (CCControl *c in cs) {
		int w = [c cw], h = [c ch]; NSString *sn = nameOfCells(w, h); if (!sn) continue;
		NSString *mid = moduleIdOf(c.kind);
		if (!c.instanceId) {                                                   /* a control added in Edit Controls: a new instance */
			if (!mid) continue;                                                // a chrono control cannot be created here (its identity archive is Apple's): not written
			c.instanceId = newUUID();
			[modules addObject: [@{ @"id": [@{ @"rawValue": c.instanceId } mutableCopy], @"size": [@{ moduleSizeOf(w, h): [NSMutableDictionary dictionary] } mutableCopy], @"moduleId": mid } mutableCopy]]; [instanceIds addObject: [@{ @"rawValue": c.instanceId } mutableCopy]];
		} else if (mid) for (NSMutableDictionary *m in modules) if ([m[@"id"][@"rawValue"] isEqual: c.instanceId]) m[@"size"] = [@{ moduleSizeOf(w, h): [NSMutableDictionary dictionary] } mutableCopy];
		NSMutableDictionary *cc = chById[c.instanceId]; if (cc) cc[@"ControlSize"] = @(w == 1 && h == 1 ? 0 : w == 2 && h == 1 ? 1 : w == 2 && h == 2 ? 3 : 2);     /* 0 and 3 are seen (1x1 and 2x2); 1 and 2 are guesses */
		[els addObject: [@{ @"size": [@{ sn: [NSMutableDictionary dictionary] } mutableCopy], @"id": [@{ @"rawValue": c.instanceId } mutableCopy], @"location": [@{ @"x": @(c.col), @"y": @(c.row) } mutableCopy] } mutableCopy]];
		for (int x = c.col; x < c.col + w; x++) for (int y = c.row; y < c.row + h; y++) [occupied addObject: @(y * 4 + x)];
	}
	for (NSDictionary *e in preserved) { [els addObject: e]; int w = 1, h = 1; cellsOfName([[e[@"size"] allKeys] firstObject], &w, &h); int c0 = [e[@"location"][@"x"] intValue], r0 = [e[@"location"][@"y"] intValue];
		for (int x = c0; x < c0 + w; x++) for (int y = r0; y < r0 + h; y++) [occupied addObject: @(y * 4 + x)]; }
	grid[@"elements"] = els;
	NSMutableArray *occ = [NSMutableArray array], *free_ = [NSMutableArray array]; int maxH = [grid[@"maxHeight"] intValue] ?: 8;
	for (int y = 0; y < maxH; y++) for (int x = 0; x < 4; x++) [([occupied containsObject: @(y * 4 + x)] ? occ : free_) addObject: [@{ @"x": @(x), @"y": @(y) } mutableCopy]];
	grid[@"occupiedLocations"] = occ; grid[@"unoccupiedLocations"] = free_;
	/* the real one lists every location of the grid in allLocations: kept (it is the same set) */
	disp[@"modules"] = plistBinary(modules); disp[@"chronoControls"] = plistBinary(chronoIds); disp[@"instanceIds"] = instanceIds;
	box[@"displayablesData"] = b64encode(plistBinary(disp));
	NSData *json = [NSJSONSerialization dataWithJSONObject: boxes options: 0 error: NULL]; if (!json) return;
	if (boxFile) { boxFile[@"boxes"] = json; [plistBinary(boxFile) writeToFile: boxPath atomically: YES]; }
	else { CFPreferencesSetValue((__bridge CFStringRef)@"boxes", (__bridge CFPropertyListRef)json, (__bridge CFStringRef)kBoxesDomain, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost); CFPreferencesSynchronize((__bridge CFStringRef)kBoxesDomain, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost); }
	if (chrono) {
		NSData *cj = [NSJSONSerialization dataWithJSONObject: chrono options: 0 error: NULL];
		if (cj && mainFile) { mainFile[kChronoKey] = cj; [plistBinary(mainFile) writeToFile: mainPath atomically: YES]; }
		else if (cj) { CFPreferencesSetAppValue((__bridge CFStringRef)kChronoKey, (__bridge CFPropertyListRef)cj, (__bridge CFStringRef)kMainDomain); CFPreferencesAppSynchronize((__bridge CFStringRef)kMainDomain); }
	}
}
@end
