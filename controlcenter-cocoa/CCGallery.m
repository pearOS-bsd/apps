#import "CCGallery.h"
#import "CCPanel.h"
#import "CCDraw.h"
#import "CCSymbols.h"
#import "CCChrono.h"
#import "CCGlass.h"
#import "CCSkyLight.h"
#import "../dock-cocoa/DockWindow.h"
#import "../dock-cocoa/SkyLightAPI.h"
#import <QuartzCore/QuartzCore.h>

/* The real Edit Controls window (macOS 27.0 on a 3440 x 1440 screen, window capture in Solarium captures/27.0-arm64-cc-real): 736 x 900 at x 1352 (centred horizontally, it does not overlap the panel), 736 x 670 on the 1280 x 800
 * screen of 26.7.2: as high as the screen allows up to 900.  An opaque dark window (grey 32; the selected row, the cards and the dividers 52; the controls 42), no glass. */
static CGRect galleryFrame(void) { CGFloat sw = 1280 + CCDX(), sh = CGDisplayBounds(CGMainDisplayID()).size.height; return CGRectMake(round((sw - 736) / 2), 45, 736, MIN(900, sh - 130)); }
#define kFrame galleryFrame()
static const int kSidebarW = 247, kFooterH = 55;
static const CGFloat kContentX = 262, kContentW = 456;      /* the card, the dividers: 262..718 */

/* the icon of a category in the sidebar: a rounded square 26 (the real ones are the icons of the apps: approximations from symbols) */
static const struct { const char *name; int r, g, b; const char *glyph; int fr, fg, fb; } kCatIcon[] = {
	{ "All Controls", -1, 0, 0, NULL, 0, 0, 0 }, { "Battery", 52, 199, 89, "battery.100", 255, 255, 255 }, { "Clock", 250, 250, 250, "clock", 40, 40, 40 }, { "Connectivity", 10, 132, 255, "wifi", 255, 255, 255 },
	{ "Desktop & Finder", 30, 30, 30, "macwindow", 255, 255, 255 }, { "Display & Brightness", 10, 132, 255, "sun.max.fill", 255, 255, 255 }, { "Fast User Switching", 142, 142, 147, "person.crop.circle", 255, 255, 255 },
	{ "Focus", 94, 92, 230, "moon.fill", 255, 255, 255 }, { "Home", 255, 149, 0, "house.fill", 255, 255, 255 }, { "Keyboards", 160, 160, 165, "keyboard", 255, 255, 255 }, { "Lock Screen", 20, 20, 20, "lock.fill", 255, 255, 255 },
	{ "Notes", 255, 214, 10, "note.text", 255, 255, 255 }, { "Now Playing", 250, 250, 250, "waveform", 255, 59, 48 }, { "Screenshot", 250, 250, 250, "camera.viewfinder", 40, 40, 40 }, { "Shortcuts", 150, 70, 230, "square.2.layers.3d.fill", 255, 255, 255 },
	{ "Sounds", 255, 59, 48, "speaker.wave.2.fill", 255, 255, 255 }, { "Utilities", 142, 142, 147, "wrench.and.screwdriver.fill", 255, 255, 255 }, { "Voice Memos", 20, 20, 20, "waveform", 255, 59, 48 }, { "Zoom", 10, 132, 255, "plus.magnifyingglass", 255, 255, 255 },
};
typedef struct { const CCCatalogEntry *e; int col, row, lines; } Placed;

@implementation CCGallery
{
	CCPanel *panel; DockWindow *win; CALayer *layer, *contentLayer; NSMutableArray<NSValue *> *itemRects; NSMutableArray<NSNumber *> *itemKinds; NSMutableArray<NSValue *> *catRects; NSMutableArray<NSNumber *> *sectionY; NSInteger selected; double scroll, contentH; NSMutableString *query; CGRect doneRect;
	int dragKind; CGPoint dragStart; BOOL dragMoved;
}
- (instancetype)initWithPanel:(CCPanel *)p
{
	if (!(self = [super init])) return nil;
	panel = p; query = [NSMutableString string]; itemRects = [NSMutableArray array]; itemKinds = [NSMutableArray array]; catRects = [NSMutableArray array]; sectionY = [NSMutableArray array]; dragKind = -1;
	const SkyLightAPI *sl = SkyLightLoad(); const CCSkyLight *cc = CCSkyLightLoad(); if (!sl) return self;
	win = [[DockWindow alloc] initWithFrame: kFrame level: 23 options: 0x10000]; if (!win) return self;
	layer = [CALayer layer]; layer.frame = CGRectMake(0, 0, kFrame.size.width, kFrame.size.height);
	if (CCGlassMode()) { CALayer *gl = CCGlassLayer(layer.bounds, 26); if (gl) [layer addSublayer: gl]; }       /* the real window is Liquid Glass (the full-screen capture of the Mac: the wallpaper shows through; the dark grey of a window capture is that glass over black) */
	contentLayer = [CALayer layer]; contentLayer.frame = layer.bounds; [layer addSublayer: contentLayer];
	CGImageRef img = [self newImage]; CCSetBandedContents(contentLayer, img, 32); CGImageRelease(img);
	[win setRootLayer: layer];
	if (cc->SetWindowClientPerceivedType) cc->SetWindowClientPerceivedType(sl->MainConnectionID(), win.windowID, 5);
	CCShowWindow(win, 23);
	return self;
}
- (void)close { if (!win) return; const SkyLightAPI *sl = SkyLightLoad(); if (sl && sl->ReleaseWindow) sl->ReleaseWindow(sl->MainConnectionID(), win.windowID); win = nil; layer = nil; }
- (BOOL)containsScreenPoint:(CGPoint)p { return win && CGRectContainsPoint(kFrame, p); }
- (void)redraw { if (!win) return; CGImageRef img = [self newImage]; CCSetBandedContents(contentLayer, img, 32); CGImageRelease(img); [CATransaction flush]; }
- (void)scrollBy:(double)dy { scroll = MAX(0, MIN(MAX(0, contentH - (kFrame.size.height - kFooterH)), scroll - dy)); [self redraw]; }
- (void)typeText:(NSString *)s { if ([s isEqual: @"\b"]) { if (query.length) [query deleteCharactersInRange: NSMakeRange(query.length - 1, 1)]; } else [query appendString: s]; scroll = 0; [self redraw]; }
- (BOOL)isDragging { return dragKind >= 0; }

/* the label inside a tile and the caption under it */
static NSString *labelOf(const CCCatalogEntry *e) { return e->kind == CCTileWindows ? @"Left & Right" : e->kind == CCRunShortcut ? @"Shortcut" : [NSString stringWithUTF8String: e->title]; }
static int captionOf(const CCCatalogEntry *e, NSString * __autoreleasing *l1, NSString * __autoreleasing *l2)
{
	NSString *t = [NSString stringWithUTF8String: e->title]; CGFloat w = e->w == 1 ? 74 : 140;
	if (e->kind == CCTileWindows) t = @"Tile Windows Left\n& Right"; if (e->kind == CCScene) t = @"Scene or\nAccessory";
	NSArray *ls = [t componentsSeparatedByString: @"\n"];
	if (ls.count == 1 && CCTextWidth(t, 12, NO) > w) { NSRange sp = [t rangeOfString: @" " options: NSBackwardsSearch]; if (sp.location != NSNotFound) ls = @[ [t substringToIndex: sp.location], [t substringFromIndex: sp.location + 1] ]; }
	*l1 = ls[0]; *l2 = ls.count > 1 ? ls[1] : nil; return (int)ls.count;
}
static CGSize tileSize(const CCCatalogEntry *e) { return CGSizeMake(e->w == 1 ? 64 : 140, e->h == 2 ? 140 : 64); }

- (void)drawItem:(const CCCatalogEntry *)e rect:(CGRect)r caption:(NSString *)l1 second:(NSString *)l2 in:(CGContextRef)c
{
	BOOL big = e->h == 2, disc = e->w == 1 && e->h == 1; CGFloat rad = big ? 34 : 32;
	if (CCGlassMode()) { CCFillRRectA(c, r, rad, 255, 0.16); CGContextSetLineWidth(c, 1); CCFillGrey(c, 255, 0.22); CCRRect(c, CGRectInset(r, 0.5, 0.5), rad); CGContextStrokePath(c); } else CCFillRRect(c, r, rad, 42); CGContextSaveGState(c); CCRRect(c, r, rad); CGContextClip(c); CCFillGrey(c, 255, 0.10); CGContextFillRect(c, CGRectMake(r.origin.x, r.origin.y, r.size.width, 1)); CGContextRestoreGState(c);       /* the lit top edge */
	CCFillGrey(c, 215, 1); CGContextSetLineWidth(c, 1.6); NSString *g = [NSString stringWithUTF8String: e->glyph];
	CGPoint mid = CGPointMake(CGRectGetMidX(r), CGRectGetMidY(r));
	if (disc) CCGlyph(c, g, mid, 22);
	else if (e->kind == CCBattery) { NSString *t = @"100%"; CGFloat w = CCTextWidth(t, 13, YES); CCFillGrey(c, 255, 1); CCGlyph(c, @"battery.100.bolt", CGPointMake(mid.x - w / 2 - 14, mid.y), 20); CCText(c, t, mid.x - w / 2 + 6, mid.y + 4.5, 13, YES, 255, 0); }
	else if (e->kind == CCDisplay || e->kind == CCSound || e->kind == CCKeyboardBrightness) {            /* a slider */
		CCFillGrey(c, 255, 1); CCText(c, e->kind == CCKeyboardBrightness ? @"Keyboard" : [NSString stringWithUTF8String: e->title], r.origin.x + 18, r.origin.y + 23, 13, YES, 255, 0);
		CCFillRRect(c, CGRectMake(r.origin.x + 38, r.origin.y + 41, 84, 4), 2, 90); CCFillGrey(c, 190, 1); CCGlyph(c, e->kind == CCSound ? @"speaker" : @"sun.min", CGPointMake(r.origin.x + 24, r.origin.y + 43), 14);
	}
	else if (big) {
		CCFillGrey(c, 215, 1); if (e->kind == CCScene) { CCGlyph(c, g, CGPointMake(r.origin.x + 26, r.origin.y + 28), 24); CCFillRRect(c, CGRectMake(r.origin.x + 14, r.origin.y + 90, 34, 6), 3, 235); CCFillRRect(c, CGRectMake(r.origin.x + 14, r.origin.y + 106, 56, 6), 3, 205); }
		else { CCGlyph(c, g, CGPointMake(r.origin.x + 26, r.origin.y + 28), 24); CCFillGrey(c, 255, 1); CCText(c, [NSString stringWithUTF8String: e->title], r.origin.x + 14, r.origin.y + r.size.height - 14, 13, YES, 255, 0); }
	} else {
		BOOL circle = e->kind == CCRecognizeMusic || e->kind == CCWifi || e->kind == CCBluetooth || e->kind == CCAirDrop || e->kind == CCFocus || e->kind == CCScreenMirroring;
		CGPoint ic = CGPointMake(r.origin.x + 32, mid.y); if (circle) CCFillDisc(c, ic, 34, 90); CCFillGrey(c, 235, 1); CCGlyph(c, g, ic, circle ? 20 : 24);
		CCFillGrey(c, 255, 1); NSString *lb = labelOf(e); CGFloat avail = r.size.width - 56 - 2;
		NSRange sp = [lb rangeOfString: @" " options: NSBackwardsSearch];
		if (CCTextWidth(lb, 13, YES) > avail && sp.location != NSNotFound) { CCText(c, [lb substringToIndex: sp.location], r.origin.x + 56, mid.y - 2, 13, YES, 255, 0); CCText(c, [lb substringFromIndex: sp.location + 1], r.origin.x + 56, mid.y + 13, 13, YES, 255, 0); }      /* a long label wraps as in the real one ("Recognize" / "Music") */
		else CCText(c, lb, r.origin.x + 56, mid.y + 4.5, 13, YES, 255, 0);
	}
	CCFillGrey(c, 235, 1); CCText(c, l1, CGRectGetMidX(r), CGRectGetMaxY(r) + 16, 12, NO, 235, 0.5); if (l2) CCText(c, l2, CGRectGetMidX(r), CGRectGetMaxY(r) + 30, 12, NO, 235, 0.5);
}
/* the real packing: the Suggestions in a grid of 6 columns (tile 64, pitch 76), a row as high as its tallest tile with the caption (64 + 14 per line + 18), and the controls of a category three to a row, each centred in a cell of 152 */
- (CGFloat)layoutSuggestions:(NSArray<NSValue *> *)list atY:(CGFloat)y in:(CGContextRef)c
{
	enum { NR = 12 }; BOOL occ[NR + 2][6] = { { 0 } }; Placed pl[16]; int np = 0; CGFloat rowH[NR + 2]; for (int i = 0; i < NR + 2; i++) rowH[i] = 0;
	for (NSValue *v in list) {
		if (np >= 16) break; const CCCatalogEntry *e = [v pointerValue]; int cw = e->w == 1 ? 1 : 2, ch = e->h; BOOL placed = NO;
		for (int r = 0; r < NR && !placed; r++) for (int cl = 0; cl + cw <= 6 && !placed; cl++) {
			BOOL free = YES; for (int a = 0; a < cw; a++) for (int b = 0; b < ch; b++) if (occ[r + b][cl + a]) free = NO; if (!free) continue;
			for (int a = 0; a < cw; a++) for (int b = 0; b < ch; b++) occ[r + b][cl + a] = YES;
			Placed *p = &pl[np++]; p->e = e; p->col = cl; p->row = r; NSString *a, *b; p->lines = captionOf(e, &a, &b); placed = YES;
		}
	}
	for (int i = 0; i < np; i++) if (pl[i].e->h == 1) rowH[pl[i].row] = MAX(rowH[pl[i].row], 64 + 14 * pl[i].lines + 18);
	for (int i = 0; i < np; i++) if (pl[i].e->h == 2) { CGFloat need = 140 + 14 * pl[i].lines + 18; rowH[pl[i].row + 1] = MAX(rowH[pl[i].row + 1], need - MAX(rowH[pl[i].row], 96)); rowH[pl[i].row] = MAX(rowH[pl[i].row], 96); }
	CGFloat top[NR + 3]; top[0] = y; for (int i = 0; i < NR + 2; i++) top[i + 1] = top[i] + rowH[i];
	for (int i = 0; i < np; i++) {
		CGSize sz = tileSize(pl[i].e); CGRect r = CGRectMake(268 + pl[i].col * 76, top[pl[i].row], sz.width, sz.height);
		NSString *a, *b; captionOf(pl[i].e, &a, &b); [self drawItem: pl[i].e rect: r caption: a second: b in: c]; [itemRects addObject: [NSValue valueWithBytes: &r objCType: @encode(CGRect)]]; [itemKinds addObject: @(pl[i].e->kind)];
	}
	return top[NR + 2] - y;
}
- (CGFloat)layoutCategory:(NSArray<NSValue *> *)list atY:(CGFloat)y in:(CGContextRef)c
{
	CGFloat used = 0; NSUInteger n = list.count;
	for (NSUInteger row = 0; row * 3 < n; row++) {
		CGFloat rh = 0; Placed pl[3]; int k = 0;
		for (NSUInteger i = row * 3; i < MIN(n, row * 3 + 3); i++) { const CCCatalogEntry *e = [list[i] pointerValue]; Placed *p = &pl[k++]; p->e = e; NSString *a0, *b0; p->lines = captionOf(e, &a0, &b0); rh = MAX(rh, tileSize(e).height + 14 * p->lines + 18); }
		for (int i = 0; i < k; i++) { CGSize sz = tileSize(pl[i].e); CGRect r = CGRectMake(261 + i * 152 + (152 - sz.width) / 2, y + used, sz.width, sz.height); NSString *a, *b; captionOf(pl[i].e, &a, &b); [self drawItem: pl[i].e rect: r caption: a second: b in: c]; [itemRects addObject: [NSValue valueWithBytes: &r objCType: @encode(CGRect)]]; [itemKinds addObject: @(pl[i].e->kind)]; }
		used += rh;
	}
	return used;
}
- (void)drawPreview:(CGContextRef)c in:(CGRect)r           /* the picture of the card: a panel in the corner of a wallpaper (the real one is a screenshot) */
{
	CGContextSaveGState(c); CCRRect(c, r, 5); CGContextClip(c);
	CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB(); CGFloat cols[8] = { 0.18, 0.38, 0.72, 1, 0.70, 0.35, 0.62, 1 }; CGFloat locs[2] = { 0, 1 }; CGGradientRef gr = CGGradientCreateWithColorComponents(cs, cols, locs, 2);
	CGContextDrawLinearGradient(c, gr, CGPointMake(r.origin.x, r.origin.y), CGPointMake(r.origin.x, CGRectGetMaxY(r)), 0); CGGradientRelease(gr); CGColorSpaceRelease(cs);
	CCFillGrey(c, 255, 0.55); CGContextFillRect(c, CGRectMake(r.origin.x, r.origin.y, r.size.width, 5));
	CGFloat px = CGRectGetMaxX(r) - 52, py = r.origin.y + 10; CCFillGrey(c, 255, 0.45);
	for (int i = 0; i < 3; i++) { CCRRect(c, CGRectMake(px, py + i * 12, 22, 8), 4); CGContextFillPath(c); }
	CCRRect(c, CGRectMake(px + 26, py, 22, 22), 5); CGContextFillPath(c); for (int i = 0; i < 4; i++) { CCRRect(c, CGRectMake(px + (i % 2) * 12, py + 40 + (i / 2) * 10, 10, 8), 4); CGContextFillPath(c); } CCRRect(c, CGRectMake(px, py + 62, 48, 8), 4); CGContextFillPath(c);
	CCFillGrey(c, 255, 0.7); CCRRect(c, CGRectMake(r.origin.x + 40, CGRectGetMaxY(r) - 14, 80, 7), 3.5); CGContextFillPath(c);
	CGContextRestoreGState(c);
}
- (void)drawCatIcon:(NSString *)name in:(CGRect)ic ctx:(CGContextRef)c
{
	NSUInteger i = NSNotFound; for (NSUInteger q = 0; q < sizeof kCatIcon / sizeof *kCatIcon; q++) if ([name isEqual: @(kCatIcon[q].name)]) i = q;
	if (i == NSNotFound) { CCFillRGB(c, 142, 142, 147); CCRRect(c, ic, 6); CGContextFillPath(c); CCFillGrey(c, 255, 1); CCGlyph(c, @"square.grid.2x2", CGPointMake(CGRectGetMidX(ic), CGRectGetMidY(ic)), 16); return; }
	if (kCatIcon[i].r < 0) { CCFillGrey(c, 255, 1); for (int a = 0; a < 2; a++) for (int b = 0; b < 2; b++) CCFillDisc(c, CGPointMake(ic.origin.x + 7 + a * 12, ic.origin.y + 7 + b * 12), 9, 245); return; }
	CCFillRGB(c, kCatIcon[i].r, kCatIcon[i].g, kCatIcon[i].b); CCRRect(c, ic, 6); CGContextFillPath(c);
	if (kCatIcon[i].glyph) { CCFillRGB(c, kCatIcon[i].fr, kCatIcon[i].fg, kCatIcon[i].fb); CCGlyph(c, @(kCatIcon[i].glyph), CGPointMake(CGRectGetMidX(ic), CGRectGetMidY(ic)), 17); }
}
- (CGImageRef)newImage
{
	CGFloat W = kFrame.size.width, H = kFrame.size.height;
	CGContextRef c = CCBeginBitmap(kFrame.size, CGPointMake(0, 0));
	BOOL glass = CCGlassMode(); if (!glass) CCFillRRect(c, CGRectMake(0, 0, W, H), 26, 32);
	CGContextSaveGState(c); CCRRect(c, CGRectMake(0, 0, W, H), 26); CGContextClip(c);
	[itemRects removeAllObjects]; [itemKinds removeAllObjects]; [catRects removeAllObjects]; [sectionY removeAllObjects];
	/* content, clipped (scrolls) */
	CGContextSaveGState(c); CGContextClipToRect(c, CGRectMake(kSidebarW, 0, W - kSidebarW, H - kFooterH));
	CGContextTranslateCTM(c, 0, -scroll);
	CGFloat y = 20; size_t n; const CCCatalogEntry *cat = CCCatalog(&n); NSArray *cats = CCCategories();
	if (!query.length) {
		if (glass) CCFillRRectA(c, CGRectMake(kContentX, y, kContentW, 169), 10, 255, 0.12); else CCFillRRect(c, CGRectMake(kContentX, y, kContentW, 169), 10, 52); CCText(c, @"What's New", kContentX + 20, y + 44, 14, YES, 255, 0);
		NSArray *ln = @[ @"Control Center is more flexible", @"than ever — resize and rearrange", @"items to customize and access", @"what matters most to you. Your", @"favorite controls can also be added", @"to the menu bar." ];
		for (NSUInteger i = 0; i < ln.count; i++) CCText(c, ln[i], kContentX + 20, y + 65 + i * 15, 12, NO, 255, 0);
		[self drawPreview: c in: CGRectMake(kContentX + 236, y + 20, 200, 130)];
		y += 189 + 6; CCText(c, @"Suggestions", kContentX, y + 6, 12, YES, 160, 0); y += 29;
		NSMutableArray *sl = [NSMutableArray array]; for (NSNumber *k in @[ @(CCScene), @(CCAlarm), @(CCStopwatch), @(CCTileWindows), @(CCRunShortcut), @(CCZoom), @(CCVoiceMemo), @(CCQuickNote), @(CCRecognizeMusic) ]) if (CCCatalogVisible((CCKind)k.intValue)) [sl addObject: [NSValue valueWithPointer: CCCatalogFor(k.intValue)]];
		y += [self layoutSuggestions: sl atY: y in: c] + 11;
		for (NSUInteger ci = 1; ci < cats.count; ci++) {
			NSMutableArray *items = [NSMutableArray array]; for (size_t i = 0; i < n; i++) if ([cats[ci] isEqual: [NSString stringWithUTF8String: cat[i].category]]) [items addObject: [NSValue valueWithPointer: &cat[i]]];
			[sectionY addObject: @(y)]; if (!items.count) continue;
			if (glass) CCFillGrey(c, 255, 0.14); else CCFillGrey(c, 52, 1); CGContextFillRect(c, CGRectMake(kContentX, y, kContentW, 1)); CCText(c, cats[ci], kContentX, y + 25, 12, YES, 160, 0); y += 49;
			y += [self layoutCategory: items atY: y in: c] + 13;
		}
	} else {
		NSMutableArray *list = [NSMutableArray array];
		for (size_t i = 0; i < n; i++) { NSString *title = [NSString stringWithUTF8String: cat[i].title]; if ([title rangeOfString: query options: NSCaseInsensitiveSearch].location != NSNotFound) [list addObject: [NSValue valueWithPointer: &cat[i]]]; }
		if (!list.count) CCText(c, @"No Results", kSidebarW + 245, 200, 14, NO, 160, 0.5);
		y += [self layoutCategory: list atY: y + 10 in: c];
	}
	contentH = y + 20;
	CGContextRestoreGState(c);
	/* footer */
	if (!glass) { CCFillGrey(c, 32, 1); CGContextFillRect(c, CGRectMake(kSidebarW, H - kFooterH, W - kSidebarW, kFooterH)); } if (glass) CCFillGrey(c, 255, 0.14); else CCFillGrey(c, 52, 1); CGContextFillRect(c, CGRectMake(kSidebarW, H - kFooterH, W - kSidebarW, 1));
	CCText(c, @"Drag a control to place it in Control Center or Menu Bar…", kContentX, H - 24, 12.5, NO, 255, 0);
	doneRect = CGRectMake(W - 79, H - 48, 59, 28); CCFillRGB(c, 9, 127, 255); CCRRect(c, doneRect, 14); CGContextFillPath(c); CCFillGrey(c, 255, 1); CCText(c, @"Done", CGRectGetMidX(doneRect), CGRectGetMidY(doneRect) + 4.5, 13, YES, 255, 0.5);
	/* scroll bar of the content */
	if (contentH > H - kFooterH) { CGFloat vis = H - kFooterH, th = MAX(30, vis * vis / contentH), ty = 6 + (vis - th - 12) * (scroll / MAX(1, contentH - vis)); CCFillGrey(c, 159, 1); CCRRect(c, CGRectMake(W - 11, ty, 5, th), 2.5); CGContextFillPath(c); }
	/* sidebar: search field and categories */
	if (glass) CCFillRRectA(c, CGRectMake(19, 19, 207, 32), 10, 0, 0.30); else CCFillRRect(c, CGRectMake(19, 19, 207, 32), 10, 30); CGContextSetLineWidth(c, 2); CCFillRGB(c, 53, 125, 167); CCRRect(c, CGRectMake(19, 19, 207, 32), 10); CGContextStrokePath(c); CCFillGrey(c, 170, 1); CCGlyph(c, @"magnifier", CGPointMake(34, 35), 15);
	CCText(c, query.length ? query : @"Search Controls", 50, 40, 13, NO, query.length ? 255 : 160, 0);
	CGFloat cy = 58; if (selected < 0) selected = 0;
	CGContextSaveGState(c); CGContextClipToRect(c, CGRectMake(0, 56, kSidebarW, H - 56));
	for (NSUInteger i = 0; i < cats.count; i++) {
		CGRect row = CGRectMake(20, cy + i * 46, 205, 46); if ((NSInteger)i == selected) { if (glass) CCFillRRectA(c, CGRectInset(row, 0, 1), 12, 255, 0.14); else CCFillRRect(c, CGRectInset(row, 0, 1), 12, 52); }
		[catRects addObject: [NSValue valueWithBytes: &row objCType: @encode(CGRect)]];
		[self drawCatIcon: cats[i] in: CGRectMake(32, CGRectGetMidY(row) - 13, 26, 26) ctx: c];
		CCText(c, cats[i], 67, CGRectGetMidY(row) + 4.5, 13, NO, 255, 0);
	}
	CGContextRestoreGState(c);
	CCFillGrey(c, 159, 1); CCRRect(c, CGRectMake(231, 62, 5, H - 70), 2.5); CGContextFillPath(c);
	CGContextRestoreGState(c);
	return CCEndBitmap(c);
}
- (BOOL)mouseDown:(CGPoint)sp
{
	CGPoint p = CGPointMake(sp.x - kFrame.origin.x, sp.y - kFrame.origin.y);
	if (CGRectContainsPoint(doneRect, p)) { [panel setEditing: NO]; return YES; }
	for (NSUInteger i = 0; i < catRects.count; i++) { CGRect r; [catRects[i] getValue: &r]; if (CGRectContainsPoint(r, p)) {
		selected = i; query = [NSMutableString string];
		scroll = i == 0 ? 0 : (i - 1 < sectionY.count ? MAX(0, MIN([sectionY[i - 1] doubleValue] - 20, MAX(0, contentH - (kFrame.size.height - kFooterH)))) : scroll); [self redraw]; return YES; } }
	dragKind = -1; dragMoved = NO;
	if (p.x > kSidebarW && p.y < kFrame.size.height - kFooterH) {
		CGPoint q = CGPointMake(p.x, p.y + scroll);
		for (NSUInteger i = 0; i < itemRects.count; i++) { CGRect r; [itemRects[i] getValue: &r]; if (CGRectContainsPoint(r, q)) { dragKind = [itemKinds[i] intValue]; dragStart = sp; return YES; } }
	}
	return YES;
}
- (BOOL)mouseDragged:(CGPoint)sp { if (dragKind >= 0 && hypot(sp.x - dragStart.x, sp.y - dragStart.y) > 4) dragMoved = YES; return dragKind >= 0; }
- (BOOL)mouseUp:(CGPoint)sp                       /* a control dropped on the panel is placed on the cell under the pointer; a click without a drag adds it on the first free place */
{
	if (dragKind < 0) return NO; int k = dragKind; dragKind = -1;
	if (!dragMoved) { [panel addControl: k]; return YES; }
	[panel addControl: k atScreenPoint: sp]; return YES;
}
@end
