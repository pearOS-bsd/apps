#import "CCStatusBar.h"
#import "CCSkyLight.h"
#import "../dock-cocoa/DockWindow.h"
#import "../dock-cocoa/SkyLightAPI.h"
#import <CoreText/CoreText.h>
#import <QuartzCore/QuartzCore.h>

enum { ItemSpotlight, ItemControl, ItemClock };
/* geometry of the real items on the 1280 x 800 Mac VM (CGWindowList): x, width; height 30 = the menu bar */
static const CGRect kFrames[3] = { {1063, 0, 31, 30}, {1094, 0, 42, 30}, {1136, 0, 144, 30} };
static const uint32_t kKeys[3] = { 0x7fffffd0, 0x7fffffe1, 0x7ffffff5 };       /* clock and Control Center: real values; Spotlight's guessed */

static CGImageRef render(int item, CGSize s)
{
	CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
	CGContextRef c = CGBitmapContextCreate(NULL, s.width, s.height, 8, 0, cs, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
	CGContextSetRGBFillColor(c, 1, 1, 1, 1); CGContextSetRGBStrokeColor(c, 1, 1, 1, 1);
	CGFloat cx = s.width / 2, cy = s.height / 2;
	if (item == ItemSpotlight) {                           /* magnifier */
		CGContextSetLineWidth(c, 1.6);
		CGContextStrokeEllipseInRect(c, CGRectMake(cx - 6.5, cy - 4, 9, 9));
		CGContextMoveToPoint(c, cx + 1.6, cy - 5.2); CGContextAddLineToPoint(c, cx + 6.2, cy - 9.2); CGContextStrokePath(c);
	} else if (item == ItemControl) {                      /* two toggles */
		CGContextSetLineWidth(c, 1.4);
		for (int i = 0; i < 2; i++) {
			CGFloat y = cy + (i ? -5.5 : 1); CGRect r = CGRectMake(cx - 8, y, 16, 5.6);
			CGPathRef p = CGPathCreateWithRoundedRect(r, 2.8, 2.8, NULL); CGContextAddPath(c, p); CGContextStrokePath(c); CFRelease(p);
			CGFloat kx = i ? r.origin.x + 1.5 : r.origin.x + r.size.width - 4.1;
			CGContextFillEllipseInRect(c, CGRectMake(kx, y + 1.5, 2.6, 2.6));
		}
	} else {                                               /* "Wed Nov 18 04:28" */
		NSDateFormatter *f = [NSDateFormatter new]; f.dateFormat = @"EEE MMM d  HH:mm"; f.dateFormat = @"EEE MMM d HH:mm";
		NSString *t = [f stringFromDate: [NSDate date]];
		CTFontRef font = CTFontCreateUIFontForLanguage(kCTFontUIFontSystem, 13, NULL);
		NSDictionary *a = @{ (id)kCTFontAttributeName: (__bridge id)font, (id)kCTForegroundColorFromContextAttributeName: @YES };
		CTLineRef line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)[[NSAttributedString alloc] initWithString: t attributes: a]);
		CGRect b = CTLineGetBoundsWithOptions(line, 0);
		CGContextSetTextPosition(c, s.width - 8 - b.size.width, cy - 4.5); CTLineDraw(line, c);
		CFRelease(line); CFRelease(font);
	}
	CGImageRef img = CGBitmapContextCreateImage(c); CGContextRelease(c); CGColorSpaceRelease(cs);
	return img;
}

@implementation CCStatusBar
{ DockWindow *wins[3]; CALayer *layers[3]; }
- (void)refresh
{
	for (int i = 0; i < 3; i++) {
		if (!layers[i]) continue;
		CGImageRef img = render(i, kFrames[i].size); layers[i].contents = (__bridge id)img; CGImageRelease(img);
	}
	[CATransaction flush];
}
- (void)start
{
	const SkyLightAPI *sl = SkyLightLoad(); const CCSkyLight *cc = CCSkyLightLoad();
	if (!sl) return;
	for (int i = 0; i < 3; i++) {
		wins[i] = [[DockWindow alloc] initWithFrame: kFrames[i] level: 25 options: 0x10000];
		if (!wins[i]) { NSLog(@"cc: window %d not created", i); continue; }
		CALayer *l = [CALayer layer]; l.frame = CGRectMake(0, 0, kFrames[i].size.width, kFrames[i].size.height);
		l.contentsGravity = kCAGravityResize; layers[i] = l;
		[wins[i] setRootLayer: l];
		int cid = sl->MainConnectionID(); uint32_t wid = wins[i].windowID;
		if (cc->SetWindowClientPerceivedType) cc->SetWindowClientPerceivedType(cid, wid, 5);
		if (cc->SetWindowEventMask) cc->SetWindowEventMask(cid, wid, 0xee5cffde);
		if (cc->SetWindowTitle) cc->SetWindowTitle(cid, wid, (__bridge CFStringRef)@"Control Center");
		CFTypeRef tx = sl->TransactionCreate(cid);
		if (tx) {
			uint64_t tags[1] = { 0 };
			if (cc->SetWindowTags) { cc->SetWindowTags(tx, wid, tags, 0x40, 0); cc->SetWindowTags(tx, wid, tags, 0x40, 1); }
			sl->TransactionSetWindowLevel(tx, wid, 25);
			if (cc->RegisterSortedWindow) cc->RegisterSortedWindow(tx, wid, kKeys[i], (__bridge CFTypeRef)[NSString stringWithFormat: @"com.pearos.controlcenter.item%d", i], i == ItemClock ? 0x590 : 0x490, i == ItemClock ? 0 : 2);
			sl->TransactionOrderWindow(tx, wid, 1, 0);
			sl->TransactionCommit(tx, 1); CFRelease(tx);
		}
	}
	[self refresh];
	[NSTimer scheduledTimerWithTimeInterval: 10 repeats: YES block: ^(NSTimer *t) { (void)t; [self refresh]; }];
}
@end
