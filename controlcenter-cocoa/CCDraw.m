#import "CCDraw.h"
#import <CoreText/CoreText.h>
#import "CCSymbols.h"
#import <dlfcn.h>

static void *skylight(void) { static void *h; if (!h) h = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY); return h; }
/* pearOS fallback: no SLSGetAppearanceThemeLegacy; the appearance is the key AppleInterfaceStyle of ~/Library/Preferences/.GlobalPreferences.plist (as the earlier Control Center did; a missing key = dark, the image's default) */
static NSString *globalPrefs(void) { return [NSHomeDirectory() stringByAppendingPathComponent: @"Library/Preferences/.GlobalPreferences.plist"]; }
/* One answer a second at most: every request to the window server is a Mach round trip (on pearOS through the bridge, 0.1 - 0.5 s each on a slow machine) and the drawing code asks at every tile */
static BOOL darkThemeNow(void);
BOOL CCDarkTheme(void)
{
	static BOOL last; static double at; struct timespec ts; clock_gettime(CLOCK_MONOTONIC, &ts); double now = ts.tv_sec + ts.tv_nsec / 1e9;
	if (at == 0 || now - at > 1.0) { last = darkThemeNow(); at = now; }
	return last;
}
void CCDarkThemeChanged(void) { /* forces the next CCDarkTheme() to ask */ }
static BOOL darkThemeNow(void)
{
	static int (*get)(void); if (!get && skylight()) get = dlsym(skylight(), "SLSGetAppearanceThemeLegacy"); if (get) return get() != 0;
	id v = [NSDictionary dictionaryWithContentsOfFile: globalPrefs()][@"AppleInterfaceStyle"]; return !v || [v caseInsensitiveCompare: @"Dark"] == NSOrderedSame;
}
void CCSetDarkTheme(BOOL dark)
{
	static void (*set)(int); if (!set && skylight()) set = dlsym(skylight(), "SLSSetAppearanceThemeLegacy"); if (set) { set(dark ? 1 : 0); return; }
	NSMutableDictionary *p = [[NSDictionary dictionaryWithContentsOfFile: globalPrefs()] mutableCopy] ?: [NSMutableDictionary dictionary]; p[@"AppleInterfaceStyle"] = dark ? @"Dark" : @"Light";
	[[NSFileManager defaultManager] createDirectoryAtPath: [globalPrefs() stringByDeletingLastPathComponent] withIntermediateDirectories: YES attributes: nil error: NULL]; [p writeToFile: globalPrefs() atomically: YES];
}

static CGColorSpaceRef rgb(void) { static CGColorSpaceRef cs; if (!cs) cs = CGColorSpaceCreateDeviceRGB(); return cs; }
CGContextRef CCBeginBitmap(CGSize size, CGPoint origin)
{
	CGContextRef c = CGBitmapContextCreate(NULL, size.width, size.height, 8, 0, rgb(), kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
	CGContextTranslateCTM(c, -origin.x, size.height + origin.y); CGContextScaleCTM(c, 1, -1); CGContextSetLineCap(c, kCGLineCapRound); CGContextSetLineJoin(c, kCGLineJoinRound);
	return c;
}
CGImageRef CCEndBitmap(CGContextRef c) { CGImageRef i = CGBitmapContextCreateImage(c); CGContextRelease(c); return i; }
static CGFloat sInk = 255, sInkA = 1, sInkR, sInkG, sInkB; static BOOL sInkRGB;
static BOOL sDarkInk;            /* the light appearance over glass: white ink becomes dark, as the labels of the real panel (vibrancy) */
void CCSetDarkInk(BOOL on) { sDarkInk = on; }
static CGFloat inkOf(CGFloat v) { return sDarkInk && v >= 200 ? 28 : v; }            /* the last colour set: SF symbols are drawn tinted with it */
void CCFillGrey(CGContextRef c, CGFloat v, CGFloat a)
{
	sInk = v; sInkA = a; sInkRGB = NO;
	CGFloat k[4] = { v / 255, v / 255, v / 255, a }; CGColorRef col = CGColorCreate(rgb(), k);
	CGContextSetFillColorWithColor(c, col); CGContextSetStrokeColorWithColor(c, col); CGColorRelease(col);
}
void CCFillRGB(CGContextRef c, int r, int g, int b)
{
	sInk = (r + g + b) / 3.0; sInkA = 1; sInkR = r; sInkG = g; sInkB = b; sInkRGB = YES;
	CGFloat k[4] = { r / 255.0, g / 255.0, b / 255.0, 1 }; CGColorRef col = CGColorCreate(rgb(), k);
	CGContextSetFillColorWithColor(c, col); CGContextSetStrokeColorWithColor(c, col); CGColorRelease(col);
}
void CCRRect(CGContextRef c, CGRect r, CGFloat radius) { CGFloat m = MIN(r.size.width, r.size.height) / 2; if (radius > m) radius = m; CGPathRef p = CGPathCreateWithRoundedRect(r, radius, radius, NULL); CGContextAddPath(c, p); CFRelease(p); }
void CCFillRRect(CGContextRef c, CGRect r, CGFloat radius, CGFloat grey) { CCFillGrey(c, grey, 1); CCRRect(c, r, radius); CGContextFillPath(c); }
void CCFillDisc(CGContextRef c, CGPoint ctr, CGFloat d, CGFloat grey) { CCFillGrey(c, grey, 1); CGContextFillEllipseInRect(c, CGRectMake(ctr.x - d / 2, ctr.y - d / 2, d, d)); }
static CTLineRef line(NSString *s, CGFloat size, BOOL bold, CGFloat grey)
{
	CTFontRef f = CTFontCreateUIFontForLanguage(bold ? kCTFontUIFontEmphasizedSystem : kCTFontUIFontSystem, size, NULL);
	CGFloat k[4] = { grey / 255, grey / 255, grey / 255, 1 }; CGColorRef col = CGColorCreate(rgb(), k);
	NSDictionary *a = @{ (id)kCTFontAttributeName: (__bridge id)f, (id)kCTForegroundColorAttributeName: (__bridge id)col };
	CTLineRef l = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)[[NSAttributedString alloc] initWithString: s ?: @"" attributes: a]);
	CFRelease(f); CGColorRelease(col); return l;
}
double CCTextWidth(NSString *s, CGFloat size, BOOL bold) { CTLineRef l = line(s, size, bold, 0); double w = CTLineGetTypographicBounds(l, NULL, NULL, NULL); CFRelease(l); return w; }
void CCText(CGContextRef c, NSString *s, CGFloat x, CGFloat baseline, CGFloat size, BOOL bold, CGFloat grey, CGFloat align)
{
	CTLineRef l = line(s, size, bold, inkOf(grey)); double w = CTLineGetTypographicBounds(l, NULL, NULL, NULL);
	CGContextSaveGState(c); CGContextSetTextMatrix(c, CGAffineTransformMakeScale(1, -1)); CGContextSetTextPosition(c, x - w * align, baseline); CTLineDraw(l, c); CGContextRestoreGState(c); CFRelease(l);
}

/* ---- glyphs: simple vector drawings, 1.6 pt strokes, centred; unit = size / 24 ---- */
static void arcs(CGContextRef c, CGPoint o, int n, CGFloat r0, CGFloat step, CGFloat a0, CGFloat a1) { for (int i = 0; i < n; i++) { CGContextAddArc(c, o.x, o.y, r0 + step * i, a0, a1, 0); CGContextStrokePath(c); } }
static void tri(CGContextRef c, CGPoint a, CGPoint b, CGPoint d) { CGContextMoveToPoint(c, a.x, a.y); CGContextAddLineToPoint(c, b.x, b.y); CGContextAddLineToPoint(c, d.x, d.y); CGContextFillPath(c); }
/* our glyph names -> SF Symbols (public: CoreGlyphs, private: CoreGlyphsPrivate); a glyph with no entry, or a Mac without the catalogs, is drawn with the vector code below */
static NSString *symbolFor(NSString *n)
{
	static NSDictionary *m; if (!m) m = @{ @"wifi": @"wifi", @"wifi.slash": @"wifi.slash", @"bluetooth": @"bluetooth", @"bluetooth.slash": @"bluetooth.slash", @"wifi.slash": @"wifi.slash", @"moon": @"moon.fill", @"mirror": @"rectangle.on.rectangle",
		@"camera": @"camera.viewfinder", @"play": @"play.fill", @"pause": @"pause.fill", @"forward": @"forward.fill", @"rewind": @"backward.fill", @"sun.min": @"sun.min", @"sun.max": @"sun.max", @"speaker": @"speaker.fill",
		@"speaker.wave": @"speaker.wave.3.fill", @"airplay": @"airplay.audio", @"dark": @"circle.lefthalf.filled", @"alarm": @"alarm", @"stopwatch": @"stopwatch", @"timer": @"timer", @"clock": @"clock", @"lightbulb": @"lightbulb.fill",
		@"waveform": @"waveform", @"note": @"note.text", @"shazam": @"shazam.logo.fill", @"screensaver": @"play.display", @"shortcut": @"square.2.layers.3d", @"tile": @"rectangle.lefthalf.inset.filled", @"person": @"person.crop.circle",
		@"lock": @"lock.fill", @"keyboard": @"keyboard", @"battery": @"battery.100", @"plus": @"plus", @"zoom": @"plus.magnifyingglass", @"truetone": @"truetone", @"nightshift": @"nightshift", @"display": @"display", @"resize": @"arrow.up.left.and.arrow.down.right", @"minus": @"minus", @"magnifier": @"magnifyingglass" };
	return m[n];
}
void CCGlyph(CGContextRef c, NSString *n, CGPoint o, CGFloat size)
{
	if (!getenv("CC_NO_SYMBOLS")) { NSString *s = symbolFor(n) ?: ([n rangeOfString: @"."].location != NSNotFound ? n : nil); CGImageRef img = s ? (sInkRGB ? CCSymbolImageRGB(s, size * 0.85, sInkR, sInkG, sInkB, sInkA) : CCSymbolImage(s, size * 0.85, inkOf(sInk), sInkA)) : NULL;
		if (img) { CGFloat w = CGImageGetWidth(img) / 2.0, h = CGImageGetHeight(img) / 2.0; CGContextSaveGState(c); CGContextTranslateCTM(c, o.x, o.y); CGContextScaleCTM(c, 1, -1); CGContextDrawImage(c, CGRectMake(-w / 2, -h / 2, w, h), img); CGContextRestoreGState(c); return; } }
	CGFloat u = size / 24.0; CGContextSaveGState(c); CGContextTranslateCTM(c, o.x, o.y); CGContextScaleCTM(c, u, u); CGContextSetLineWidth(c, 1.7);
	if ([n hasPrefix: @"wifi"] || [n isEqual: @"airdrop"]) {
		arcs(c, CGPointMake(0, 6), 3, 5.5, 5, -M_PI * 0.80, -M_PI * 0.20); CGContextFillEllipseInRect(c, CGRectMake(-1.8, 4.4, 3.6, 3.6));
		if ([n hasSuffix: @".slash"] || [n isEqual: @"airdrop"]) { CGContextMoveToPoint(c, -10, -9); CGContextAddLineToPoint(c, 10, 10); CGContextStrokePath(c); }
	} else if ([n hasPrefix: @"bluetooth"]) {
		CGContextMoveToPoint(c, -5, -5); CGContextAddLineToPoint(c, 5, 5); CGContextAddLineToPoint(c, 0, 10); CGContextAddLineToPoint(c, 0, -10); CGContextAddLineToPoint(c, 5, -5); CGContextAddLineToPoint(c, -5, 5); CGContextStrokePath(c);
		if ([n hasSuffix: @".slash"]) { CGContextMoveToPoint(c, -9, -9); CGContextAddLineToPoint(c, 9, 10); CGContextStrokePath(c); }
	} else if ([n isEqual: @"moon"]) {
		CGContextAddArc(c, 0, 0, 10, 0.45, 2 * M_PI - 0.45, 0); CGContextAddArc(c, 5, -4, 9, 2 * M_PI - 0.45 - 0.8, 0.45 + 0.8, 1); CGContextFillPath(c);
	} else if ([n isEqual: @"stage"]) {
		CGContextStrokeRect(c, CGRectMake(-2, -9, 15, 18)); for (int i = 0; i < 3; i++) CGContextFillRect(c, CGRectMake(-13, -9 + i * 7, 3.4, 3.4));
	} else if ([n isEqual: @"mirror"]) {
		CCRRect(c, CGRectMake(-13, -11, 19, 15), 3); CGContextStrokePath(c); CCRRect(c, CGRectMake(-5, -4, 19, 15), 3); CGContextStrokePath(c);
	} else if ([n isEqual: @"camera"]) {
		CCRRect(c, CGRectMake(-9, -6, 18, 13), 2.5); CGContextStrokePath(c); CGContextStrokeEllipseInRect(c, CGRectMake(-4, -3, 8, 8));
	} else if ([n isEqual: @"play"]) { tri(c, CGPointMake(-7, -10), CGPointMake(-7, 10), CGPointMake(10, 0));
	} else if ([n isEqual: @"pause"]) { CGContextFillRect(c, CGRectMake(-7, -9, 5, 18)); CGContextFillRect(c, CGRectMake(2, -9, 5, 18));
	} else if ([n isEqual: @"forward"]) { tri(c, CGPointMake(-11, -7), CGPointMake(-11, 7), CGPointMake(-1, 0)); tri(c, CGPointMake(-1, -7), CGPointMake(-1, 7), CGPointMake(9, 0));
	} else if ([n isEqual: @"rewind"]) { tri(c, CGPointMake(11, -7), CGPointMake(11, 7), CGPointMake(1, 0)); tri(c, CGPointMake(1, -7), CGPointMake(1, 7), CGPointMake(-9, 0));
	} else if ([n isEqual: @"sun.min"] || [n isEqual: @"sun.max"]) {
		CGFloat r = [n isEqual: @"sun.min"] ? 4 : 5.5; CGContextSetLineWidth(c, 1.4); CGContextStrokeEllipseInRect(c, CGRectMake(-r, -r, 2 * r, 2 * r));
		for (int i = 0; i < 8; i++) { CGFloat a = i * M_PI / 4; CGContextMoveToPoint(c, cos(a) * (r + 3), sin(a) * (r + 3)); CGContextAddLineToPoint(c, cos(a) * (r + 6), sin(a) * (r + 6)); } CGContextStrokePath(c);
	} else if ([n hasPrefix: @"speaker"]) {
		CGContextMoveToPoint(c, -9, -4); CGContextAddLineToPoint(c, -4, -4); CGContextAddLineToPoint(c, 2, -9); CGContextAddLineToPoint(c, 2, 9); CGContextAddLineToPoint(c, -4, 4); CGContextAddLineToPoint(c, -9, 4); CGContextFillPath(c);
		int w = [n isEqual: @"speaker.wave"] ? 2 : 0; for (int i = 1; i <= w; i++) { CGContextAddArc(c, 2, 0, 3 + 4 * i, -0.7, 0.7, 0); CGContextStrokePath(c); }
	} else if ([n isEqual: @"airplay"]) { arcs(c, CGPointMake(0, 2), 3, 4, 4.2, -M_PI * 0.9, -M_PI * 0.1); tri(c, CGPointMake(-5, 11), CGPointMake(5, 11), CGPointMake(0, 4));
	} else if ([n isEqual: @"dark"]) { CGContextFillEllipseInRect(c, CGRectMake(-10, -10, 20, 20));
	} else if ([n isEqual: @"alarm"] || [n isEqual: @"stopwatch"] || [n isEqual: @"clock"] || [n isEqual: @"timer"]) {
		CGContextStrokeEllipseInRect(c, CGRectMake(-9, -8, 18, 18)); CGContextMoveToPoint(c, 0, 1); CGContextAddLineToPoint(c, 0, -5); CGContextMoveToPoint(c, 0, 1); CGContextAddLineToPoint(c, 4, 3); CGContextStrokePath(c);
		if ([n isEqual: @"stopwatch"]) { CGContextMoveToPoint(c, -2.5, -11.5); CGContextAddLineToPoint(c, 2.5, -11.5); CGContextStrokePath(c); }
		if ([n isEqual: @"alarm"]) { CGContextMoveToPoint(c, -11, -7); CGContextAddLineToPoint(c, -8, -10); CGContextMoveToPoint(c, 11, -7); CGContextAddLineToPoint(c, 8, -10); CGContextStrokePath(c); }
	} else if ([n isEqual: @"lightbulb"]) { CGContextStrokeEllipseInRect(c, CGRectMake(-7, -11, 14, 14)); CGContextMoveToPoint(c, -3, 6); CGContextAddLineToPoint(c, 3, 6); CGContextMoveToPoint(c, -2, 9); CGContextAddLineToPoint(c, 2, 9); CGContextStrokePath(c);
	} else if ([n isEqual: @"waveform"]) { for (int i = -3; i <= 3; i++) { CGFloat h = 3 + (4 - abs(i)) * 2.2; CGContextMoveToPoint(c, i * 3.4, -h); CGContextAddLineToPoint(c, i * 3.4, h); } CGContextStrokePath(c);
	} else if ([n isEqual: @"note"]) { CCRRect(c, CGRectMake(-9, -9, 18, 18), 3.5); CGContextStrokePath(c); CGContextMoveToPoint(c, -5, 4); CGContextAddCurveToPoint(c, -3, -4, 0, 6, 5, -3); CGContextStrokePath(c);
	} else if ([n isEqual: @"shazam"]) { CGContextStrokeEllipseInRect(c, CGRectMake(-9, -9, 18, 18)); CGContextMoveToPoint(c, 3, -5); CGContextAddCurveToPoint(c, -6, -4, -3, 0, 0, 0); CGContextAddCurveToPoint(c, 3, 0, 6, 4, -3, 5); CGContextStrokePath(c);
	} else if ([n isEqual: @"screensaver"]) { CCRRect(c, CGRectMake(-10, -8, 20, 15), 2.5); CGContextStrokePath(c); CGContextFillEllipseInRect(c, CGRectMake(-5, -3, 3, 3));
	} else if ([n isEqual: @"shortcut"]) { CCRRect(c, CGRectMake(-9, -3, 14, 9), 3); CGContextStrokePath(c); CCRRect(c, CGRectMake(-5, -9, 14, 9), 3); CGContextStrokePath(c);
	} else if ([n isEqual: @"tile"]) { CCRRect(c, CGRectMake(-11, -8, 22, 16), 2.5); CGContextStrokePath(c); CGContextFillRect(c, CGRectMake(-9, -6, 8, 12));
	} else if ([n isEqual: @"person"]) { CGContextStrokeEllipseInRect(c, CGRectMake(-4, -9, 8, 8)); CGContextAddArc(c, 0, 11, 8, M_PI, 0, 0); CGContextStrokePath(c);
	} else if ([n isEqual: @"lock"]) { CCRRect(c, CGRectMake(-7, -2, 14, 11), 2.5); CGContextFillPath(c); CGContextAddArc(c, 0, -3, 4.5, M_PI, 0, 0); CGContextStrokePath(c);
	} else if ([n isEqual: @"keyboard"]) { CCRRect(c, CGRectMake(-11, -6, 22, 12), 2.5); CGContextStrokePath(c); CGContextFillRect(c, CGRectMake(-6, 1, 12, 2));
	} else if ([n isEqual: @"battery"]) { CCRRect(c, CGRectMake(-11, -5, 21, 10), 2.5); CGContextStrokePath(c); CGContextFillRect(c, CGRectMake(-9, -3, 12, 6));
	} else if ([n isEqual: @"plus"]) { CGContextMoveToPoint(c, -6, 0); CGContextAddLineToPoint(c, 6, 0); CGContextMoveToPoint(c, 0, -6); CGContextAddLineToPoint(c, 0, 6); CGContextStrokePath(c);
	} else if ([n isEqual: @"minus"]) { CGContextMoveToPoint(c, -6, 0); CGContextAddLineToPoint(c, 6, 0); CGContextStrokePath(c);
	} else if ([n isEqual: @"magnifier"]) { CGContextStrokeEllipseInRect(c, CGRectMake(-9, -9, 14, 14)); CGContextMoveToPoint(c, 3, 3); CGContextAddLineToPoint(c, 9, 9); CGContextStrokePath(c);
	} else { CGContextFillEllipseInRect(c, CGRectMake(-5, -5, 10, 10)); }
	CGContextRestoreGState(c);
}

void CCSetBandedContents(CALayer *layer, CGImageRef img, int bh) { CCSetBandedContentsFade(layer, img, bh, NO); }
void CCSetBandedContentsFade(CALayer *layer, CGImageRef img, int bh, BOOL fade)
{
	size_t w = CGImageGetWidth(img), h = CGImageGetHeight(img); NSUInteger n = (h + bh - 1) / bh;
	NSArray *old = [layer.sublayers copy]; BOOL reuse = old.count == n;
	if (!reuse) { for (CALayer *l in old) [l removeFromSuperlayer]; }
	layer.contents = nil;
	for (NSUInteger i = 0; i < n; i++) {
		size_t y0 = i * bh, rows = MIN((size_t)bh, h - y0); CGImageRef band = CGImageCreateWithImageInRect(img, CGRectMake(0, y0, w, rows)); if (!band) continue;
		CALayer *l = reuse ? old[i] : [CALayer layer];
		if (!reuse) { l.frame = CGRectMake(0, h - y0 - rows, w, rows); l.contentsGravity = kCAGravityResize; [layer addSublayer: l]; }
		if (fade && reuse) { CATransition *t = [CATransition animation]; t.type = kCATransitionFade; t.duration = 0.15; t.timingFunction = [CAMediaTimingFunction functionWithName: kCAMediaTimingFunctionEaseInEaseOut]; [l addAnimation: t forKey: @"contents-fade"]; }
		l.contents = (__bridge id)band; CGImageRelease(band);
	}
}

CASpringAnimation *CCSwiftUISpring(NSString *keyPath, double response, double zeta)
{
	CASpringAnimation *a = [CASpringAnimation animationWithKeyPath: keyPath]; double k = pow(2 * M_PI / response, 2);
	a.mass = 1; a.stiffness = k; a.damping = 2 * zeta * sqrt(k); a.initialVelocity = 0; a.duration = a.settlingDuration; return a;
}

CASpringAnimation *CCRawSpring(NSString *keyPath, double mass, double stiffness, double damping)
{
	CASpringAnimation *a = [CASpringAnimation animationWithKeyPath: keyPath]; a.mass = mass; a.stiffness = stiffness; a.damping = damping; a.initialVelocity = 0; a.duration = a.settlingDuration; return a;
}

CGFloat CCDX(void)
{
	static CGFloat dx = -1; if (dx >= 0) return dx;
	if (getenv("CC_DX")) return dx = atof(getenv("CC_DX"));
	CGRect b = CGDisplayBounds(CGMainDisplayID()); dx = b.size.width > 1280 ? b.size.width - 1280 : 0; return dx;
}

BOOL CCGlassMode(void) { static int g = -1; if (g < 0) g = getenv("CC_GLASS") && !strcmp(getenv("CC_GLASS"), "0") ? 0 : 1; return g; }
void CCFillRRectA(CGContextRef c, CGRect r, CGFloat radius, CGFloat grey, CGFloat alpha) { CCFillGrey(c, grey, alpha); CCRRect(c, r, radius); CGContextFillPath(c); }
