#import "DockModel.h"
#import "../dock/dock_layout.h"
#import "dock_fit.h"
#import "DockRunning.h"
#import "SkyLightAPI.h"
@implementation DockTile @end
static DockTile *TileFromDict(NSDictionary *d, int kind)
{
	NSDictionary *td = d[@"tile-data"]; NSString *u = td[@"file-data"][@"_CFURLString"];
	DockTile *t = [DockTile new]; t.kind = kind; t.tileType = d[@"tile-type"];
	NSURL *url = u ? [NSURL URLWithString: u] : nil; NSString *p = [url isFileURL] ? [url path] : u;
	t.dict = d; t.path = p; t.label = td[@"file-label"] ?: [[p lastPathComponent] stringByDeletingPathExtension]; t.bundleIdentifier = td[@"bundle-identifier"];
	return t;
}
@implementation DockModel
{ NSMutableArray<DockTile *> *list; }
+ (NSDictionary *)tileDictionaryForPath:(NSString *)path label:(NSString *)label bundleIdentifier:(NSString *)bid
{
	NSString *u = [@"file://" stringByAppendingString: [[path stringByAddingPercentEncodingWithAllowedCharacters: [NSCharacterSet URLPathAllowedCharacterSet]] stringByAppendingString: @"/"]];
	NSMutableDictionary *td = [@{ @"file-data": @{ @"_CFURLString": u, @"_CFURLStringType": @15 }, @"file-label": label ?: path.lastPathComponent.stringByDeletingPathExtension, @"file-type": @41, @"dock-extra": @NO, @"is-beta": @NO } mutableCopy];
	if (bid.length) td[@"bundle-identifier"] = bid;
	return @{ @"GUID": @(arc4random()), @"tile-type": @"file-tile", @"tile-data": td };
}
- (NSArray<DockTile *> *)tiles { return list; }
- (CGRect)hitRect
{
	CGRect r = _barRect; CGFloat e = _magExtra; if (e <= 0) return r;
	if (_orientation == 0) { r.origin.y -= e; r.size.height += e; } else if (_orientation == 1) r.size.width += e; else { r.origin.x -= e; r.size.width += e; }
	return r;
}
- (instancetype)initWithPrefs:(DockPrefs *)prefs displayBounds:(CGRect)display
{
	if (!(self = [super init])) return nil;
	list = [NSMutableArray array];
	DockTile *finder = [DockTile new]; finder.kind = DOCK_APP; finder.label = @"Finder"; finder.path = @"/System/Library/CoreServices/Finder.app"; finder.bundleIdentifier = @"com.apple.finder"; [list addObject: finder];
	for (NSDictionary *d in prefs.values[@"persistent-apps"]) [list addObject: TileFromDict(d, DOCK_APP)];
	/* the middle section: running applications that are not in the Dock permanently (LaunchServices), then the recent applications that are not running; a separator before and after.
	 * Measured on the real Dock: 19 apps | Terminal + Install Command Line Developer Tools (running) | separator | folder + Trash.  Terminal is also in recent-apps: listed once. */
	NSMutableSet *known = [NSMutableSet set]; for (DockTile *t in list) if (t.path) [known addObject: t.path.stringByStandardizingPath];
	for (NSDictionary *d in prefs.values[@"persistent-apps"]) { DockTile *t = TileFromDict(d, DOCK_APP); if (t.path) [known addObject: t.path.stringByStandardizingPath]; }
	DockTile *sep = [DockTile new]; sep.kind = DOCK_SEPARATOR; [list addObject: sep];
	NSMutableArray<DockTile *> *middle = [NSMutableArray array];
	for (NSDictionary *a in DockRunningApplications()) {
		NSString *p = [a[@"path"] stringByStandardizingPath]; if ([known containsObject: p] || [p hasPrefix: @"/System/Library/CoreServices/Finder.app"]) continue;
		DockTile *t = [DockTile new]; t.kind = DOCK_APP; t.label = a[@"name"]; t.path = a[@"path"]; t.bundleIdentifier = a[@"bundleIdentifier"]; t.running = YES; [middle addObject: t]; [known addObject: p];
	}
	BOOL showRecents = prefs.values[@"show-recents"] ? [prefs.values[@"show-recents"] boolValue] : YES;
	if (showRecents) for (NSDictionary *d in prefs.values[@"recent-apps"]) { DockTile *t = TileFromDict(d, DOCK_APP); NSString *p = t.path.stringByStandardizingPath; if (p && ![known containsObject: p]) { [middle addObject: t]; [known addObject: p]; } }
	if (middle.count) { [list addObjectsFromArray: middle]; DockTile *sep2 = [DockTile new]; sep2.kind = DOCK_SEPARATOR; [list addObject: sep2]; }
	for (NSDictionary *d in prefs.values[@"persistent-others"]) [list addObject: TileFromDict(d, DOCK_OTHER)];
	DockTile *trash = [DockTile new]; trash.kind = DOCK_TRASH; trash.label = @"Trash"; [list addObject: trash];
	{ int sec = 0; for (DockTile *t in list) { if (t.kind == DOCK_SEPARATOR) { sec++; t.section = sec; continue; } t.section = (t.kind == DOCK_OTHER || t.kind == DOCK_TRASH) ? 2 : sec; } }
	{ NSMutableDictionary *runPaths = [NSMutableDictionary dictionary]; for (NSDictionary *a in DockRunningApplications()) runPaths[[a[@"path"] stringByStandardizingPath]] = a;
	  for (DockTile *t in list) { NSDictionary *a = t.path ? runPaths[t.path.stringByStandardizingPath] : nil; if (a) { t.running = YES; if ([a[@"badge"] length]) t.badge = a[@"badge"]; } } }
	/* sizes: the preferences when set; our defaults are measurements on a 1280x800 display, NOT the real Dock's registered defaults (still unknown) */
	DockMetrics m = { 58, 99, 0, (int)display.size.width };
	if ([prefs.values[@"tilesize"] intValue] > 0) m.tilesize = [prefs.values[@"tilesize"] intValue];
	if ([prefs.values[@"largesize"] intValue] > 0) m.largesize = [prefs.values[@"largesize"] intValue];
	m.magnification = [prefs.values[@"magnification"] boolValue];
	NSUInteger n = list.count; DockItem *items = calloc(n, sizeof *items); DockSlot *slots = calloc(n, sizeof *slots); DockBar bar;
	for (NSUInteger i = 0; i < n; i++) items[i].kind = list[i].kind;
	NSString *ori = prefs.values[@"orientation"]; _orientation = [ori isEqualToString: @"left"] ? 1 : [ori isEqualToString: @"right"] ? 2 : 0;
	CGFloat menubar = 30; { const SkyLightAPI *sl = SkyLightLoad(); uint32_t h = 0; if (sl && sl->MainDisplayID && sl->GetDisplayMenubarHeight && sl->GetDisplayMenubarHeight(sl->MainDisplayID(), &h) == 0 && h) menubar = h; }
	/* the tiles run along the width (bottom) or along the height under the menu bar (sides); margins 36 / 18 measured on the real Dock (dock_fit.h) */
	if (_orientation == 0) m.screen_w = (int)display.size.width; else m.screen_w = (int)(display.size.height - menubar);
	double fitted = dock_layout_fit(&m, items, (int)n, slots, &bar, _orientation == 0 ? DOCK_SIDE_MARGIN : DOCK_EDGE_MARGIN);
	m.tilesize = (int)(fitted + 0.5); _tileSize = m.tilesize;
	if (_orientation == 0) {
		CGFloat barTop = display.origin.y + display.size.height - bar.bar_h - bar.bottom_margin;
		_barRect = CGRectMake(display.origin.x + bar.bar_x, barTop, bar.bar_w, bar.bar_h);
		for (NSUInteger i = 0; i < n; i++) { list[i].frame = CGRectMake(display.origin.x + slots[i].x, barTop, slots[i].w, bar.bar_h); list[i].art = slots[i].art; }
	} else {
		CGFloat thick = m.tilesize + 16, x = _orientation == 1 ? display.origin.x + 5 : display.origin.x + display.size.width - 5 - thick;   /* 5 px from the screen edge, thickness tile size + 16 (measured: 42 at 26) */
		_barRect = CGRectMake(x, display.origin.y + menubar + bar.bar_x, thick, bar.bar_w);
		for (NSUInteger i = 0; i < n; i++) { list[i].frame = CGRectMake(x, display.origin.y + menubar + slots[i].x, thick, slots[i].w); list[i].art = slots[i].art; }
	}
	free(items); free(slots);
	_baseBarRect = _barRect; for (DockTile *t in list) t.baseFrame = t.frame;
	_magnification = [prefs.values[@"magnification"] boolValue]; _largeSize = [prefs.values[@"largesize"] doubleValue] > 0 ? [prefs.values[@"largesize"] doubleValue] : 128;
	return self;
}
@end
