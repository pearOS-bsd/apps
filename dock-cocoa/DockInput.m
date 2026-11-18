#import "DockInput.h"
#import "DockController.h"
#import "DockMenu.h"
#import "DockActions.h"
#import "DockHover.h"
#import "../dock/dock_layout.h"
#import <ApplicationServices/ApplicationServices.h>

typedef enum { StIdle, StPressed, StDragging, StResizing } State;
@implementation DockInput
{
	DockController *ctl; CFMachPortRef tap; State st; DockTile *pressed; CGPoint down; int baseSize; CGFloat resizeY0; DockMenu *menu; DockTile *menuTile; CGPoint dragOffset; CGPoint iconHome;
}
static CGEventRef onEvent(CGEventTapProxy proxy, CGEventType type, CGEventRef ev, void *ref)
{
	DockInput *self = (__bridge DockInput *)ref;
	if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) { CGEventTapEnable(self->tap, true); return ev; }
	return [self handle: type event: ev] ? NULL : ev;
}
- (instancetype)initWithController:(DockController *)c
{
	if (!(self = [super init])) return nil;
	ctl = c; st = StIdle;
	CGEventMask mask = 0; CGEventType types[] = { kCGEventMouseMoved, kCGEventLeftMouseDown, kCGEventLeftMouseUp, kCGEventLeftMouseDragged, kCGEventRightMouseDown, kCGEventRightMouseUp };
	for (size_t i = 0; i < sizeof types / sizeof *types; i++) mask |= CGEventMaskBit(types[i]);
	tap = CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap, getenv("DOCK_TAP_LISTEN") ? kCGEventTapOptionListenOnly : kCGEventTapOptionDefault, mask, onEvent, (__bridge void *)self);
	if (!tap) tap = CGEventTapCreate(kCGAnnotatedSessionEventTap, kCGHeadInsertEventTap, kCGEventTapOptionDefault, mask, onEvent, (__bridge void *)self);       /* second try: the annotated session tap point */
	if (!tap) { NSLog(@"dock: no event tap (AXIsProcessTrusted %d, listen access %d, post access %d): the Dock will not react to the mouse", AXIsProcessTrusted(), CGPreflightListenEventAccess(), CGPreflightPostEventAccess()); return self; }
	CFRunLoopSourceRef src = CFMachPortCreateRunLoopSource(NULL, tap, 0); CFRunLoopAddSource(CFRunLoopGetMain(), src, kCFRunLoopCommonModes); CFRelease(src); CGEventTapEnable(tap, true);
	return self;
}
- (DockTile *)tileAt:(CGPoint)p
{
	DockModel *m = ctl.model; if (!CGRectContainsPoint(CGRectInset(m.hitRect, 0, -2), p)) return nil;
	for (DockTile *t in m.tiles) if (DockAxis(m, p) >= DockTileMin(m, t) && DockAxis(m, p) < DockTileMax(m, t)) return t;
	return nil;
}
- (BOOL)inBar:(CGPoint)p { return CGRectContainsPoint(CGRectInset(ctl.model.hitRect, 0, -2), p); }
- (BOOL)busy { return menu != nil || st != StIdle; }
- (void)closeMenu { [menu close]; menu = nil; menuTile = nil; }
- (BOOL)draggable:(DockTile *)t { return t.dict != nil && (t.section == 0 || t.section == 2) && t.kind != DOCK_TRASH && t.kind != DOCK_SEPARATOR; }

- (void)showMenuFor:(DockTile *)t
{
	if (t.kind == DOCK_SEPARATOR) return;
	[[ctl valueForKey: @"hoverObject"] hideLabel];
	NSMutableArray *items = [NSMutableArray array]; __weak DockController *wc = ctl;
	if (t.kind == DOCK_TRASH) { [items addObject: [DockMenuItem item: @"Open" action: ^{ DockOpenTile(t); }]]; }
	else {
		DockMenuItem *title = [DockMenuItem item: t.label ?: @"" action: nil]; title.isTitle = YES; title.enabled = NO; if (t.kind == DOCK_APP) [items addObject: title];
		BOOL kept = t.dict != nil && t.section == 0; BOOL isFinder = [t.path hasSuffix: @"/Finder.app"];
		NSMutableArray *opts = [NSMutableArray array];
		if (t.kind == DOCK_APP && !isFinder) {
			DockMenuItem *keep = [DockMenuItem item: @"Keep in Dock" action: ^{
				NSMutableArray *apps = [[wc persistentApps] mutableCopy];
				if (kept) { for (NSDictionary *d in [apps copy]) if (d == t.dict) [apps removeObject: d]; }
				else [apps addObject: [DockModel tileDictionaryForPath: t.path label: t.label bundleIdentifier: t.bundleIdentifier]];
				[wc setPersistentApps: apps]; }];
			keep.checked = kept; [opts addObject: keep];
			DockMenuItem *login = [DockMenuItem item: @"Open at Login" action: nil]; login.enabled = NO; [opts addObject: login];      /* needs the login items API: not done */
		}
		[opts addObject: [DockMenuItem item: @"Show in Finder" action: ^{ DockRevealTile(t); }]];
		DockMenuItem *o = [DockMenuItem item: @"Options" action: nil]; o.submenu = opts; [items addObject: o];
		if (t.kind == DOCK_APP) {
			[items addObject: [DockMenuItem separator]];
			[items addObject: [DockMenuItem item: t.running ? @"Show All Windows" : @"Open" action: ^{ DockOpenTile(t); }]];
			if (t.running && !isFinder) [items addObject: [DockMenuItem item: @"Quit" action: ^{ DockQuitTile(t); }]];
		} else [items addObject: [DockMenuItem item: @"Open" action: ^{ DockOpenTile(t); }]];
	}
	menu = [[DockMenu alloc] initWithItems: items]; menuTile = t;
	DockModel *mm = ctl.model;
	if (mm.orientation == 0) [menu showInLayer: ctl.root at: CGPointMake(CGRectGetMidX(t.frame), CGRectGetMinY(mm.barRect) - 6) displayHeight: ctl.display.size.height];
	else { menu.leftTop = mm.orientation == 1; menu.rightTop = mm.orientation == 2; [menu showInLayer: ctl.root at: CGPointMake(mm.orientation == 1 ? CGRectGetMaxX(mm.barRect) + 6 : CGRectGetMinX(mm.barRect) - 6, CGRectGetMidY(t.frame) - 14) displayHeight: ctl.display.size.height]; }
}

/* returns YES when the event is swallowed */
- (BOOL)handle:(CGEventType)type event:(CGEventRef)ev
{
	CGPoint p = CGEventGetLocation(ev); DockModel *m = ctl.model;
	if (menu) {
		if (type == kCGEventMouseMoved) { [menu mouseMovedTo: p]; return NO; }
		if (type == kCGEventLeftMouseDown || type == kCGEventRightMouseDown) {
			if (![menu containsPoint: p]) { [self closeMenu]; return [self inBar: p] && type == kCGEventRightMouseDown ? [self handle: type event: ev] : YES; }
			if ([menu clickAt: p]) menu = nil;
			return YES;
		}
		if (type == kCGEventLeftMouseUp || type == kCGEventRightMouseUp) return [menu containsPoint: p];
	}
	switch (type) {
	case kCGEventRightMouseDown: { DockTile *t = [self tileAt: p]; if (!t) return NO; [self showMenuFor: t]; return YES; }
	case kCGEventRightMouseUp: return [self inBar: p];
	case kCGEventLeftMouseDown: {
		DockTile *t = [self tileAt: p]; if (!t) return NO;
		down = p; pressed = t;
		if (t.kind == DOCK_SEPARATOR) { st = StResizing; resizeY0 = m.orientation == 0 ? p.y : p.x; int pref = [ctl.prefs.values[@"tilesize"] intValue]; baseSize = pref > 0 ? pref : m.tileSize; } else st = StPressed;       /* the preference, not the (shrunk) displayed size */
		return YES; }
	case kCGEventLeftMouseDragged: {
		if (st == StPressed && hypot(p.x - down.x, p.y - down.y) > 5 && [self draggable: pressed] && pressed.iconLayer) {
			st = StDragging; iconHome = pressed.iconLayer.position; [[ctl valueForKey: @"hoverObject"] hideLabel];
			[CATransaction begin]; [CATransaction setDisableActions: YES]; pressed.iconLayer.zPosition = 10; [CATransaction commit];
		}
		if (st == StDragging) {
			[CATransaction begin]; [CATransaction setDisableActions: YES];
			pressed.iconLayer.position = CGPointMake(iconHome.x + (p.x - down.x), iconHome.y + (p.y - down.y)); [CATransaction commit]; [CATransaction flush]; return YES;
		}
		if (st == StResizing) {
			int ts = baseSize + (int)round(ctl.model.orientation == 0 ? resizeY0 - p.y : ctl.model.orientation == 1 ? p.x - resizeY0 : resizeY0 - p.x); if (ts < 16) ts = 16; if (ts > 128) ts = 128;       /* approximate: the real Dock's rule for the divider drag is not measured */
			[ctl setPreference: @(ts) forKey: @"tilesize"]; return YES;
		}
		return st != StIdle; }
	case kCGEventLeftMouseUp: {
		State was = st; st = StIdle; DockTile *t = pressed; pressed = nil;
		if (was == StPressed) { if (t.kind != DOCK_SEPARATOR) DockOpenTile(t); return YES; }
		if (was == StDragging) { [self dropTile: t at: p]; return YES; }
		if (was == StResizing) return YES;
		return [self inBar: p]; }
	default: return NO;
	}
}
- (void)dropTile:(DockTile *)t at:(CGPoint)p
{
	DockModel *m = ctl.model;
	BOOL outside = m.orientation == 0 ? p.y < CGRectGetMinY(m.barRect) - 60 : m.orientation == 1 ? p.x > CGRectGetMaxX(m.barRect) + 60 : p.x < CGRectGetMinX(m.barRect) - 60;                 /* dragged away from the Dock: the tile is taken out (the real Dock shows a puff of smoke: not done) */
	if (t.section == 0) {
		NSMutableArray *apps = [[ctl persistentApps] mutableCopy]; NSUInteger from = [apps indexOfObjectIdenticalTo: t.dict]; if (from == NSNotFound) { [ctl reload]; return; }
		[apps removeObjectAtIndex: from];
		if (!outside) {                                                   /* the new place: before the first persistent tile whose centre is to the right of the pointer */
			NSUInteger to = apps.count; NSUInteger k = 0;
			for (DockTile *o in m.tiles) { if (o.section != 0 || o.kind != DOCK_APP || !o.dict || o == t) continue; if (DockAxis(m, p) < DockTileMid(m, o)) { to = k; break; } k++; }
			[apps insertObject: t.dict atIndex: MIN(to, apps.count)];
		}
		[ctl setPersistentApps: apps];
	} else if (t.section == 2 && t.dict) {
		NSMutableArray *others = [NSMutableArray array]; for (DockTile *o in m.tiles) if (o.section == 2 && o.kind == DOCK_OTHER && o.dict && o != t) [others addObject: o.dict];
		if (!outside) { NSUInteger to = others.count, k = 0; for (DockTile *o in m.tiles) { if (o.section != 2 || o.kind != DOCK_OTHER || !o.dict || o == t) continue; if (DockAxis(m, p) < DockTileMid(m, o)) { to = k; break; } k++; } [others insertObject: t.dict atIndex: MIN(to, others.count)]; }
		[ctl setPreference: others forKey: @"persistent-others"];
	} else [ctl reload];
}
@end
