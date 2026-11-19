#import "CCChrono.h"
#import <dlfcn.h>
#include <string.h>

typedef struct sqlite3 sqlite3; typedef struct sqlite3_stmt sqlite3_stmt;
static int (*s_open)(const char *, sqlite3 **, int, const char *); static int (*s_prepare)(sqlite3 *, const char *, int, sqlite3_stmt **, const char **); static int (*s_step)(sqlite3_stmt *);
static const void *(*s_blob)(sqlite3_stmt *, int); static int (*s_bytes)(sqlite3_stmt *, int); static int (*s_finalize)(sqlite3_stmt *); static int (*s_close)(sqlite3 *);

static CCChronoControl *gAll; static size_t gN; static BOOL gLoaded, gHave;

static id uidDeref(NSArray *objs, id o) { if ([o isKindOfClass: [NSDictionary class]] && [(NSDictionary *)o count] == 1 && ((NSDictionary *)o)[@"CF$UID"]) { NSUInteger i = [((NSDictionary *)o)[@"CF$UID"] unsignedIntegerValue]; return i < objs.count ? objs[i] : nil; } return o; }

static NSSet *installedExtensions(void)
{
	NSMutableSet *set = [NSMutableSet set]; NSFileManager *fm = [NSFileManager defaultManager];
	for (NSString *root in @[ @"/System/Applications", @"/System/Applications/Utilities", @"/Applications", @"/System/Library/CoreServices", @"/System/Library/CoreServices/Applications", @"/System/Cryptexes/App/System/Applications" ]) {
		for (NSString *app in [fm contentsOfDirectoryAtPath: root error: NULL]) {
			NSString *pi = [[root stringByAppendingPathComponent: app] stringByAppendingPathComponent: @"Contents/PlugIns"];
			for (NSString *x in [fm contentsOfDirectoryAtPath: pi error: NULL]) { NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile: [[pi stringByAppendingPathComponent: x] stringByAppendingPathComponent: @"Contents/Info.plist"]]; NSString *b = d[@"CFBundleIdentifier"]; if (b) [set addObject: b]; }
		}
	}
	NSString *ek = @"/System/Library/ExtensionKit/Extensions";
	for (NSString *x in [fm contentsOfDirectoryAtPath: ek error: NULL]) { NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile: [[ek stringByAppendingPathComponent: x] stringByAppendingPathComponent: @"Contents/Info.plist"]]; NSString *b = d[@"CFBundleIdentifier"]; if (b) [set addObject: b]; }
	return set;
}

static void loadAll(void)
{
	if (gLoaded) return; gLoaded = YES;
	NSString *path = getenv("CC_CHRONO_DB") ? @(getenv("CC_CHRONO_DB")) : [NSHomeDirectory() stringByAppendingPathComponent: @"Library/Group Containers/group.com.apple.chronod/chronod/chrono.sql"];
	if (![[NSFileManager defaultManager] fileExistsAtPath: path]) return;
	void *h = dlopen("/usr/lib/libsqlite3.dylib", RTLD_LAZY); if (!h) return;
	s_open = dlsym(h, "sqlite3_open_v2"); s_prepare = dlsym(h, "sqlite3_prepare_v2"); s_step = dlsym(h, "sqlite3_step"); s_blob = dlsym(h, "sqlite3_column_blob"); s_bytes = dlsym(h, "sqlite3_column_bytes"); s_finalize = dlsym(h, "sqlite3_finalize"); s_close = dlsym(h, "sqlite3_close");
	if (!s_open || !s_prepare || !s_step || !s_blob || !s_bytes || !s_finalize || !s_close) return;
	sqlite3 *db = NULL; if (s_open(path.fileSystemRepresentation, &db, 1 /* SQLITE_OPEN_READONLY */, NULL) != 0) { if (db) s_close(db); return; }
	sqlite3_stmt *st = NULL; if (s_prepare(db, "select data from Descriptors where descriptorType = 2", -1, &st, NULL) != 0) { s_close(db); return; }
	gHave = YES; BOOL all = getenv("CC_CHRONO_ALL") != NULL; NSSet *inst = all ? nil : installedExtensions(); NSMutableArray *out = [NSMutableArray array];
	while (s_step(st) == 100 /* SQLITE_ROW */) {
		NSData *blob = [NSData dataWithBytes: s_blob(st, 0) length: (NSUInteger)s_bytes(st, 0)];
		NSDictionary *p = [NSPropertyListSerialization propertyListWithData: blob options: 0 format: NULL error: NULL]; NSArray *objs = p[@"$objects"]; if (![objs isKindOfClass: [NSArray class]]) continue;
		NSDictionary *root = uidDeref(objs, p[@"$top"][@"root"]); NSArray *list = root[@"NS.objects"];
		for (id u in list) {
			NSDictionary *d = uidDeref(objs, u); if (![d isKindOfClass: [NSDictionary class]]) continue;
			NSDictionary *ext = uidDeref(objs, d[@"extensionIdentity"]); NSString *name = uidDeref(objs, d[@"displayName"]), *kind = uidDeref(objs, d[@"kind"]), *desc = uidDeref(objs, d[@"widgetDescription"]);
			NSString *cont = uidDeref(objs, ext[@"containerBundleIdentifier"]), *eid = uidDeref(objs, ext[@"extensionBundleIdentifier"]);
			if (![name isKindOfClass: [NSString class]] || ![kind isKindOfClass: [NSString class]] || !eid) continue;
			if ([d[@"hiddenControl"] boolValue] || [d[@"internal"] boolValue] || [d[@"hiddenBySensitiveUI"] boolValue]) continue;
			if (inst && ![inst containsObject: eid]) continue;
			[out addObject: @[ name, kind, [desc isKindOfClass: [NSString class]] ? desc : @"", cont ?: @"", eid, d[@"type"] ?: @1 ]];
		}
	}
	s_finalize(st); s_close(db);
	gAll = calloc(out.count ? out.count : 1, sizeof *gAll); gN = out.count;
	for (NSUInteger i = 0; i < out.count; i++) { NSArray *r = out[i]; gAll[i] = (CCChronoControl){ strdup([r[1] UTF8String]), strdup([r[0] UTF8String]), strdup([r[2] UTF8String]), strdup([r[3] UTF8String]), strdup([r[4] UTF8String]), [r[5] intValue] }; }
}
size_t CCChronoCount(void) { loadAll(); return gN; }
const CCChronoControl *CCChronoAt(size_t i) { loadAll(); return i < gN ? &gAll[i] : NULL; }
const CCChronoControl *CCChronoFind(const char *kind) { loadAll(); for (size_t i = 0; i < gN; i++) if (!strcmp(gAll[i].kind, kind)) return &gAll[i]; return NULL; }
BOOL CCChronoAvailable(void) { loadAll(); return gHave; }
/* the group of a control in the sidebar: the app it belongs to (the real list is by app: Clock, Notes, Home ...; the system's own are grouped by what they do) */
NSString *CCChronoCategory(const CCChronoControl *c)
{
	static NSDictionary *m; if (!m) m = @{ @"com.apple.controlcenter": @"Display & Brightness", @"com.apple.WindowManager": @"Desktop & Finder", @"com.apple.dock": @"Desktop & Finder", @"com.apple.clock": @"Clock", @"com.apple.Notes": @"Notes", @"com.apple.Home": @"Home",
		@"com.apple.VoiceMemos": @"Voice Memos", @"com.apple.shortcuts": @"Shortcuts", @"com.apple.screenshot.launcher": @"Screenshot", @"com.apple.calculator": @"Utilities", @"com.apple.printcenter": @"Utilities", @"com.apple.wallpaper.agent": @"Utilities", @"com.apple.journal": @"Utilities" };
	NSString *cat = m[@(c->container)]; if (cat) return cat;
	return ([@(c->extension) rangeOfString: @"Accessibility"].location != NSNotFound) ? @"Accessibility" : @"Utilities";
}
