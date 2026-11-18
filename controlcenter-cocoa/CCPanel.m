#import "CCPanel.h"
#import "CCSkyLight.h"
#import "CCDraw.h"
#import "CCGallery.h"
#import "../dock-cocoa/DockWindow.h"
#import "../dock-cocoa/SkyLightAPI.h"
#import <QuartzCore/QuartzCore.h>

NSString *const CCEditModeChanged = @"CCEditModeChanged";
/* window of the real panel: 800,0 656 x 964 (level 22; larger than the panel: room for the shadow, partly off screen); the panel x 966..1274, from y 34 */
static const CGRect kWindow = { {800, 0}, {656, 964} };
static const CGFloat kPanelX = 966, kPanelY = 34, kPanelW = 308;

static CGRect editPill(CGRect panel) { return CGRectMake(1074, CGRectGetMaxY(panel) - 31, 93, 23); }          /* "Edit Controls": 502..525 in a panel ending at 533 */

@implementation CCPanel
{
	DockWindow *win; CALayer *layer; BOOL editing; CCGallery *gallery;
	CCKind pageKind; BOOL hasPage; CGFloat pageX; NSArray<CCRow *> *pageRows; CCControl *pressed; CGPoint pressPoint; BOOL moved; CCControl *dragSlider; NSTimer *poll;
}
- (BOOL)visible { return win != nil; }
- (BOOL)editing { return editing; }
- (CGRect)panelRect
{
	if (hasPage) return CGRectMake(pageX ?: 964, 36, 308, 2 + pageRows.count * 40);
	int rows = [CCLayout shared].rows; if (editing) rows = MIN(rows + 2, CCMaxRows());
	CGFloat lastBottom = 42 + (rows - 1) * 76 + 63;
	return CGRectMake(kPanelX, kPanelY, kPanelW, lastBottom + (editing ? 7 : 48) - kPanelY);
}
- (BOOL)containsScreenPoint:(CGPoint)p { return win && (CGRectContainsPoint([self panelRect], p) || [gallery containsScreenPoint: p]); }

/* ---- drawing ---- */
- (void)drawControl:(CCControl *)ct in:(CGContextRef)c dark:(BOOL)dark
{
	const CCCatalogEntry *e = [ct entry]; CGRect r = [ct frame]; CGPoint ctr = CGPointMake(CGRectGetMidX(r), CGRectGetMidY(r));
	BOOL on = CCIsOn(ct.kind), disc1 = e->w == 1 && e->h == 1; CGFloat radius = (e->h == 1 && e->w <= 2) ? 31.5 : 24;
	BOOL whiteTile = disc1 && on;                                                 /* a switched-on one-cell toggle is a white disc with a dark glyph (the Dark Mode button of the real panel) */
	CCFillRRect(c, r, radius, whiteTile ? 255 : (dark ? 111 : 109));
	CGFloat ink = whiteTile ? 0 : 255; CCFillGrey(c, ink, 1); CGContextSetLineWidth(c, 1.6);
	switch (ct.kind) {
	case CCDisplay: case CCSound: case CCKeyboardBrightness: {
		CCText(c, [NSString stringWithUTF8String: e->title], r.origin.x + 16, r.origin.y + (ct.kind == CCDisplay ? 23 : 22), 13, YES, 255, 0);
		BOOL disp = ct.kind != CCSound; CGFloat y = r.origin.y + (ct.kind == CCDisplay ? 43 : 42), x0 = r.origin.x + (disp ? 36 : 34), x1 = r.origin.x + (disp ? 254 : 216);
		CCFillRRect(c, CGRectMake(x0, y - 2, x1 - x0, 4), 2, 150);
		double v = CCSliderGet(ct.kind); if (v > 0.001) { CCFillRRect(c, CGRectMake(x0, y - 2, (x1 - x0) * v, 4), 2, 235); CCFillDisc(c, CGPointMake(x0 + (x1 - x0) * v, y), 14, 255); }
		CCFillGrey(c, 205, 1);
		if (disp) { CCGlyph(c, @"sun.min", CGPointMake(r.origin.x + 22, y), 14); CCGlyph(c, @"sun.max", CGPointMake(r.origin.x + 268, y), 16); }
		else { CCGlyph(c, @"speaker", CGPointMake(r.origin.x + 20, y), 16); CCGlyph(c, @"speaker.wave", CGPointMake(r.origin.x + 231, y), 16); CCFillDisc(c, CGPointMake(r.origin.x + 265, y), 26, 147); CCFillGrey(c, 255, 1); CCGlyph(c, @"airplay", CGPointMake(r.origin.x + 265, y), 16); }
		break; }
	case CCNowPlaying: {
		NSString *title = CCNowPlayingTitle(), *artist = CCNowPlayingArtist(); CGImageRef art = CCNowPlayingArtwork();
		CGRect ar = CGRectMake(r.origin.x + 14, r.origin.y + 12, 40, 40);
		if (art) { CGContextSaveGState(c); CCRRect(c, ar, 8); CGContextClip(c); CGContextTranslateCTM(c, ar.origin.x, ar.origin.y + 40); CGContextScaleCTM(c, 1, -1); CGContextDrawImage(c, CGRectMake(0, 0, 40, 40), art); CGContextRestoreGState(c); }
		else CCFillRRect(c, ar, 8, 138);
		CCText(c, title ?: @"Not Playing", r.origin.x + 14, r.origin.y + (artist ? 76 : 83), 13, YES, 255, 0); if (artist) CCText(c, artist, r.origin.x + 14, r.origin.y + 92, 12, NO, 200, 0);
		CGFloat by = r.origin.y + 111; CCFillGrey(c, 255, 1); CCGlyph(c, CCNowPlayingIsPlaying() ? @"pause" : @"play", CGPointMake(r.origin.x + 70, by), 24);
		CCFillGrey(c, title ? 255 : 160, 1); CCGlyph(c, @"rewind", CGPointMake(r.origin.x + 33, by), 24); CCGlyph(c, @"forward", CGPointMake(r.origin.x + 110, by), 24);
		break; }
	default:
		if (disc1) { CCGlyph(c, [NSString stringWithUTF8String: e->glyph], ctr, 22); }
		else if (e->h == 2) {                                                    /* big square tile: glyph above, title below */
			CCGlyph(c, [NSString stringWithUTF8String: e->glyph], CGPointMake(r.origin.x + 26, r.origin.y + 28), 24); CCFillGrey(c, 255, 1);
			CCText(c, [NSString stringWithUTF8String: e->title], r.origin.x + 14, r.origin.y + r.size.height - 14, 13, YES, 255, 0);
		} else {                                                                 /* wide: round icon on the left, state or title on the right */
			CGPoint ic = CGPointMake(r.origin.x + 31.5, ctr.y); BOOL conn = ct.kind == CCWifi || ct.kind == CCBluetooth || ct.kind == CCAirDrop, focus = ct.kind == CCFocus;
			CCFillDisc(c, ic, 34, (conn || focus) && on ? 0 : 147); if ((conn || focus) && on) { CCFillRGB(c, focus ? 94 : 10, focus ? 92 : 132, focus ? 230 : 255); CGContextFillEllipseInRect(c, CGRectMake(ic.x - 17, ic.y - 17, 34, 34)); }
			CCFillGrey(c, 255, 1);
			NSString *g = [NSString stringWithUTF8String: e->glyph]; if (!on && (ct.kind == CCWifi || ct.kind == CCBluetooth)) g = [g stringByAppendingString: @".slash"];
			CCGlyph(c, g, ic, 20);
			NSString *st = CCStateText(ct.kind);
			if (conn) { if (on) { CCText(c, [NSString stringWithUTF8String: e->title], r.origin.x + 56, ctr.y - 1, 13, YES, 255, 0); CCText(c, st ?: @"On", r.origin.x + 56, ctr.y + 14, 12, NO, 230, 0); } else CCText(c, st ?: @"Off", r.origin.x + 56, ctr.y + 13, 12, NO, 255, 0); }
			else if (focus) { if (on) { CCText(c, @"Focus", r.origin.x + 56, ctr.y - 1, 13, YES, 255, 0); CCText(c, st ?: @"On", r.origin.x + 56, ctr.y + 14, 12, NO, 230, 0); } }
			else CCText(c, [NSString stringWithUTF8String: e->title], r.origin.x + 56, ctr.y + 4.5, 13, YES, 255, 0);
		}
	}
}
- (void)drawPage:(CGContextRef)c in:(CGRect)r dark:(BOOL)dark
{
	CCFillRRect(c, r, 20, dark ? 111 : 109); CGFloat y = r.origin.y + 1;
	for (NSUInteger i = 0; i < pageRows.count; i++) {
		CCRow *row = pageRows[i]; CGFloat mid = y + 20;
		if (i > 0) { CCFillGrey(c, 131, 1); CGContextFillRect(c, CGRectMake(r.origin.x + 14, y, r.size.width - 28, 1)); }
		BOOL bold = row.type == CCRowSwitch || row.type == CCRowHeader;
		CCText(c, row.title, r.origin.x + 14, mid + 4.5, 13, bold, 255, 0);
		if (row.type == CCRowSwitch) {                                           /* measured: track 57 x 24, knob a 32 x 20 pill */
			CGRect tr = CGRectMake(r.origin.x + 236, mid - 12, 57, 24); CCFillRRect(c, tr, 12, 104); if (row.on) { CCFillRGB(c, 10, 132, 255); CCRRect(c, tr, 12); CGContextFillPath(c); }
			CCFillRRect(c, CGRectMake(row.on ? CGRectGetMaxX(tr) - 38 : tr.origin.x + 6, mid - 10, 32, 20), 10, 255);
		}
		if (row.type == CCRowRadio && row.on) { CCFillRGB(c, 10, 132, 255); CGContextFillEllipseInRect(c, CGRectMake(r.origin.x + r.size.width - 34, mid - 8, 16, 16)); CCFillGrey(c, 255, 1); CGContextSetLineWidth(c, 1.8); CGContextMoveToPoint(c, r.origin.x + r.size.width - 30, mid); CGContextAddLineToPoint(c, r.origin.x + r.size.width - 27, mid + 3); CGContextAddLineToPoint(c, r.origin.x + r.size.width - 22, mid - 3); CGContextStrokePath(c); }
		y += 40;
	}
}
- (CGImageRef)newImage
{
	BOOL dark = CCDarkTheme(); CGRect panel = [self panelRect];
	CGContextRef c = CCBeginBitmap(kWindow.size, kWindow.origin);
	if (hasPage) { [self drawPage: c in: panel dark: dark]; return CCEndBitmap(c); }
	CCFillRRect(c, panel, 37, dark ? (editing ? 58 : 61) : 219);
	CCLayout *lay = [CCLayout shared];
	for (CCControl *ct in lay.controls) [self drawControl: ct in: c dark: dark];
	if (editing) {
		int rows = MIN(lay.rows + 2, CCMaxRows());
		for (int rw = 0; rw < rows; rw++) for (int cl = 0; cl < 4; cl++) {                      /* empty slots */
			BOOL used = NO; for (CCControl *ct in lay.controls) { const CCCatalogEntry *e = [ct entry]; if (cl >= ct.col && cl < ct.col + e->w && rw >= ct.row && rw < ct.row + e->h) used = YES; }
			if (!used) { CGRect r = CCCellRect(cl, rw, 1, 1); CCFillDisc(c, CGPointMake(CGRectGetMidX(r), CGRectGetMidY(r)), 63, dark ? 93 : 190); }
		}
		for (CCControl *ct in lay.controls) {                                                  /* the minus badges */
			CGRect r = [ct frame]; CGPoint b = CGPointMake(r.origin.x + 8, r.origin.y + 8); CCFillDisc(c, b, 19, dark ? 66 : 120); CCFillGrey(c, 255, 1); CGContextSetLineWidth(c, 1.4); CCGlyph(c, @"minus", b, 14);
		}
	} else {
		CGRect p = editPill(panel); CCFillRRect(c, p, 11.5, dark ? 111 : 109); CCText(c, @"Edit Controls", CGRectGetMidX(p), CGRectGetMidY(p) + 4.5, 13, NO, 255, 0.5);
	}
	return CCEndBitmap(c);
}
- (void)redraw { if (!win) return; CGImageRef img = [self newImage]; CCSetBandedContents(layer, img, 32); CGImageRelease(img); [CATransaction flush]; [gallery redraw]; }

/* ---- window ---- */
- (void)show
{
	const SkyLightAPI *sl = SkyLightLoad(); const CCSkyLight *cc = CCSkyLightLoad(); if (!sl) return;
	win = [[DockWindow alloc] initWithFrame: kWindow level: 22 options: 0x10000];
	if (!win) { NSLog(@"cc: panel window not created"); return; }
	layer = [CALayer layer]; layer.frame = CGRectMake(0, 0, kWindow.size.width, kWindow.size.height);
	CGImageRef img = [self newImage]; CCSetBandedContents(layer, img, 32); CGImageRelease(img);
	[win setRootLayer: layer];
	if (cc->SetWindowClientPerceivedType) cc->SetWindowClientPerceivedType(sl->MainConnectionID(), win.windowID, 5);
	CCShowWindow(win, 22);
	__weak CCPanel *w = self; poll = [NSTimer scheduledTimerWithTimeInterval: 1 repeats: YES block: ^(NSTimer *t) { (void)t; [w redraw]; }];       /* states change outside (appearance, preferences) */
}
- (void)hide
{
	if (!win) return;
	hasPage = NO; pageRows = nil; pageX = 0;
	[self setEditing: NO]; [poll invalidate]; poll = nil;
	const SkyLightAPI *sl = SkyLightLoad(); if (sl && sl->ReleaseWindow) sl->ReleaseWindow(sl->MainConnectionID(), win.windowID); win = nil; layer = nil;
}
- (void)toggleExtra:(CCKind)k atX:(CGFloat)itemMidX                  /* a click on a menu-bar extra: the page of the control under it */
{
	if (win && hasPage && pageKind == k) { [self hide]; return; }
	if (win) [self hide];
	[self show]; pageKind = k; pageRows = CCPageRows(k); if (!pageRows) { [self hide]; return; }
	hasPage = YES; pageX = MAX(8, MIN(1272 - 308, itemMidX - 154)); [self redraw];
}
- (void)toggle { if (win) [self hide]; else [self show]; }
- (void)setEditing:(BOOL)on
{
	if (on == editing) return;
	editing = on;
	if (on) gallery = [[CCGallery alloc] initWithPanel: self]; else { [gallery close]; gallery = nil; }
	[self redraw]; [[NSNotificationCenter defaultCenter] postNotificationName: CCEditModeChanged object: self userInfo: @{ @"editing": @(on) }];
}
- (void)scrollGallery:(double)dy { [gallery scrollBy: dy]; }
- (void)typeInGallery:(NSString *)s { [gallery typeText: s]; }
- (BOOL)addControl:(CCKind)k { BOOL ok = [[CCLayout shared] add: k]; [self redraw]; return ok; }

/* ---- mouse ---- */
- (CCControl *)sliderAt:(CGPoint)p { CCControl *c = [[CCLayout shared] controlAtPoint: p]; if (!c) return nil; return (c.kind == CCDisplay || c.kind == CCSound || c.kind == CCKeyboardBrightness) ? c : nil; }
- (void)setSlider:(CCControl *)c atX:(CGFloat)x
{
	CGRect r = [c frame]; BOOL disp = c.kind != CCSound; CGFloat x0 = r.origin.x + (disp ? 36 : 34), x1 = r.origin.x + (disp ? 254 : 216);
	CCSliderSet(c.kind, MAX(0, MIN(1, (x - x0) / (x1 - x0)))); [self redraw];
}
- (void)refreshPage { if (hasPage) { pageRows = CCPageRows(pageKind); [self redraw]; } }
- (BOOL)mouseDown:(CGPoint)p
{
	if (!win) return NO;
	if ([gallery containsScreenPoint: p]) return [gallery mouseDown: p];
	if (!CGRectContainsPoint([self panelRect], p)) return NO;
	CCLayout *lay = [CCLayout shared]; CCControl *ct = [lay controlAtPoint: p]; pressed = nil; moved = NO; dragSlider = nil;
	if (editing) {
		for (CCControl *c in [lay.controls copy]) { CGRect r = [c frame]; if (hypot(p.x - (r.origin.x + 8), p.y - (r.origin.y + 8)) <= 10) { [lay remove: c]; [self redraw]; return YES; } }
		pressed = ct; pressPoint = p; return YES;
	}
	if (hasPage) {
		CGRect pr = [self panelRect]; NSInteger i = (NSInteger)floor((p.y - pr.origin.y - 1) / 40);
		if (i >= 0 && i < (NSInteger)pageRows.count) { CCRow *row = pageRows[i]; if (row.action) row.action(); pageRows = CCPageRows(pageKind); [self performSelector: @selector(refreshPage) withObject: nil afterDelay: 0.3]; [self redraw]; }
		return YES;
	}
	if (CGRectContainsPoint(editPill([self panelRect]), p)) { [self setEditing: YES]; return YES; }
	CCControl *s = [self sliderAt: p]; if (s && p.y > [s frame].origin.y + 28) { dragSlider = s; [self setSlider: s atX: p.x]; return YES; }
	pressed = ct; pressPoint = p; return YES;
}
- (BOOL)mouseDragged:(CGPoint)p
{
	if (!win) return NO;
	if (dragSlider) { [self setSlider: dragSlider atX: p.x]; return YES; }
	if (pressed && hypot(p.x - pressPoint.x, p.y - pressPoint.y) > 4) moved = YES;
	return pressed != nil;
}
- (BOOL)mouseUp:(CGPoint)p
{
	if (!win) return NO;
	if (dragSlider) { dragSlider = nil; return YES; }
	CCControl *ct = pressed; pressed = nil; if (!ct) return NO;
	if (editing) {                                                                       /* drag a control to another cell */
		if (moved) {                                                                    /* the control's top-left follows the pointer; the cell under its centre is the target */
			CGRect f = [ct frame]; int col = (int)floor((f.origin.x + (p.x - pressPoint.x) - 974 + 31) / 76.33), row = (int)floor((f.origin.y + (p.y - pressPoint.y) - 42 + 31) / 76);
			[[CCLayout shared] moveControl: ct toCol: col row: row]; [self redraw];
		}
		return YES;
	}
	if (!moved && CCPageRows(ct.kind) && ((ct.kind == CCDisplay || ct.kind == CCSound) ? pressPoint.y < [ct frame].origin.y + 28 : ([ct entry]->w == 2 && pressPoint.x > [ct frame].origin.x + 52))) { pageKind = ct.kind; pageX = 0; pageRows = CCPageRows(pageKind); hasPage = YES; [self redraw]; return YES; }
	if (!moved) { CCPerform(ct.kind); [self performSelector: @selector(redraw) withObject: nil afterDelay: 0.25]; }
	return YES;
}
@end
