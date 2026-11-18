#import "CCPanel.h"
#import "CCSkyLight.h"
#import "../dock-cocoa/DockWindow.h"
#import "../dock-cocoa/SkyLightAPI.h"
#import <CoreText/CoreText.h>
#import <QuartzCore/QuartzCore.h>

/* window of the real panel: 800,0 656 x 964 (level 22; larger than the panel: room for the shadow, partly off screen); the panel itself x 966..1274, y 34..533 */
static const CGRect kWindow = { {800, 0}, {656, 964} };
static const CGRect kPanel = { {966, 34}, {308, 499} };
typedef struct { CGRect r; CGFloat radius; int kind; const char *title, *sub; } Tile;
enum { KWifi, KBluetooth, KAirDrop, KNowPlaying, KStage, KMirror, KAppearance, KShot, KFocus, KDisplay, KSound, KEdit };
static const Tile kTiles[] = {
	{ {974, 42, 140, 63}, 31.5, KWifi, "Wi-Fi", "Off" }, { {974, 118, 140, 63}, 31.5, KBluetooth, "Bluetooth", "Off" }, { {974, 194, 140, 63}, 31.5, KAirDrop, "AirDrop", "Off" },
	{ {1126, 42, 140, 140}, 24, KNowPlaying, "Not Playing", NULL }, { {1126, 194, 63, 63}, 31.5, KStage, NULL, NULL }, { {1203, 194, 63, 63}, 31.5, KMirror, NULL, NULL },
	{ {974, 270, 63, 63}, 31.5, KAppearance, NULL, NULL }, { {1051, 270, 63, 63}, 31.5, KShot, NULL, NULL }, { {1126, 270, 140, 63}, 31.5, KFocus, NULL, NULL },
	{ {974, 346, 292, 63}, 24, KDisplay, "Display", NULL }, { {974, 422, 292, 63}, 24, KSound, "Sound", NULL }, { {1074, 502, 93, 23}, 11.5, KEdit, "Edit Controls", NULL },
};
static CGColorRef grey(CGFloat v, CGFloat a)     /* same colour space as the bitmap (device RGB): values equal the screenshot's pixel values */
{
	static CGColorSpaceRef cs; if (!cs) cs = CGColorSpaceCreateDeviceRGB();
	CGFloat c[4] = { v / 255.0, v / 255.0, v / 255.0, a }; return CGColorCreate(cs, c);
}

static void rrect(CGContextRef c, CGRect r, CGFloat rad) { CGPathRef p = CGPathCreateWithRoundedRect(r, rad, rad, NULL); CGContextAddPath(c, p); CFRelease(p); }
static void text(CGContextRef c, NSString *s, CGFloat x, CGFloat baseline, CGFloat size, BOOL bold, CGFloat white, CGFloat align /* 0 left, 0.5 centre */)
{
	CTFontRef f = CTFontCreateUIFontForLanguage(bold ? kCTFontUIFontEmphasizedSystem : kCTFontUIFontSystem, size, NULL);
	CGColorRef col = grey(white, 1);
	NSDictionary *a = @{ (id)kCTFontAttributeName: (__bridge id)f, (id)kCTForegroundColorAttributeName: (__bridge id)col };
	CTLineRef l = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)[[NSAttributedString alloc] initWithString: s attributes: a]);
	double w = CTLineGetTypographicBounds(l, NULL, NULL, NULL);
	CGContextSaveGState(c); CGContextSetTextMatrix(c, CGAffineTransformMakeScale(1, -1)); CGContextSetTextPosition(c, x - w * align, baseline); CTLineDraw(l, c); CGContextRestoreGState(c);
	CFRelease(l); CFRelease(f); CGColorRelease(col);
}
static void glyphCircle(CGContextRef c, CGPoint ctr, CGFloat d, CGFloat v) { CGColorRef col = grey(v, 1); CGContextSetFillColorWithColor(c, col); CGColorRelease(col); CGContextFillEllipseInRect(c, CGRectMake(ctr.x - d / 2, ctr.y - d / 2, d, d)); }
static void arcs(CGContextRef c, CGPoint o, int n, CGFloat r0, CGFloat step)    /* Wi-Fi / AirDrop style arcs, centre o */
{
	for (int i = 0; i < n; i++) { CGContextAddArc(c, o.x, o.y, r0 + step * i, -M_PI * 0.78, -M_PI * 0.22, 0); CGContextStrokePath(c); }
}
static void sun(CGContextRef c, CGPoint o, CGFloat r, BOOL big)
{
	CGContextSetLineWidth(c, big ? 1.3 : 1.1); CGContextStrokeEllipseInRect(c, CGRectMake(o.x - r, o.y - r, 2 * r, 2 * r));
	for (int i = 0; i < 8; i++) { CGFloat a = i * M_PI / 4; CGContextMoveToPoint(c, o.x + cos(a) * (r + 2.5), o.y + sin(a) * (r + 2.5)); CGContextAddLineToPoint(c, o.x + cos(a) * (r + (big ? 5 : 4)), o.y + sin(a) * (r + (big ? 5 : 4))); }
	CGContextStrokePath(c);
}
static void speaker(CGContextRef c, CGPoint o, CGFloat s, int waves)
{
	CGContextMoveToPoint(c, o.x - s * 0.6, o.y - s * 0.25); CGContextAddLineToPoint(c, o.x - s * 0.25, o.y - s * 0.25); CGContextAddLineToPoint(c, o.x + s * 0.15, o.y - s * 0.65);
	CGContextAddLineToPoint(c, o.x + s * 0.15, o.y + s * 0.65); CGContextAddLineToPoint(c, o.x - s * 0.25, o.y + s * 0.25); CGContextAddLineToPoint(c, o.x - s * 0.6, o.y + s * 0.25); CGContextFillPath(c);
	for (int i = 1; i <= waves; i++) { CGContextAddArc(c, o.x + s * 0.15, o.y, s * (0.35 + 0.28 * i), -0.7, 0.7, 0); CGContextStrokePath(c); }
}

static CGImageRef renderPanel(void)
{
	size_t W = kWindow.size.width, H = kWindow.size.height;
	CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
	CGContextRef c = CGBitmapContextCreate(NULL, W, H, 8, 0, cs, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
	CGContextTranslateCTM(c, -kWindow.origin.x, H + kWindow.origin.y); CGContextScaleCTM(c, 1, -1);       /* screen coordinates, y down */
	CGColorRef col;
	col = grey(61, 1); CGContextSetFillColorWithColor(c, col); CGColorRelease(col); rrect(c, kPanel, 37); CGContextFillPath(c);
	CGContextSetLineCap(c, kCGLineCapRound);
	for (size_t i = 0; i < sizeof kTiles / sizeof *kTiles; i++) {
		const Tile *t = &kTiles[i]; CGRect r = t->r; CGPoint ctr = CGPointMake(CGRectGetMidX(r), CGRectGetMidY(r));
		BOOL white = t->kind == KAppearance;
		col = grey(white ? 255 : 111, 1); CGContextSetFillColorWithColor(c, col); CGColorRelease(col); rrect(c, r, t->radius); CGContextFillPath(c);
		col = grey(white ? 0 : 255, 1); CGContextSetStrokeColorWithColor(c, col); CGContextSetFillColorWithColor(c, col); CGColorRelease(col); CGContextSetLineWidth(c, 1.6);
		switch (t->kind) {
		case KWifi: case KBluetooth: case KAirDrop: {
			CGPoint ic = CGPointMake(r.origin.x + 31.5, ctr.y); glyphCircle(c, ic, 34, 147);
			col = grey(255, 1); CGContextSetStrokeColorWithColor(c, col); CGContextSetFillColorWithColor(c, col); CGColorRelease(col);
			if (t->kind == KBluetooth) { CGContextMoveToPoint(c, ic.x - 4.5, ic.y - 4.5); CGContextAddLineToPoint(c, ic.x + 4.5, ic.y + 4.5); CGContextAddLineToPoint(c, ic.x, ic.y + 9); CGContextAddLineToPoint(c, ic.x, ic.y - 9); CGContextAddLineToPoint(c, ic.x + 4.5, ic.y - 4.5); CGContextAddLineToPoint(c, ic.x - 4.5, ic.y + 4.5); CGContextStrokePath(c); }
			else { arcs(c, CGPointMake(ic.x, ic.y + 6), t->kind == KWifi ? 3 : 3, 5, 4.5); CGContextFillEllipseInRect(c, CGRectMake(ic.x - 1.5, ic.y + 4.5, 3, 3)); }
			CGContextMoveToPoint(c, ic.x - 9, ic.y - 8); CGContextAddLineToPoint(c, ic.x + 9, ic.y + 9); CGContextStrokePath(c);                      /* the "off" slash */
			text(c, [NSString stringWithUTF8String: t->sub], r.origin.x + 56, ctr.y + 13, 12, NO, 255, 0);     /* off: only the state, no title (real panel) */
			break; }
		case KNowPlaying: {
			col = grey(138, 1); CGContextSetFillColorWithColor(c, col); CGColorRelease(col); rrect(c, CGRectMake(r.origin.x + 14, r.origin.y + 12, 40, 40), 8); CGContextFillPath(c);
			col = grey(255, 1); CGContextSetFillColorWithColor(c, col); CGColorRelease(col);
			text(c, @"Not Playing", r.origin.x + 14, r.origin.y + 83, 13, YES, 255, 0);
			CGFloat by = r.origin.y + 111;
			CGContextMoveToPoint(c, r.origin.x + 62, by - 8); CGContextAddLineToPoint(c, r.origin.x + 62, by + 8); CGContextAddLineToPoint(c, r.origin.x + 71, by); CGContextFillPath(c);     /* play */
			CGContextMoveToPoint(c, r.origin.x + 60, by - 11); CGContextAddLineToPoint(c, r.origin.x + 60, by + 11); CGContextAddLineToPoint(c, r.origin.x + 80, by); CGContextFillPath(c);
			col = grey(160, 1); CGContextSetFillColorWithColor(c, col); CGColorRelease(col);
			for (int s = -1; s <= 1; s += 2) { CGFloat cx = s < 0 ? r.origin.x + 28 : r.origin.x + 108; for (int k = 0; k < 2; k++) { CGFloat x = cx + k * 9 * s * -1; (void)x; } }
			CGContextMoveToPoint(c, r.origin.x + 38, by - 6); CGContextAddLineToPoint(c, r.origin.x + 38, by + 6); CGContextAddLineToPoint(c, r.origin.x + 28, by); CGContextFillPath(c);
			CGContextMoveToPoint(c, r.origin.x + 48, by - 6); CGContextAddLineToPoint(c, r.origin.x + 48, by + 6); CGContextAddLineToPoint(c, r.origin.x + 38, by); CGContextFillPath(c);
			CGContextMoveToPoint(c, r.origin.x + 100, by - 6); CGContextAddLineToPoint(c, r.origin.x + 100, by + 6); CGContextAddLineToPoint(c, r.origin.x + 110, by); CGContextFillPath(c);
			CGContextMoveToPoint(c, r.origin.x + 110, by - 6); CGContextAddLineToPoint(c, r.origin.x + 110, by + 6); CGContextAddLineToPoint(c, r.origin.x + 120, by); CGContextFillPath(c);
			break; }
		case KStage: CGContextStrokeRect(c, CGRectMake(ctr.x - 2, ctr.y - 8, 15, 16)); CGContextFillRect(c, CGRectMake(ctr.x - 13, ctr.y - 8, 3, 3)); CGContextFillRect(c, CGRectMake(ctr.x - 13, ctr.y - 2, 3, 3)); CGContextFillRect(c, CGRectMake(ctr.x - 13, ctr.y + 4, 3, 3)); break;
		case KMirror: rrect(c, CGRectMake(ctr.x - 13, ctr.y - 10, 18, 14), 2.5); CGContextStrokePath(c); rrect(c, CGRectMake(ctr.x - 5, ctr.y - 4, 18, 14), 2.5); CGContextStrokePath(c); break;
		case KAppearance: CGContextFillEllipseInRect(c, CGRectMake(ctr.x - 10, ctr.y - 10, 20, 20)); col = grey(255, 1); CGContextSetFillColorWithColor(c, col); CGColorRelease(col); CGContextAddArc(c, ctr.x, ctr.y, 10, -M_PI / 2, M_PI / 2, 1); CGContextFillPath(c); break;
		case KShot: rrect(c, CGRectMake(ctr.x - 8, ctr.y - 5, 16, 11), 2); CGContextStrokePath(c); CGContextStrokeEllipseInRect(c, CGRectMake(ctr.x - 3.5, ctr.y - 3, 7, 7)); break;
		case KFocus: glyphCircle(c, CGPointMake(r.origin.x + 31.5, ctr.y), 34, 147); col = grey(255, 1); CGContextSetFillColorWithColor(c, col); CGColorRelease(col);
			CGContextAddArc(c, r.origin.x + 31.5, ctr.y, 9, 0.4, 2 * M_PI - 0.4, 0); CGContextAddArc(c, r.origin.x + 36.5, ctr.y - 3, 8, 2 * M_PI - 0.4 - 0.9, 0.4 + 0.9, 1); CGContextFillPath(c); break;
		case KDisplay: case KSound: {
			text(c, [NSString stringWithUTF8String: t->title], r.origin.x + 16, r.origin.y + (t->kind == KDisplay ? 23 : 22), 13, YES, 255, 0);
			BOOL disp = t->kind == KDisplay; CGFloat y = r.origin.y + (t->kind == KDisplay ? 43 : 42), x0 = r.origin.x + (disp ? 36 : 34), x1 = r.origin.x + (disp ? 254 : 216);
			col = grey(150, 1); CGContextSetFillColorWithColor(c, col); CGContextSetStrokeColorWithColor(c, col); CGColorRelease(col);
			rrect(c, CGRectMake(x0, y - 2, x1 - x0, 4), 2); CGContextFillPath(c);
			col = grey(205, 1); CGContextSetFillColorWithColor(c, col); CGContextSetStrokeColorWithColor(c, col); CGColorRelease(col);
			if (disp) { sun(c, CGPointMake(r.origin.x + 22, y), 2.6, NO); sun(c, CGPointMake(r.origin.x + 268, y), 3.6, YES); }
			else { speaker(c, CGPointMake(r.origin.x + 20, y), 14, 0); speaker(c, CGPointMake(r.origin.x + 231, y), 14, 2); glyphCircle(c, CGPointMake(r.origin.x + 265, y), 26, 147); col = grey(255, 1); CGContextSetStrokeColorWithColor(c, col); CGColorRelease(col); arcs(c, CGPointMake(r.origin.x + 265, y + 3), 2, 4.5, 4.5); }
			break; }
		case KEdit: text(c, @"Edit Controls", ctr.x, ctr.y + 4.5, 13, NO, 255, 0.5); break;
		}
	}
	CGImageRef img = CGBitmapContextCreateImage(c); CGContextRelease(c); CGColorSpaceRelease(cs);
	return img;
}

@implementation CCPanel
{ DockWindow *win; CALayer *layer; }
- (BOOL)visible { return win != nil; }
- (BOOL)containsScreenPoint:(CGPoint)p { return win && CGRectContainsPoint(kPanel, p); }
- (void)show
{
	const SkyLightAPI *sl = SkyLightLoad(); const CCSkyLight *cc = CCSkyLightLoad(); if (!sl) return;
	win = [[DockWindow alloc] initWithFrame: kWindow level: 22 options: 0x10000];
	if (!win) return;
	layer = [CALayer layer]; layer.frame = CGRectMake(0, 0, kWindow.size.width, kWindow.size.height);
	CGImageRef img = renderPanel(); layer.contents = (__bridge id)img; CGImageRelease(img);
	[win setRootLayer: layer];
	int cid = sl->MainConnectionID(); uint32_t wid = win.windowID;
	if (cc->SetWindowClientPerceivedType) cc->SetWindowClientPerceivedType(cid, wid, 5);
	[win orderIn];
}
- (void)hide { if (!win) return; const SkyLightAPI *sl = SkyLightLoad(); if (sl && sl->ReleaseWindow) sl->ReleaseWindow(sl->MainConnectionID(), win.windowID); win = nil; layer = nil; }
- (void)toggle { if (win) [self hide]; else [self show]; }
@end
