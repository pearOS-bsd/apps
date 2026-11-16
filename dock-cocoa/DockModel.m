#import "DockModel.h"
#import "../dock/dock_layout.h"
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
	/* the recent applications: a separator, the recents, a separator (measured on the real Dock: 19 apps | 2 recents | folder + Trash, two separators) */
	NSArray *recents = prefs.values[@"recent-apps"]; BOOL showRecents = prefs.values[@"show-recents"] ? [prefs.values[@"show-recents"] boolValue] : YES;
	DockTile *sep = [DockTile new]; sep.kind = DOCK_SEPARATOR; [list addObject: sep];
	if (showRecents && recents.count) {
		for (NSDictionary *d in recents) [list addObject: TileFromDict(d, DOCK_APP)];
		DockTile *sep2 = [DockTile new]; sep2.kind = DOCK_SEPARATOR; [list addObject: sep2];
	}
	for (NSDictionary *d in prefs.values[@"persistent-others"]) [list addObject: TileFromDict(d, DOCK_OTHER)];
	DockTile *trash = [DockTile new]; trash.kind = DOCK_TRASH; trash.label = @"Trash"; [list addObject: trash];
	/* sizes: the preferences when set; our defaults are measurements on a 1280x800 display, NOT the real Dock's registered defaults (still unknown) */
	DockMetrics m = { 58, 99, 0, (int)display.size.width };
	if ([prefs.values[@"tilesize"] intValue] > 0) m.tilesize = [prefs.values[@"tilesize"] intValue];
	if ([prefs.values[@"largesize"] intValue] > 0) m.largesize = [prefs.values[@"largesize"] intValue];
	m.magnification = [prefs.values[@"magnification"] boolValue];
	NSUInteger n = list.count; DockItem *items = calloc(n, sizeof *items); DockSlot *slots = calloc(n, sizeof *slots); DockBar bar;
	for (NSUInteger i = 0; i < n; i++) items[i].kind = list[i].kind;
	/* too many tiles: the tile size shrinks until the bar fits.  HYPOTHESIS from one measurement (25 items, 1280 px display -> tilesize 46, bar 1208 wide): the bar may use at most 95% of the display; 47 would give ~1234 > 1216 */
	for (;;) {
		dock_layout(&m, items, (int)n, -1, slots, &bar);
		if (bar.bar_w <= display.size.width * 0.95 || m.tilesize <= 16) break;
		m.tilesize--; if (m.largesize < m.tilesize) m.largesize = m.tilesize;
	}
	_tileSize = m.tilesize;
	CGFloat barTop = display.origin.y + display.size.height - bar.bar_h - bar.bottom_margin;
	for (NSUInteger i = 0; i < n; i++) { list[i].frame = CGRectMake(display.origin.x + slots[i].x, barTop, slots[i].w, bar.bar_h); list[i].art = slots[i].art; }
	_barRect = CGRectMake(display.origin.x + bar.bar_x, display.origin.y + display.size.height - bar.bar_h - bar.bottom_margin, bar.bar_w, bar.bar_h);
	free(items); free(slots);
	return self;
}
@end
