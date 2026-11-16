#import "DockModel.h"
#import "../dock/dock_layout.h"
#import "dock_fit.h"
#import "DockRunning.h"
@implementation DockTile @end
static DockTile *TileFromDict(NSDictionary *d, int kind)
{
	NSDictionary *td = d[@"tile-data"]; NSString *u = td[@"file-data"][@"_CFURLString"];
	DockTile *t = [DockTile new]; t.kind = kind; t.tileType = d[@"tile-type"];
	NSURL *url = u ? [NSURL URLWithString: u] : nil; NSString *p = [url isFileURL] ? [url path] : u;
	t.path = p; t.label = td[@"file-label"] ?: [[p lastPathComponent] stringByDeletingPathExtension]; t.bundleIdentifier = td[@"bundle-identifier"];
	return t;
}
@implementation DockModel
{ NSMutableArray<DockTile *> *list; }
- (NSArray<DockTile *> *)tiles { return list; }
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
	{ NSMutableSet *runPaths = [NSMutableSet set]; for (NSDictionary *a in DockRunningApplications()) [runPaths addObject: [a[@"path"] stringByStandardizingPath]];
	  for (DockTile *t in list) if (t.path && [runPaths containsObject: t.path.stringByStandardizingPath]) t.running = YES; }
	/* sizes: the preferences when set; our defaults are measurements on a 1280x800 display, NOT the real Dock's registered defaults (still unknown) */
	DockMetrics m = { 58, 99, 0, (int)display.size.width };
	if ([prefs.values[@"tilesize"] intValue] > 0) m.tilesize = [prefs.values[@"tilesize"] intValue];
	if ([prefs.values[@"largesize"] intValue] > 0) m.largesize = [prefs.values[@"largesize"] intValue];
	m.magnification = [prefs.values[@"magnification"] boolValue];
	NSUInteger n = list.count; DockItem *items = calloc(n, sizeof *items); DockSlot *slots = calloc(n, sizeof *slots); DockBar bar;
	for (NSUInteger i = 0; i < n; i++) items[i].kind = list[i].kind;
	/* too many tiles: the tile size shrinks continuously until the bar is exactly display - 2 * 36 wide (dock_fit.c, ground truth: the real Dock's accessibility tree) */
	double fitted = dock_layout_fit(&m, items, (int)n, slots, &bar);
	m.tilesize = (int)(fitted + 0.5);
	_tileSize = m.tilesize;
	CGFloat barTop = display.origin.y + display.size.height - bar.bar_h - bar.bottom_margin;
	for (NSUInteger i = 0; i < n; i++) { list[i].frame = CGRectMake(display.origin.x + slots[i].x, barTop, slots[i].w, bar.bar_h); list[i].art = slots[i].art; }
	_barRect = CGRectMake(display.origin.x + bar.bar_x, display.origin.y + display.size.height - bar.bar_h - bar.bottom_margin, bar.bar_w, bar.bar_h);
	free(items); free(slots);
	return self;
}
@end
