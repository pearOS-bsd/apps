#include <string.h>
#include <fcntl.h>
#include <unistd.h>
static void bt(const char *fmt, long a, long b2) { if (!getenv("CC_TRACE")) return; int fd = open("/Users/alex/cc-save.txt", O_WRONLY | O_CREAT | O_APPEND, 0644); if (fd >= 0) { dprintf(fd, fmt, a, b2); dprintf(fd, "\n"); close(fd); } }
#import "CCBento.h"
#import "CCChrono.h"

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

/* the archived identity of a chrono control, as the real one writes it: a keyed archive of CHSControlIdentity { intentRef, kind, extId = CHSExtensionIdentity { deviceIdentifier, containerBundleIdentifier, extensionBundleIdentifier } }.
 * Two classes of ours stand for them (NSKeyedArchiver writes the names given by setClassName:forClass:, so the archive says CHSControlIdentity / CHSExtensionIdentity). */
@interface CCExtIdentity : NSObject <NSCoding> { @public NSString *container, *extension; } @end
@implementation CCExtIdentity
- (void)encodeWithCoder:(NSCoder *)c { [c encodeObject: nil forKey: @"deviceIdentifier"]; [c encodeObject: container forKey: @"containerBundleIdentifier"]; [c encodeObject: extension forKey: @"extensionBundleIdentifier"]; }
- (instancetype)initWithCoder:(NSCoder *)c { return [super init]; }
@end
@interface CCCtlIdentity : NSObject <NSCoding> { @public NSString *kind; CCExtIdentity *ext; } @end
@implementation CCCtlIdentity
- (void)encodeWithCoder:(NSCoder *)c { [c encodeObject: nil forKey: @"intentRef"]; [c encodeObject: kind forKey: @"kind"]; [c encodeObject: ext forKey: @"extId"]; }
- (instancetype)initWithCoder:(NSCoder *)c { return [super init]; }
@end
static NSString *b64encode(NSData *d);
static NSString *identityArchive(NSString *kind, NSString *container, NSString *extension)
{
	[NSKeyedArchiver setClassName: @"CHSControlIdentity" forClass: [CCCtlIdentity class]]; [NSKeyedArchiver setClassName: @"CHSExtensionIdentity" forClass: [CCExtIdentity class]];
	CCExtIdentity *e = [CCExtIdentity new]; e->container = container; e->extension = extension; CCCtlIdentity *i = [CCCtlIdentity new]; i->kind = kind; i->ext = e;
	NSData *d = [NSKeyedArchiver archivedDataWithRootObject: i requiringSecureCoding: NO error: NULL]; return d ? b64encode(d) : nil;
}
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
static NSData *plistBinary(id o)       /* binary like the real files: CoreFoundation's writer first (the Foundation of pearOS has none that works), then Foundation's, then XML (the real reader takes both) */
{
	CFErrorRef cerr = NULL; CFDataRef cd = CFPropertyListCreateData(NULL, (__bridge CFPropertyListRef)o, kCFPropertyListBinaryFormat_v1_0, 0, &cerr); if (cd) return CFBridgingRelease(cd);
	NSError *err = nil; NSData *d = [NSPropertyListSerialization dataWithPropertyList: o format: NSPropertyListBinaryFormat_v1_0 options: 0 error: &err];
	if (!d) { cd = CFPropertyListCreateData(NULL, (__bridge CFPropertyListRef)o, kCFPropertyListXMLFormat_v1_0, 0, &cerr); if (cd) return CFBridgingRelease(cd); }
	if (!d && getenv("CC_TRACE")) { int fd = open("/Users/alex/cc-save.txt", O_WRONLY | O_CREAT | O_APPEND, 0644); if (fd >= 0) { dprintf(fd, "plist serialization failed: %s\n", cerr ? ((__bridge NSError *)cerr).description.UTF8String ?: "cf error" : "no error"); close(fd); } }
	return d;
}

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
/* the chrono controls (extensions): the kind of the descriptor is one of the strings inside the archived identity (CHSControlIdentity: kind, extension identity) */
static int chronoKindOf(NSString *b64)
{
	NSData *d = b64decode(b64 ?: @""); if (!d.length) return -1;
	NSDictionary *p = [NSPropertyListSerialization propertyListWithData: d options: 0 format: NULL error: NULL]; NSArray *objs = p[@"$objects"];
	for (id o in objs) if ([o isKindOfClass: [NSString class]]) { const CCCatalogEntry *e = CCCatalogByChrono([o UTF8String]); if (e) return (int)e->kind; }
	return -1;
}

/* no layout file yet (a new account): an empty one in the real format, written at the first change */
+ (instancetype)blank
{
	CCBento *b = [CCBento new]; b->grid = [@{ @"width": @4, @"maxHeight": @8, @"id": [@{ @"rawValue": @0 } mutableCopy], @"elements": [NSMutableArray array], @"occupiedLocations": [NSMutableArray array], @"unoccupiedLocations": [NSMutableArray array], @"allLocations": [NSMutableArray array] } mutableCopy];
	for (int y = 0; y < 8; y++) for (int x = 0; x < 4; x++) [b->grid[@"allLocations"] addObject: [@{ @"x": @(x), @"y": @(y) } mutableCopy]];
	b->instanceIds = [NSMutableArray array]; b->modules = [NSMutableArray array]; b->chronoIds = [NSMutableArray array]; b->disp = [@{ @"instanceIds": b->instanceIds } mutableCopy];
	b->box = [@{ @"menuBarIconName": @"circle.grid.2x2", @"grid": b->grid, @"displayablesData": @"" } mutableCopy]; b->boxes = [NSMutableArray arrayWithObject: b->box]; b->placed = [NSMutableArray array]; b->preserved = [NSMutableArray array];
	NSMutableDictionary *mf = nil; NSString *mp = nil; NSData *cr = prefValue(kChronoKey, kMainDomain, NO, &mf, &mp); b->mainFile = mf; b->mainPath = mp; b->chrono = jsonMutable(cr); b->chronoControls = [b->chrono isKindOfClass: [NSMutableDictionary class]] ? b->chrono[@"Controls"] : nil;
	return b;
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
	bt("save: %ld controls, file %ld", (long)cs.count, (long)(boxFile != nil));
	NSMutableArray *els = [NSMutableArray array]; NSMutableSet *occupied = [NSMutableSet set]; NSMutableDictionary *chById = [NSMutableDictionary dictionary];
	for (NSDictionary *c in chronoControls) { NSString *i = [c[@"Identifier"] firstObject]; if (i) chById[i] = c; }
	for (CCControl *c in cs) {
		int w = [c cw], h = [c ch]; NSString *sn = nameOfCells(w, h); if (!sn) continue;
		NSString *mid = moduleIdOf(c.kind);
		if (!c.instanceId) {                                                   /* a control added in Edit Controls: a new instance */
			if (!mid) {                                                         // a chrono control (an extension): an entry of the configuration with an identity that we archive the way the real one does
				const CCCatalogEntry *ce = CCCatalogFor(c.kind); const CCChronoControl *dc = ce && ce->chrono ? CCChronoFind(ce->chrono) : NULL; NSString *cont = dc ? @(dc->container) : nil, *ext = dc ? @(dc->extension) : nil, *nm = dc ? @(dc->name) : @(ce ? ce->title : ""), *ds = dc ? @(dc->desc) : @"";
				if (ce && ce->chrono && !dc) {                                  // without the database (pearOS has no chronod): the extension of the well-known ones, as the real database lists them
					static const struct { const char *prefix, *container, *extension; } ids[] = { { "com.apple.controls.display", "com.apple.controlcenter", "com.apple.controls.display" }, { "com.apple.windowmanager", "com.apple.WindowManager", "com.apple.WindowManager.controls" },
						{ "com.apple.mobiletimer", "com.apple.clock", "com.apple.clock.WorldClockWidget" }, { "com.apple.Home", "com.apple.Home", "com.apple.Home.HomeWidget.Interactive" }, { "ShortcutsControl", "com.apple.shortcuts", "com.apple.shortcuts.ShortcutsWidget" },
						{ "com.apple.VoiceMemos", "com.apple.VoiceMemos", "com.apple.VoiceMemos.RecordWidget" }, { "com.apple.notes", "com.apple.Notes", "com.apple.Notes.WidgetExtension" }, { "com.apple.controls.screenshot", "com.apple.screenshot.launcher", "com.apple.controls.screenshot" } };
					for (size_t q = 0; q < sizeof ids / sizeof *ids; q++) if (!strncmp(ce->chrono, ids[q].prefix, strlen(ids[q].prefix))) { cont = @(ids[q].container); ext = @(ids[q].extension); break; }
				}
				NSString *arch = (cont && ext) ? identityArchive(@(ce->chrono), cont, ext) : nil; if (!arch) continue;
				if (!chrono) { chrono = [NSMutableDictionary dictionaryWithObject: [NSMutableArray array] forKey: @"Controls"]; chronoControls = chrono[@"Controls"]; }
				c.instanceId = newUUID();
				[chronoControls addObject: [@{ @"OverrideSizeForMenuBar": @NO, @"ControlType": @(dc ? dc->type : (w == 1 && h == 1 ? 1 : 2)), @"DisplayName": nm, @"Identifier": [@[ c.instanceId ] mutableCopy], @"ControlIdentity": arch, @"PromptsForUserConfiguration": @NO, @"ControlDescription": ds, @"ControlSize": @(w == 1 && h == 1 ? 0 : w == 2 && h == 1 ? 1 : w == 2 && h == 2 ? 3 : 2) } mutableCopy]];
				[chronoIds addObject: [@{ @"rawValue": c.instanceId } mutableCopy]]; [instanceIds addObject: [@{ @"rawValue": c.instanceId } mutableCopy]]; chById[c.instanceId] = [chronoControls lastObject];
			} else {
			c.instanceId = newUUID();
			[modules addObject: [@{ @"id": [@{ @"rawValue": c.instanceId } mutableCopy], @"size": [@{ moduleSizeOf(w, h): [NSMutableDictionary dictionary] } mutableCopy], @"moduleId": mid } mutableCopy]]; [instanceIds addObject: [@{ @"rawValue": c.instanceId } mutableCopy]]; }
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
	NSData *json = [NSJSONSerialization dataWithJSONObject: boxes options: 0 error: NULL]; if (!json) { bt("save: json failed %ld %ld", 0, 0); return; }
	bt("save: json %ld bytes, path set %ld", (long)json.length, (long)(boxPath != nil));
	if (!boxFile && !boxPath && getenv("CC_BENTO_FILE")) { boxPath = @(getenv("CC_BENTO_FILE")); boxFile = [NSMutableDictionary dictionary]; }
	if (!boxFile && !boxPath) {                       // a new file: through CFPreferences, and when that does not keep it (no cfprefsd) as a file of the ByHost folder
		CFPreferencesSetValue((__bridge CFStringRef)@"boxes", (__bridge CFPropertyListRef)json, (__bridge CFStringRef)kBoxesDomain, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost); CFPreferencesSynchronize((__bridge CFStringRef)kBoxesDomain, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost);
		if (!prefValue(@"boxes", kBoxesDomain, YES, NULL, NULL)) { NSString *dir = [NSHomeDirectory() stringByAppendingPathComponent: @"Library/Preferences/ByHost"]; [[NSFileManager defaultManager] createDirectoryAtPath: dir withIntermediateDirectories: YES attributes: nil error: NULL]; boxPath = [dir stringByAppendingPathComponent: @"com.apple.controlcenter.bentoboxes.00000000-0000-0000-0000-000000000001.plist"]; boxFile = [NSMutableDictionary dictionary]; }
	}
	if (boxFile) { boxFile[@"boxes"] = json; BOOL ok = [plistBinary(boxFile) writeToFile: boxPath atomically: YES]; bt("save: write %ld (path nil %ld)", (long)ok, (long)(boxPath == nil)); }
	else { CFPreferencesSetValue((__bridge CFStringRef)@"boxes", (__bridge CFPropertyListRef)json, (__bridge CFStringRef)kBoxesDomain, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost); CFPreferencesSynchronize((__bridge CFStringRef)kBoxesDomain, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost); }
	if (chrono) {
		if (!mainFile && getenv("CC_CHRONO_FILE")) { mainPath = @(getenv("CC_CHRONO_FILE")); mainFile = [NSMutableDictionary dictionary]; }
		NSData *cj = [NSJSONSerialization dataWithJSONObject: chrono options: 0 error: NULL];
		if (cj && mainFile) { mainFile[kChronoKey] = cj; [plistBinary(mainFile) writeToFile: mainPath atomically: YES]; }
		else if (cj) {
			CFPreferencesSetAppValue((__bridge CFStringRef)kChronoKey, (__bridge CFPropertyListRef)cj, (__bridge CFStringRef)kMainDomain); CFPreferencesAppSynchronize((__bridge CFStringRef)kMainDomain);
			if (!prefValue(kChronoKey, kMainDomain, NO, NULL, NULL)) {                // cfprefsd did not keep it (pearOS): the file of the preferences
				NSString *p = [NSHomeDirectory() stringByAppendingPathComponent: @"Library/Preferences/com.apple.controlcenter.plist"]; NSMutableDictionary *f = readFile(p) ?: [NSMutableDictionary dictionary]; f[kChronoKey] = cj;
				[[NSFileManager defaultManager] createDirectoryAtPath: [p stringByDeletingLastPathComponent] withIntermediateDirectories: YES attributes: nil error: NULL]; [plistBinary(f) writeToFile: p atomically: YES];
			}
		}
	}
}
@end
