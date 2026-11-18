#import "CCGallery.h"
#import "CCPanel.h"
#import "CCDraw.h"
#import "CCSkyLight.h"
#import "../dock-cocoa/DockWindow.h"
#import "../dock-cocoa/SkyLightAPI.h"
#import <QuartzCore/QuartzCore.h>

static const CGRect kFrame = { {226, 45}, {736, 670} };
static const int kSidebarW = 247, kFooterH = 55;
static const int kIconRGB[16][3] = { {255,255,255}, {255,255,255}, {40,40,40}, {10,132,255}, {255,255,255}, {94,92,230}, {255,255,255}, {255,255,255}, {255,159,10}, {120,60,200}, {255,255,255}, {255,214,10}, {255,255,255}, {30,30,30}, {150,150,150}, {50,200,90} };
typedef struct { CGRect r; int idx; } Hit;

@implementation CCGallery
{
	CCPanel *panel; DockWindow *win; CALayer *layer; NSMutableArray<NSValue *> *itemRects; NSMutableArray<NSNumber *> *itemKinds; NSMutableArray<NSValue *> *catRects; NSInteger selected; double scroll, contentH; NSMutableString *query; CGRect doneRect;
}
- (instancetype)initWithPanel:(CCPanel *)p
{
	if (!(self = [super init])) return nil;
	panel = p; query = [NSMutableString string]; itemRects = [NSMutableArray array]; itemKinds = [NSMutableArray array]; catRects = [NSMutableArray array];
	const SkyLightAPI *sl = SkyLightLoad(); const CCSkyLight *cc = CCSkyLightLoad(); if (!sl) return self;
	win = [[DockWindow alloc] initWithFrame: kFrame level: 23 options: 0x10000]; if (!win) return self;
	layer = [CALayer layer]; layer.frame = CGRectMake(0, 0, kFrame.size.width, kFrame.size.height);
	CGImageRef img = [self newImage]; layer.contents = (__bridge id)img; CGImageRelease(img);
	[win setRootLayer: layer];
	if (cc->SetWindowClientPerceivedType) cc->SetWindowClientPerceivedType(sl->MainConnectionID(), win.windowID, 5);
	[win orderIn];
	return self;
}
- (void)close { if (!win) return; const SkyLightAPI *sl = SkyLightLoad(); if (sl && sl->ReleaseWindow) sl->ReleaseWindow(sl->MainConnectionID(), win.windowID); win = nil; layer = nil; }
- (BOOL)containsScreenPoint:(CGPoint)p { return win && CGRectContainsPoint(kFrame, p); }
- (void)redraw { if (!win) return; CGImageRef img = [self newImage]; layer.contents = (__bridge id)img; CGImageRelease(img); [CATransaction flush]; }
- (void)scrollBy:(double)dy { scroll = MAX(0, MIN(MAX(0, contentH - (kFrame.size.height - kFooterH - 20)), scroll - dy)); [self redraw]; }
- (void)typeText:(NSString *)s { if ([s isEqual: @"\b"]) { if (query.length) [query deleteCharactersInRange: NSMakeRange(query.length - 1, 1)]; } else [query appendString: s]; scroll = 0; [self redraw]; }

- (void)drawItem:(const CCCatalogEntry *)e at:(CGPoint)o in:(CGContextRef)c
{
	CGFloat w = e->w == 1 ? 64 : 140, h = e->h == 1 ? 64 : 140; CGRect r = CGRectMake(o.x, o.y, w, h);
	CCFillRRect(c, r, (e->h == 1) ? 32 : 24, 111); CCFillGrey(c, 255, 1); CGContextSetLineWidth(c, 1.6);
	NSString *g = [NSString stringWithUTF8String: e->glyph];
	if (e->w == 1 && e->h == 1) CCGlyph(c, g, CGPointMake(CGRectGetMidX(r), CGRectGetMidY(r)), 22);
	else if (e->h == 2) { CCGlyph(c, g, CGPointMake(r.origin.x + 26, r.origin.y + 28), 24); if (e->kind != CCScene) CCText(c, [NSString stringWithUTF8String: e->title], r.origin.x + 14, r.origin.y + h - 14, 13, YES, 255, 0); else { CCFillGrey(c, 255, 1); CGContextFillRect(c, CGRectMake(r.origin.x + 14, r.origin.y + h - 36, 34, 4)); CGContextFillRect(c, CGRectMake(r.origin.x + 14, r.origin.y + h - 26, 52, 4)); } }
	else { CCFillDisc(c, CGPointMake(r.origin.x + 32, CGRectGetMidY(r)), 34, 147); CCFillGrey(c, 255, 1); CCGlyph(c, g, CGPointMake(r.origin.x + 32, CGRectGetMidY(r)), 20); CCText(c, e->kind == CCTileWindows ? @"Left & Right" : [NSString stringWithUTF8String: e->title], r.origin.x + 56, CGRectGetMidY(r) + 4.5, 13, YES, 255, 0); }
	NSString *t = [NSString stringWithUTF8String: e->title]; if (e->kind == CCTileWindows) t = @"Tile Windows Left\n& Right";
	NSArray *lines = [t componentsSeparatedByString: @"\n"]; if (lines.count == 1 && CCTextWidth(t, 12, NO) > w + 20) { NSRange sp = [t rangeOfString: @" " options: NSBackwardsSearch]; if (sp.location != NSNotFound) lines = @[ [t substringToIndex: sp.location], [t substringFromIndex: sp.location + 1] ]; }
	for (NSUInteger i = 0; i < lines.count; i++) CCText(c, lines[i], CGRectGetMidX(r), r.origin.y + h + 16 + i * 14, 12, NO, 235, 0.5);
}
/* lays out a list of entries in a 6-column grid (tile 64, pitch 76; rows 88 tall); returns the height used */
- (CGFloat)layoutEntries:(NSArray<NSValue *> *)list atY:(CGFloat)y in:(CGContextRef)c hits:(BOOL)hits
{
	BOOL occ[40][6] = { { 0 } }; CGFloat bottom = y;
	for (NSValue *v in list) {
		const CCCatalogEntry *e = [v pointerValue]; int cw = e->w == 1 ? 1 : 2, ch = e->h; BOOL placed = NO;
		for (int r = 0; r < 38 && !placed; r++) for (int cl = 0; cl + cw <= 6 && !placed; cl++) {
			BOOL free = YES; for (int a = 0; a < cw; a++) for (int b = 0; b < ch; b++) if (occ[r + b][cl + a]) free = NO;
			if (!free) continue;
			for (int a = 0; a < cw; a++) for (int b = 0; b < ch; b++) occ[r + b][cl + a] = YES;
			CGPoint o = CGPointMake(kSidebarW + 21 + cl * 76, y + r * 88); [self drawItem: e at: o in: c];
			CGRect rr = CGRectMake(o.x, o.y, e->w == 1 ? 64 : 140, e->h == 1 ? 64 : 140); bottom = MAX(bottom, rr.origin.y + rr.size.height + 34);
			if (hits) { [itemRects addObject: [NSValue valueWithBytes: &rr objCType: @encode(CGRect)]]; [itemKinds addObject: @(e->kind)]; }
			placed = YES;
		}
	}
	return bottom - y;
}
- (CGImageRef)newImage
{
	CGContextRef c = CCBeginBitmap(kFrame.size, CGPointMake(0, 0));
	CCFillRRect(c, CGRectMake(0, 0, kFrame.size.width, kFrame.size.height), 26, 84);
	/* sidebar */
	CGContextSaveGState(c); CCRRect(c, CGRectMake(0, 0, kFrame.size.width, kFrame.size.height), 26); CGContextClip(c);
	CCFillGrey(c, 75, 1); CGContextFillRect(c, CGRectMake(0, 0, kSidebarW, kFrame.size.height));
	[itemRects removeAllObjects]; [itemKinds removeAllObjects]; [catRects removeAllObjects];
	/* content, clipped (scrolls) */
	CGContextSaveGState(c); CGContextClipToRect(c, CGRectMake(kSidebarW, 0, kFrame.size.width - kSidebarW, kFrame.size.height - kFooterH));
	CGContextTranslateCTM(c, 0, -scroll);
	CGFloat y = 20; size_t n; const CCCatalogEntry *cat = CCCatalog(&n); NSString *cn = CCCategories()[selected];
	NSMutableArray *list = [NSMutableArray array];
	for (size_t i = 0; i < n; i++) { NSString *title = [NSString stringWithUTF8String: cat[i].title]; if (query.length && [title rangeOfString: query options: NSCaseInsensitiveSearch].location == NSNotFound) continue; if (selected == 0 || [cn isEqual: [NSString stringWithUTF8String: cat[i].category]]) [list addObject: [NSValue valueWithPointer: &cat[i]]]; }
	if (selected == 0 && !query.length) {
		CCFillRRect(c, CGRectMake(kSidebarW + 15, y, 456, 169), 10, 128); CCText(c, @"What's New", kSidebarW + 35, y + 40, 14, YES, 255, 0);
		NSArray *ln = @[ @"Control Center is more flexible", @"than ever — resize and rearrange", @"items to customize and access", @"what matters most to you. Your", @"favorite controls can also be added", @"to the menu bar." ]; for (NSUInteger i = 0; i < ln.count; i++) CCText(c, ln[i], kSidebarW + 35, y + 61 + i * 15, 12, NO, 255, 0);
		CCFillRRect(c, CGRectMake(kSidebarW + 272, y + 20, 200, 130), 6, 150);
		y += 189; CCText(c, @"Suggestions", kSidebarW + 15, y + 6, 12, YES, 190, 0); y += 26;
		NSArray *sugg = @[ @(CCScene), @(CCAlarm), @(CCStopwatch), @(CCTileWindows), @(CCRunShortcut), @(CCScreenSaver), @(CCVoiceMemo), @(CCQuickNote), @(CCRecognizeMusic) ]; NSMutableArray *sl = [NSMutableArray array]; for (NSNumber *k in sugg) [sl addObject: [NSValue valueWithPointer: CCCatalogFor(k.intValue)]];
		y += [self layoutEntries: sl atY: y in: c hits: YES] + 12;
		for (NSString *sec in CCCategories()) {
			NSMutableArray *items = [NSMutableArray array]; for (size_t i = 0; i < n; i++) if ([sec isEqual: [NSString stringWithUTF8String: cat[i].category]]) [items addObject: [NSValue valueWithPointer: &cat[i]]];
			if (!items.count) continue;
			CCFillGrey(c, 130, 1); CGContextFillRect(c, CGRectMake(kSidebarW + 15, y, 456, 1)); CCText(c, sec, kSidebarW + 15, y + 20, 12, YES, 190, 0); y += 40; y += [self layoutEntries: items atY: y in: c hits: YES] + 6;
		}
	} else {
		if (!list.count) CCText(c, @"No Results", kSidebarW + 245, 200, 14, NO, 190, 0.5);
		y += [self layoutEntries: list atY: y in: c hits: YES];
	}
	contentH = y + 20; CGContextRestoreGState(c);
	/* footer */
	CCFillGrey(c, 75, 1); CGContextFillRect(c, CGRectMake(kSidebarW, kFrame.size.height - kFooterH, kFrame.size.width - kSidebarW, kFooterH)); CCFillGrey(c, 130, 1); CGContextFillRect(c, CGRectMake(kSidebarW, kFrame.size.height - kFooterH, kFrame.size.width - kSidebarW, 1));
	CCText(c, @"Drag a control to place it in Control Center or Menu Bar…", kSidebarW + 17, kFrame.size.height - 24, 12.5, NO, 255, 0);
	doneRect = CGRectMake(kFrame.size.width - 80, kFrame.size.height - 42, 60, 28); CCFillRGB(c, 10, 132, 255); CCRRect(c, doneRect, 14); CGContextFillPath(c); CCFillGrey(c, 255, 1); CCText(c, @"Done", CGRectGetMidX(doneRect), CGRectGetMidY(doneRect) + 4.5, 13, YES, 255, 0.5);
	/* sidebar: search field and categories */
	CCFillRRect(c, CGRectMake(19, 19, 207, 32), 10, 30); CGContextSetLineWidth(c, 2); CCFillRGB(c, 10, 132, 255); CCRRect(c, CGRectMake(19, 19, 207, 32), 10); CGContextStrokePath(c); CCFillGrey(c, 170, 1); CCGlyph(c, @"magnifier", CGPointMake(34, 35), 15);
	CCText(c, query.length ? query : @"Search Controls", 50, 40, 13, NO, query.length ? 255 : 160, 0);
	NSArray *cats = CCCategories(); CGFloat cy = 58;
	for (NSUInteger i = 0; i < cats.count; i++) {
		CGRect row = CGRectMake(20, cy + i * 46, 205, 46); if (i == selected) CCFillRRect(c, CGRectInset(row, 0, 1), 12, 117);
		[catRects addObject: [NSValue valueWithBytes: &row objCType: @encode(CGRect)]];
		CGRect ic = CGRectMake(32, CGRectGetMidY(row) - 13, 26, 26); const int *rgb = kIconRGB[i % 16]; CCFillRGB(c, rgb[0], rgb[1], rgb[2]); CCRRect(c, ic, 6); CGContextFillPath(c);
		CCFillGrey(c, i % 2 ? 40 : 230, 1); if (i == 0) { for (int a = 0; a < 2; a++) for (int b = 0; b < 2; b++) CCFillDisc(c, CGPointMake(33 + 6 + a * 9, CGRectGetMidY(row) - 4.5 + b * 9), 7, 255); }
		CCText(c, cats[i], 70, CGRectGetMidY(row) + 4.5, 13, NO, 255, 0);
	}
	CGContextRestoreGState(c);
	return CCEndBitmap(c);
}
- (BOOL)mouseDown:(CGPoint)sp
{
	CGPoint p = CGPointMake(sp.x - kFrame.origin.x, sp.y - kFrame.origin.y);
	if (CGRectContainsPoint(doneRect, p)) { [panel setEditing: NO]; return YES; }
	for (NSUInteger i = 0; i < catRects.count; i++) { CGRect r; [catRects[i] getValue: &r]; if (CGRectContainsPoint(r, p)) { selected = i; scroll = 0; [self redraw]; return YES; } }
	if (p.x > kSidebarW && p.y < kFrame.size.height - kFooterH) {
		CGPoint q = CGPointMake(p.x, p.y + scroll);
		for (NSUInteger i = 0; i < itemRects.count; i++) { CGRect r; [itemRects[i] getValue: &r]; if (CGRectContainsPoint(r, q)) { [panel addControl: [itemKinds[i] intValue]]; return YES; } }
	}
	return YES;
}
@end
