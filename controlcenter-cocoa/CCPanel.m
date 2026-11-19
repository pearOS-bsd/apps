#include <dlfcn.h>
#import "CCPanel.h"
#import "CCSkyLight.h"
#import "CCDraw.h"
#import "CCGlass.h"
#import "CCGallery.h"
#import "../dock-cocoa/DockWindow.h"
#import "../dock-cocoa/SkyLightAPI.h"
#import <QuartzCore/QuartzCore.h>

NSString *const CCEditModeChanged = @"CCEditModeChanged";
/* window of the real panel: 800,0 656 x 964 (level 22; larger than the panel: room for the shadow, partly off screen); the panel x 966..1274, from y 34 */
#define kWindow CGRectMake(800 + CCDX(), 0, 656, 964)
#define kPanelX (966 + CCDX())
static const CGFloat kPanelY = 34, kPanelW = 308;

static CGRect editPill(CGRect panel) { return CGRectMake(1072 + CCDX(), CGRectGetMaxY(panel) - 33, 96, 24); }          /* "Edit Controls": 502..525 in a panel ending at 533 */

/* CC_STAGES=1: each stage of show() sends a harmless request to the window server (a different getter at each stage), so that the log of the Mach bridge shows how far the program got when it waits for something that never comes (stderr is not visible on pearOS) */
static void ccTrace(const char *s)
{
	static const char *stages[] = { "show: begin", "show: window", "show: layers", "show: applied", "show: root", "show: shown", "show: opened" };
	if (!getenv("CC_STAGES")) return;
	/* stage k = k + 2 calls of SLSGetAppearanceThemeLegacy straight (the cached CCDarkTheme would hide them): the count in the log of the bridge says the stage */
	for (int k = 0; k < 7; k++) if (!strcmp(s, stages[k])) { static int (*f)(void); if (!f) f = dlsym(RTLD_DEFAULT, "SLSGetAppearanceThemeLegacy"); if (f) for (int n = 0; n < k + 2; n++) f(); }
}
@implementation CCPanel
{
	DockWindow *win; CALayer *editGlass; NSMutableDictionary<NSNumber *, NSValue *> *oldFrames; CCControl *resizing; CALayer *layer, *baseLayer, *tileLayer, *glassLayer; NSMutableArray<CALayer *> *glassTiles; NSMutableArray<CALayer *> *tiles; NSMutableArray<CCControl *> *tileOwners; CCControl *hovered; NSUInteger tileGeneration; BOOL editing; CCGallery *gallery;
	CCKind pageKind; BOOL hasPage; CGFloat pageX; NSArray<CCRow *> *pageRows; CCControl *pressed; CGPoint pressPoint; BOOL moved; CCControl *dragSlider; NSTimer *poll;
}
- (BOOL)visible { return win != nil; }
- (BOOL)editing { return editing; }
- (CGRect)panelRect
{
	if (hasPage) return CGRectMake(pageX ?: 964 + CCDX(), 36, 308, 2 + pageRows.count * 40);
	int rows = [CCLayout shared].rows; if (editing) rows = MIN(rows + 2, CCMaxRows());
	CGFloat lastBottom = 42 + (rows - 1) * 76 + 63;
	return CGRectMake(kPanelX, kPanelY, kPanelW, lastBottom + (editing ? 7 : 48) - kPanelY);
}
- (BOOL)containsScreenPoint:(CGPoint)p { return win && (CGRectContainsPoint([self panelRect], p) || [gallery containsScreenPoint: p]); }

/* ---- drawing ---- */
- (void)drawControl:(CCControl *)ct in:(CGContextRef)c dark:(BOOL)dark
{
	const CCCatalogEntry *e = [ct entry]; CGRect r = [ct frame]; CGPoint ctr = CGPointMake(CGRectGetMidX(r), CGRectGetMidY(r));
	int cw = ct.cw, chh = ct.ch; BOOL on = CCIsOn(ct.kind), disc1 = cw == 1 && chh == 1; CGFloat radius = chh == 1 ? 31.5 : 34;
	BOOL whiteTile = disc1 && on;                                                 /* a switched-on one-cell toggle is a white disc with a dark glyph (the Dark Mode button of the real panel) */
	if (CCGlassMode() && !whiteTile) CCFillRRectA(c, r, radius, dark ? 150 : 120, 0.03); else CCFillRRect(c, r, radius, whiteTile ? 255 : (dark ? 111 : 109));
	if (whiteTile && (ct.kind == CCWifi || ct.kind == CCBluetooth || ct.kind == CCAirDrop)) CCFillRGB(c, 10, 132, 255); else CCFillGrey(c, whiteTile ? 0 : 255, 1);      /* the connectivity buttons that are on: a white disc and a blue glyph */
	CGContextSetLineWidth(c, 1.6);
	switch (ct.kind) {
	case CCDisplay: case CCSound: case CCKeyboardBrightness: {
		BOOL wide = cw == 4, disp = ct.kind != CCSound; CGFloat x0, x1; CCSliderRange(ct, &x0, &x1);
		CCText(c, [NSString stringWithUTF8String: e->title], r.origin.x + (wide ? 16 : 18), r.origin.y + (ct.kind == CCDisplay ? 23 : 22), 13, YES, 255, 0);
		CGFloat y = r.origin.y + (ct.kind == CCDisplay ? 43 : 42);
		CCFillRRect(c, CGRectMake(x0, y - 2, x1 - x0, 4), 2, 150);
		double v = CCSliderGet(ct.kind); if (v > 0.001) { CCFillRRect(c, CGRectMake(x0, y - 2, (x1 - x0) * v, 4), 2, 235); CCFillDisc(c, CGPointMake(x0 + (x1 - x0) * v, y), 14, 255); }
		CCFillGrey(c, 205, 1);
		if (!wide) CCGlyph(c, disp ? @"sun.min" : @"speaker", CGPointMake(r.origin.x + 24, y), 14);
		else if (disp) { CCGlyph(c, @"sun.min", CGPointMake(r.origin.x + 22, y), 14); CCGlyph(c, @"sun.max", CGPointMake(r.origin.x + 268, y), 16); }
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
		if (ct.kind == CCBattery && !disc1) { NSString *t = CCStateText(CCBattery) ?: @"100%"; CCFillGrey(c, 255, 1); CGFloat w = CCTextWidth(t, 13, YES); CCGlyph(c, @"battery", CGPointMake(ctr.x - w / 2 - 14, ctr.y), 20); CCText(c, t, ctr.x - w / 2 + 6, ctr.y + 4.5, 13, YES, 255, 0); }
		else if (disc1) { NSString *g = [NSString stringWithUTF8String: e->glyph]; if (!on && (ct.kind == CCWifi || ct.kind == CCBluetooth)) g = [g stringByAppendingString: @".slash"]; CCGlyph(c, g, ctr, 22); }
		else if (chh == 2) {                                                    /* big square tile: glyph above, title below */
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
/* The panel is a base (the rounded background, the empty slots of edit mode, the "Edit Controls" pill, or a page) and one small layer per control, so that a control can be animated on its own (hover and press springs, like the real SwiftUI tiles). */
- (CGImageRef)newImage
{
	BOOL dark = CCDarkTheme(); CCSetDarkInk(CCGlassMode() && !dark); CGRect panel = [self panelRect];
	CGContextRef c = CCBeginBitmap(kWindow.size, kWindow.origin);
	if (hasPage) { [self drawPage: c in: panel dark: dark]; return CCEndBitmap(c); }
	if (!CCGlassMode()) CCFillRRect(c, panel, 37, dark ? (editing ? 58 : 61) : 219);       /* with glass the panel has no body: the controls float */
	CCLayout *lay = [CCLayout shared];
	if (editing) {
		int rows = MIN(lay.rows + 2, CCMaxRows());
		for (int rw = 0; rw < rows; rw++) for (int cl = 0; cl < 4; cl++) {                      /* empty slots */
			BOOL used = NO; for (CCControl *ct in lay.controls) { if (cl >= ct.col && cl < ct.col + ct.cw && rw >= ct.row && rw < ct.row + ct.ch) used = YES; }
			if (!used) { CGRect r = CCCellRect(cl, rw, 1, 1); CCFillDisc(c, CGPointMake(CGRectGetMidX(r), CGRectGetMidY(r)), 63, dark ? 93 : 190); }
		}
	} else {
		CGRect p = editPill(panel); if (!CCGlassMode()) CCFillRRect(c, p, 12, dark ? 111 : 109); CCText(c, @"Edit Controls", CGRectGetMidX(p), CGRectGetMidY(p) + 4.5, 13, YES, 255, 0.5);
	}
	return CCEndBitmap(c);
}
static const CGFloat kTilePad = 4;
- (CGRect)tileFrame:(CCControl *)ct { CGRect f = CGRectInset([ct frame], -kTilePad, -kTilePad); return CGRectMake(f.origin.x - kWindow.origin.x, kWindow.size.height - (f.origin.y - kWindow.origin.y) - f.size.height, f.size.width, f.size.height); }
- (CGImageRef)newTileImage:(CCControl *)ct dark:(BOOL)dark
{
	CCSetDarkInk(CCGlassMode() && !dark);
	CGRect f = CGRectInset([ct frame], -kTilePad, -kTilePad);
	CGContextRef c = CCBeginBitmap(f.size, f.origin); [self drawControl: ct in: c dark: dark];
	if (editing) { CGRect r = [ct frame]; CGPoint b = CGPointMake(r.origin.x + 8, r.origin.y + 8); CCFillDisc(c, b, 19, dark ? 66 : 120); CCFillGrey(c, 255, 1); CGContextSetLineWidth(c, 1.4); CCGlyph(c, @"minus", b, 14);
		int n; CCSizesFor(ct.kind, &n); if (n > 1) { CGPoint h = CGPointMake(CGRectGetMaxX(r) - 10, CGRectGetMaxY(r) - 10); CCFillDisc(c, h, 19, dark ? 66 : 120); CCFillGrey(c, 255, 1); CCGlyph(c, @"resize", h, 12); } }
	return CCEndBitmap(c);
}
/* The tiles are drawn one per run-loop turn after the panel is shown (a slow or blocking control does not hold the whole panel back); a newer redraw cancels the older one */
- (void)fillTile:(NSUInteger)i generation:(NSUInteger)gen fade:(BOOL)fade dark:(BOOL)dark
{
	if (!win || gen != tileGeneration || i >= tileOwners.count) return;
	CCControl *ct = tileOwners[i]; CALayer *l = tiles[i]; CGImageRef img = [self newTileImage: ct dark: dark];
	[CATransaction begin]; [CATransaction setDisableActions: YES];
	l.frame = [self tileFrame: ct];
	if (fade && l.contents) { CATransition *t = [CATransition animation]; t.type = kCATransitionFade; t.duration = 0.15; t.timingFunction = [CAMediaTimingFunction functionWithName: kCAMediaTimingFunctionEaseInEaseOut]; [l addAnimation: t forKey: @"contents-fade"]; }
	l.contents = (__bridge id)img; CGImageRelease(img); [CATransaction commit]; [CATransaction flush];
	__weak CCPanel *w = self; dispatch_async(dispatch_get_main_queue(), ^{ [w fillTile: i + 1 generation: gen fade: fade dark: dark]; });
}
- (void)syncTiles:(BOOL)fade dark:(BOOL)dark
{
	NSArray<CCControl *> *cs = [CCLayout shared].controls; if (getenv("CC_TILELIMIT")) cs = [cs subarrayWithRange: NSMakeRange(0, MIN(cs.count, (NSUInteger)atoi(getenv("CC_TILELIMIT"))))];
	BOOL same = cs.count == tileOwners.count;
	for (NSUInteger i = 0; same && i < cs.count; i++) if (tileOwners[i] != cs[i]) same = NO;
	[CATransaction begin]; [CATransaction setDisableActions: YES];
	if (!same) {
		for (CALayer *l in tiles) [l removeFromSuperlayer]; tiles = [NSMutableArray array]; tileOwners = [NSMutableArray array]; hovered = nil;
		for (CALayer *g in glassTiles) [g removeFromSuperlayer]; glassTiles = [NSMutableArray array];
		for (CCControl *ct in cs) {
			CALayer *l = [CALayer layer]; l.contentsGravity = kCAGravityResize; l.frame = [self tileFrame: ct]; [tileLayer addSublayer: l]; [tiles addObject: l]; [tileOwners addObject: ct];
			if (CCGlassMode() && glassLayer) { CGRect f = CGRectInset([self tileFrame: ct], kTilePad, kTilePad); CALayer *g = CCGlassLayer(f, ct.ch == 1 ? 31.5 : 34); [glassLayer addSublayer: g ?: [CALayer layer]]; [glassTiles addObject: g ?: [CALayer layer]]; }
			NSValue *old = oldFrames[@((NSUInteger)(__bridge void *)ct)];
			if (old) { CGRect of; [old getValue: &of]; CGRect nf = l.frame; CALayer *g = glassTiles.count ? glassTiles.lastObject : nil;
				if (of.size.width == nf.size.width && of.size.height == nf.size.height) { if (!CGRectEqualToRect(of, nf)) for (CALayer *t in @[ l, g ?: l ]) { CASpringAnimation *a = CCSwiftUISpring(@"position", 0.4867, 1.0); CGPoint from = CGPointMake(CGRectGetMidX(of), CGRectGetMidY(of)), to = t.position; a.fromValue = [NSValue valueWithBytes: &from objCType: @encode(CGPoint)]; a.toValue = [NSValue valueWithBytes: &to objCType: @encode(CGPoint)]; [t addAnimation: a forKey: @"glide"]; } }
				else for (CALayer *t in @[ l, g ?: l ]) { CASpringAnimation *a = CCSwiftUISpring(@"opacity", 0.4867, 1.0); a.fromValue = @0; a.toValue = @1; [t addAnimation: a forKey: @"grow"]; } }
		}
	}
	/* the glass of the "Edit Controls" pill */
	if (CCGlassMode() && glassLayer) {
		CGRect ep = editPill([self panelRect]); CGRect lr = CGRectMake(ep.origin.x - kWindow.origin.x, kWindow.size.height - (ep.origin.y - kWindow.origin.y) - ep.size.height, ep.size.width, ep.size.height);
		if (!editGlass) { editGlass = CCGlassLayer(lr, 12); if (editGlass) [glassLayer addSublayer: editGlass]; }
		editGlass.position = CGPointMake(CGRectGetMidX(lr), CGRectGetMidY(lr)); editGlass.hidden = editing || hasPage;
	}
	oldFrames = nil;
	[CATransaction commit];
	tileGeneration++; NSUInteger gen = tileGeneration; __weak CCPanel *w = self;
	dispatch_async(dispatch_get_main_queue(), ^{ [w fillTile: 0 generation: gen fade: fade && same dark: dark]; });
}
- (void)applyFading:(BOOL)fade
{
	if (!win) return;
	CGImageRef img = [self newImage]; CCSetBandedContentsFade(baseLayer, img, 32, fade); CGImageRelease(img);
	tileLayer.hidden = hasPage; if (!hasPage && !getenv("CC_NOTILES")) [self syncTiles: fade dark: CCDarkTheme()];
	[CATransaction flush]; [gallery redraw];
}
/* a tile's scale on a spring from where it is now: the real ControlCenter's pointer feedback is spring(0.2, 1.0) and spring(0.25, 0.75) (80 and 50 calls while the pointer moved over the open panel; which is the press and which the hover is a GUESS) */
- (void)scaleTile:(CCControl *)ct to:(CGFloat)s response:(double)r damping:(double)z
{
	NSUInteger i = ct ? [tileOwners indexOfObjectIdenticalTo: ct] : NSNotFound; if (i == NSNotFound) return; CALayer *l = tiles[i];
	CATransform3D now = l.presentationLayer ? ((CALayer *)l.presentationLayer).transform : l.transform, to = CATransform3DMakeScale(s, s, 1);
	CASpringAnimation *a = CCSwiftUISpring(@"transform", r, z); a.fromValue = [NSValue valueWithCATransform3D: now]; a.toValue = [NSValue valueWithCATransform3D: to];
	[CATransaction begin]; [CATransaction setDisableActions: YES]; l.transform = to; [CATransaction commit]; [l addAnimation: a forKey: @"scale"];
	if (i < glassTiles.count) { CALayer *g = glassTiles[i]; [CATransaction begin]; [CATransaction setDisableActions: YES]; g.transform = to; [CATransaction commit]; [g addAnimation: [a copy] forKey: @"scale"]; }
	[CATransaction flush];
}
- (void)hoverAt:(CGPoint)p
{
	if (!win || hasPage || editing) return;
	CCControl *ct = CGRectContainsPoint([self panelRect], p) ? [[CCLayout shared] controlAtPoint: p] : nil; if (ct == hovered || pressed) return;
	[self scaleTile: hovered to: 1 response: 0.25 damping: 0.75]; hovered = ct; [self scaleTile: ct to: 1.02 response: 0.25 damping: 0.75];
}
/* a control moved, was resized, added or removed: the tile layers are rebuilt, and a tile that only moved glides there on a spring (the SwiftUI layout animation; the constants are the (0.4867, 1.0) one) */
- (void)relayout
{
	oldFrames = [NSMutableDictionary dictionary]; for (NSUInteger i = 0; i < tileOwners.count; i++) oldFrames[@((NSUInteger)(__bridge void *)tileOwners[i])] = ({ CGRect fr = tiles[i].frame; [NSValue valueWithBytes: &fr objCType: @encode(CGRect)]; });
	tileOwners = nil; [self redraw];
}
- (void)redrawFading { [self applyFading: YES]; }
- (void)redraw { [self applyFading: NO]; }

/* ---- window ---- */
/* The real ControlCenter animates with SwiftUI springs; the constants of its code (22 Animation.spring call sites, REA: docs/development/CONTROLCENTER-ANIMATIONS.md): (response, damping) = (0.4867, 1.0) x7, (0.5, 1.0) x5, (0.5, 0.85) x5,
 * (0.33, 0.825) x2, (0.33, 1.0), (0.15, 0.85), (0.5, 0.3), (0.6283, 0.7333).  Which call site is the panel's opening is NOT identified (the sites are static Animation values without names): the open uses the most used one, (0.4867, 1.0),
 * on the scale and the opacity; the scale from 94 % about the top-right corner is a GUESS, the fade-out of 0.12 s too. */
- (void)animateOpen
{
	CGFloat ax = kPanelX + kPanelW - kWindow.origin.x, ay = kWindow.size.height - kPanelY, cx = kWindow.size.width / 2, cy = kWindow.size.height / 2;
	CATransform3D s = CATransform3DMakeScale(0.94, 0.94, 1), from = CATransform3DConcat(CATransform3DConcat(CATransform3DMakeTranslation(-(ax - cx), -(ay - cy), 0), s), CATransform3DMakeTranslation(ax - cx, ay - cy, 0));
	CASpringAnimation *sp = CCRawSpring(@"transform", 1, 631.6547, 51.6603);       /* read at run time from the real ControlCenter (lldb breakpoint on Animation.interpolatingSpring while its panel opened): mass 1, stiffness 631.6547 (= (2 pi / 0.25)^2), damping 51.6603 (zeta 1.03) */ sp.fromValue = [NSValue valueWithCATransform3D: from]; sp.toValue = [NSValue valueWithCATransform3D: CATransform3DIdentity];
	CASpringAnimation *fade = CCRawSpring(@"opacity", 1, 631.6547, 51.6603); fade.fromValue = @0; fade.toValue = @1;
	[layer addAnimation: sp forKey: @"open-scale"]; [layer addAnimation: fade forKey: @"open-fade"]; [CATransaction flush];
}
/* a page replaces the panel (modal anchored to the tile: the real code uses interpolatingSpring(mass 2, stiffness 300, damping 50) in "modalAnchoredFromDisplayable", read from the binary) */
- (void)animatePageIn
{
	CGRect r = [self panelRect]; CGFloat ax = CGRectGetMaxX(r) - kWindow.origin.x, ay = kWindow.size.height - r.origin.y, cx = kWindow.size.width / 2, cy = kWindow.size.height / 2;
	CATransform3D s = CATransform3DMakeScale(0.96, 0.96, 1), from = CATransform3DConcat(CATransform3DConcat(CATransform3DMakeTranslation(-(ax - cx), -(ay - cy), 0), s), CATransform3DMakeTranslation(ax - cx, ay - cy, 0));
	CASpringAnimation *sp = [CASpringAnimation animationWithKeyPath: @"transform"]; sp.mass = 2; sp.stiffness = 300; sp.damping = 50; sp.duration = sp.settlingDuration;
	sp.fromValue = [NSValue valueWithCATransform3D: from]; sp.toValue = [NSValue valueWithCATransform3D: CATransform3DIdentity]; [layer addAnimation: sp forKey: @"page-scale"]; [CATransaction flush];
}
/* The glass of the real panel: Liquid Glass layers (CCGlass.m, the tree of NSGlassEffectView), one for the panel and one for each control, under the drawn content.  glassTiles is parallel to tiles. */
- (void)addBackdrop
{
	glassLayer = [CALayer layer]; glassLayer.frame = layer.bounds; [layer addSublayer: glassLayer];
	/* the real panel has no glass of its own: the controls float on the wallpaper, each one a glass shape (Control Center of macOS 26) */
}
- (void)show
{
	const SkyLightAPI *sl = SkyLightLoad(); const CCSkyLight *cc = CCSkyLightLoad(); if (!sl) return;
	ccTrace("show: begin"); win = [[DockWindow alloc] initWithFrame: kWindow level: 22 options: 0x10000]; ccTrace(win ? "show: window" : "show: NO window");
	if (!win) { NSLog(@"cc: panel window not created"); return; }
	layer = [CALayer layer]; layer.frame = CGRectMake(0, 0, kWindow.size.width, kWindow.size.height);
	if (CCGlassMode()) [self addBackdrop];
	baseLayer = [CALayer layer]; baseLayer.frame = layer.bounds; tileLayer = [CALayer layer]; tileLayer.frame = layer.bounds; [layer addSublayer: baseLayer]; [layer addSublayer: tileLayer]; tiles = nil; tileOwners = nil; hovered = nil;
	ccTrace("show: layers"); [self applyFading: NO]; ccTrace("show: applied");
	[win setRootLayer: layer]; ccTrace("show: root");
	if (cc->SetWindowClientPerceivedType) cc->SetWindowClientPerceivedType(sl->MainConnectionID(), win.windowID, 5);
	CCShowWindow(win, 22); ccTrace("show: shown");
	[self animateOpen]; ccTrace("show: opened");
	__weak CCPanel *w = self; poll = [NSTimer scheduledTimerWithTimeInterval: 1 repeats: YES block: ^(NSTimer *t) { (void)t; [w redraw]; }];       /* states change outside (appearance, preferences) */
}
- (void)hide
{
	if (!win) return;
	hasPage = NO; pageRows = nil; pageX = 0; editGlass = nil;
	[self setEditing: NO]; [poll invalidate]; poll = nil;
	DockWindow *dying = win; CALayer *dl = layer; win = nil; layer = nil;
	CABasicAnimation *fade = [CABasicAnimation animationWithKeyPath: @"opacity"]; fade.fromValue = @1; fade.toValue = @0; fade.duration = 0.12; fade.fillMode = kCAFillModeForwards; fade.removedOnCompletion = NO; [dl addAnimation: fade forKey: @"close-fade"]; [CATransaction flush];       /* 0.12 s fade out (approximate), then the window goes */
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.14 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ const SkyLightAPI *sl = SkyLightLoad(); if (sl && sl->ReleaseWindow) sl->ReleaseWindow(sl->MainConnectionID(), dying.windowID); });
}
- (void)toggleExtra:(CCKind)k atX:(CGFloat)itemMidX                  /* a click on a menu-bar extra: the page of the control under it */
{
	if (win && hasPage && pageKind == k) { [self hide]; return; }
	if (win) [self hide];
	[self show]; pageKind = k; pageRows = CCPageRows(k); if (!pageRows) { [self hide]; return; }
	hasPage = YES; pageX = MAX(8, MIN(1272 + CCDX() - 308, itemMidX - 154)); [self redraw];
}
- (void)toggle { if (win) [self hide]; else [self show]; }
- (void)setEditing:(BOOL)on
{
	if (on == editing) return;
	editing = on;
	if (on) gallery = [[CCGallery alloc] initWithPanel: self]; else { [gallery close]; gallery = nil; }
	[self redrawFading]; [[NSNotificationCenter defaultCenter] postNotificationName: CCEditModeChanged object: self userInfo: @{ @"editing": @(on) }];
}
- (void)scrollGallery:(double)dy { [gallery scrollBy: dy]; }
- (void)typeInGallery:(NSString *)s { [gallery typeText: s]; }
- (BOOL)addControl:(CCKind)k { BOOL ok = [[CCLayout shared] add: k]; [self relayout]; return ok; }

/* ---- mouse ---- */
- (CCControl *)sliderAt:(CGPoint)p { CCControl *c = [[CCLayout shared] controlAtPoint: p]; if (!c) return nil; return (c.kind == CCDisplay || c.kind == CCSound || c.kind == CCKeyboardBrightness) ? c : nil; }
- (void)setSlider:(CCControl *)c atX:(CGFloat)x
{
	CGFloat x0, x1; CCSliderRange(c, &x0, &x1);
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
		for (CCControl *c in [lay.controls copy]) { CGRect r = [c frame]; if (hypot(p.x - (r.origin.x + 8), p.y - (r.origin.y + 8)) <= 10) { [lay remove: c]; [self relayout]; return YES; } }
		for (CCControl *c in lay.controls) { int n; CCSizesFor(c.kind, &n); CGRect r = [c frame]; if (n > 1 && hypot(p.x - (CGRectGetMaxX(r) - 10), p.y - (CGRectGetMaxY(r) - 10)) <= 12) { resizing = c; return YES; } }
		pressed = ct; pressPoint = p; return YES;
	}
	if (hasPage) {
		CGRect pr = [self panelRect]; NSInteger i = (NSInteger)floor((p.y - pr.origin.y - 1) / 40);
		if (i >= 0 && i < (NSInteger)pageRows.count) { CCRow *row = pageRows[i]; if (row.action) row.action(); pageRows = CCPageRows(pageKind); [self performSelector: @selector(refreshPage) withObject: nil afterDelay: 0.3]; [self redraw]; }
		return YES;
	}
	if (CGRectContainsPoint(editPill([self panelRect]), p)) { [self setEditing: YES]; return YES; }
	CCControl *s = [self sliderAt: p]; if (s && p.y > [s frame].origin.y + 28) { dragSlider = s; [self setSlider: s atX: p.x]; return YES; }
	pressed = ct; pressPoint = p; [self scaleTile: ct to: 0.97 response: 0.2 damping: 1.0]; return YES;
}
- (BOOL)mouseDragged:(CGPoint)p
{
	if (!win) return NO;
	if (dragSlider) { [self setSlider: dragSlider atX: p.x]; return YES; }
	if (resizing) {                                                                      /* the handle follows the pointer: the nearest size the control offers that fits */
		CGRect r = [resizing frame]; double wc = (p.x + 10 - r.origin.x) / 76.33, hc = (p.y + 10 - r.origin.y) / 76; int n; const CCSize *s = CCSizesFor(resizing.kind, &n), *best = NULL; double bd = 1e9;
		for (int i = 0; i < n; i++) { double d = fabs(s[i].w - wc) + fabs(s[i].h - hc); if (d < bd) { bd = d; best = &s[i]; } }
		if (best && (best->w != resizing.cw || best->h != resizing.ch) && [[CCLayout shared] resizeControl: resizing toW: best->w h: best->h]) [self relayout];
		return YES;
	}
	if (pressed && hypot(p.x - pressPoint.x, p.y - pressPoint.y) > 4) moved = YES;
	return pressed != nil;
}
- (BOOL)mouseUp:(CGPoint)p
{
	if (!win) return NO;
	if (dragSlider) { dragSlider = nil; return YES; }
	if (resizing) { resizing = nil; [[CCLayout shared] commit]; return YES; }
	CCControl *ct = pressed; pressed = nil; if (!ct) return NO;
	[self scaleTile: ct to: (hovered == ct ? 1.02 : 1) response: 0.25 damping: 0.75];
	if (editing) {                                                                       /* drag a control to another cell */
		if (moved) {                                                                    /* the control's top-left follows the pointer; the cell under its centre is the target */
			CGRect f = [ct frame]; int col = (int)floor((f.origin.x + (p.x - pressPoint.x) - 974 - CCDX() + 31) / 76.33), row = (int)floor((f.origin.y + (p.y - pressPoint.y) - 42 + 31) / 76);
			if ([[CCLayout shared] moveControl: ct toCol: col row: row]) [self relayout]; else [self redraw];
		}
		return YES;
	}
	if (!moved && CCPageRows(ct.kind) && ((ct.kind == CCDisplay || ct.kind == CCSound) ? pressPoint.y < [ct frame].origin.y + 28 : (ct.cw == 2 && pressPoint.x > [ct frame].origin.x + 52))) { pageKind = ct.kind; pageX = 0; pageRows = CCPageRows(pageKind); hasPage = YES; [self redrawFading]; [self animatePageIn]; return YES; }
	if (!moved) { CCPerform(ct.kind); [self performSelector: @selector(redrawFading) withObject: nil afterDelay: 0.25]; }
	return YES;
}
@end
