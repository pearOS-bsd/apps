#import "DockController.h"
#import "DockView.h"
#import "DockWallpaper.h"
#import "DockHover.h"
#import "DockInput.h"
#import "../dock/dock_layout.h"
@implementation DockController
{ DockWindow *win, *wall; DockHover *hover; DockInput *input; }
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
	hover = [[DockHover alloc] initWithController: self];
	input = [[DockInput alloc] initWithController: self];
	if (getenv("DOCK_LOG")) NSLog(@"dock: window id %u, %lu tiles, tilesize %d, bar %@", win.windowID, (unsigned long)_model.tiles.count, _model.tileSize, NSStringFromRect(NSRectFromCGRect(_model.barRect)));
}
- (void)reload
{
	_prefs = [[DockPrefs alloc] initFromPreferences];
	_model = [[DockModel alloc] initWithPrefs: _prefs displayBounds: _display];
	_root = DockBuildLayers(_model, _display.size); [win setRootLayer: _root];
	[hover modelChanged];
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
