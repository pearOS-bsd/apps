#import "DockController.h"
#import "DockView.h"
#import "DockWallpaper.h"
#import "DockHover.h"
#import "DockMagnify.h"
#import "DockInput.h"
#import "DockServer.h"
#import "DockNotify.h"
#import "SkyLightAPI.h"
#import "../dock/dock_layout.h"
@implementation DockController
{ DockWindow *win, *wall; DockMagnify *magnify; DockHover *hover; DockInput *input; NSTimer *refresh; NSString *signature; }
- (NSString *)runtimeSignature { NSMutableString *s = [NSMutableString string]; [s appendFormat: @"%@|%@|", _prefs.values[@"orientation"], _prefs.values[@"tilesize"]]; for (DockTile *t in _model.tiles) [s appendFormat: @"%@|%d|%@;", t.path, t.running, t.badge]; return s; }
- (id)hoverObject { return hover; }
- (void)start
{
	_display = [DockWindow mainDisplayBounds];
	_prefs = [[DockPrefs alloc] initFromPreferences]; [_prefs readSystemKeys];
	_model = [[DockModel alloc] initWithPrefs: _prefs displayBounds: _display];
	win = [[DockWindow alloc] initWithFrame: _display level: 20];
	wall = [[DockWindow alloc] initWithFrame: _display level: -2147483624 options: 1];       /* created second, like the real Dock */
	[win orderIn]; [wall orderIn];
	[wall setRootLayer: DockWallpaperLayer(_display.size)];
	_root = DockBuildLayers(_model, _display.size); [win setRootLayer: _root];
	if (getenv("DOCK_NOTIFY")) DockNotifyStart();       /* experiment: registers ~1500 notification types, logs them; off by default */
	DockServerSetMinimizeHandler(^(uint32_t wid, NSString *title, BOOL animate) {
		/* EXPERIMENT 1: can this Dock order out a window of another process? (the real one does; it has private SkyLight entitlements) */
		const SkyLightAPI *sl = SkyLightLoad(); int cid = sl ? sl->MainConnectionID() : 0; CFTypeRef tx = sl && sl->TransactionCreate ? sl->TransactionCreate(cid) : NULL;
		if (tx) { sl->TransactionOrderWindow(tx, wid, 0 /* out */, 0); CGError e = sl->TransactionCommit(tx, 1); CFRelease(tx); NSLog(@"dock: minimize request window %u \"%@\" animate %d -> order out: error %d", wid, title, animate, e); }
	});
	hover = [[DockHover alloc] initWithController: self]; magnify = [[DockMagnify alloc] initWithController: self];
	input = [[DockInput alloc] initWithController: self];
	/* running applications and badges change while the Dock runs: look again every 1.5 s (SCAFFOLDING: the real Dock is told by LaunchServices / usernoted) */
	signature = [self runtimeSignature];
	refresh = [NSTimer scheduledTimerWithTimeInterval: 1.5 repeats: YES block: ^(NSTimer *t) {
		if ([input busy]) return;
		DockPrefs *p = [[DockPrefs alloc] initFromPreferences]; DockModel *m = [[DockModel alloc] initWithPrefs: p displayBounds: self->_display];
		NSMutableString *s = [NSMutableString string]; [s appendFormat: @"%@|%@|", p.values[@"orientation"], p.values[@"tilesize"]]; for (DockTile *x in m.tiles) [s appendFormat: @"%@|%d|%@;", x.path, x.running, x.badge];
		if (![s isEqualToString: self->signature]) { [self reload]; self->signature = [self runtimeSignature]; }
	}];
	if (getenv("DOCK_LOG")) NSLog(@"dock: window id %u, %lu tiles, tilesize %d, bar %@", win.windowID, (unsigned long)_model.tiles.count, _model.tileSize, NSStringFromRect(NSRectFromCGRect(_model.barRect)));
}
- (void)reload
{
	_prefs = [[DockPrefs alloc] initFromPreferences];
	_model = [[DockModel alloc] initWithPrefs: _prefs displayBounds: _display];
	_root = DockBuildLayers(_model, _display.size); [win setRootLayer: _root];
	[hover modelChanged]; [magnify modelChanged];
}
- (void)setPreference:(id)value forKey:(NSString *)key { [DockPrefs setValue: value forKey: key]; [self reload]; }
- (NSArray<NSDictionary *> *)persistentApps
{
	NSMutableArray *a = [NSMutableArray array];
	for (DockTile *t in _model.tiles) if (t.section == 0 && t.kind == DOCK_APP && t.dict) [a addObject: t.dict];
	return a;
}
- (void)setPersistentApps:(NSArray<NSDictionary *> *)apps { [self setPreference: apps forKey: @"persistent-apps"]; }
@end
