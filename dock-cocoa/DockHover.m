#import "DockHover.h"
#import <CoreText/CoreText.h>
#import "../dock/dock_layout.h"
#import "DockController.h"
@implementation DockHover
{ DockController *ctl; NSTimer *timer; NSInteger shown; CALayer *label; }
- (CALayer *)root { return ctl.root; }
- (DockModel *)model { return ctl.model; }
- (instancetype)initWithController:(DockController *)c
{
	if (!(self = [super init])) return nil;
	ctl = c; shown = -1;
	timer = [NSTimer scheduledTimerWithTimeInterval: 1.0 / 60 target: self selector: @selector(tick) userInfo: nil repeats: YES];
	return self;
}
- (void)modelChanged { label = nil; shown = -1; }
- (void)hideLabel { [CATransaction begin]; [CATransaction setDisableActions: YES]; [label removeFromSuperlayer]; label = nil; shown = -2; [CATransaction commit]; [CATransaction flush]; }
- (NSInteger)tileAt:(CGPoint)p
{
	DockModel *model = self.model; CGRect bar = model.barRect; if (!CGRectContainsPoint(CGRectInset(bar, 0, -2), p)) return -1;
	for (NSUInteger i = 0; i < model.tiles.count; i++) { DockTile *t = model.tiles[i]; if (t.kind != DOCK_SEPARATOR && p.x >= CGRectGetMinX(t.frame) && p.x < CGRectGetMaxX(t.frame)) return (NSInteger)i; }
	return -1;
}
- (CALayer *)labelFor:(DockTile *)t
{
	NSString *text = t.label.length ? t.label : (t.kind == DOCK_TRASH ? @"Trash" : @"");
	CTFontRef font = CTFontCreateUIFontForLanguage(kCTFontUIFontToolTip, 14, NULL);
	NSDictionary *attr = @{ (__bridge id)kCTFontAttributeName: (__bridge id)font, (__bridge id)kCTForegroundColorFromContextAttributeName: @YES };
	CTLineRef line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)[[NSAttributedString alloc] initWithString: text attributes: attr]);
	CGFloat asc, desc, lead; double tw = CTLineGetTypographicBounds(line, &asc, &desc, &lead); CFRelease(line);
	CGFloat w = round(tw + 26.6), h = 27, ptrH = 6, ptrW = 12;       /* 14 pt text, 14 px each side: the real pill is 64 px wide for "Safari" */
	CGFloat cx = CGRectGetMidX(t.frame), top = CGRectGetMinY(self.model.barRect) - 40;
	CALayer *box = [CALayer layer]; box.frame = CGRectMake(round(cx - w / 2), top, w, h + ptrH);
	CAShapeLayer *shape = [CAShapeLayer layer]; shape.frame = box.bounds;
	CGMutablePathRef path = CGPathCreateMutable(); CGPathAddRoundedRect(path, NULL, CGRectMake(0, 0, w, h), h / 2, h / 2);
	/* the pointer, drawn in the same direction as the pill and overlapping it (non-zero fill) so there is no seam */
	CGPathMoveToPoint(path, NULL, w / 2 - ptrW / 2, h - 4); CGPathAddLineToPoint(path, NULL, w / 2 + ptrW / 2, h - 4); CGPathAddLineToPoint(path, NULL, w / 2 + ptrW / 2, h - 0.5); CGPathAddLineToPoint(path, NULL, w / 2, h + ptrH); CGPathAddLineToPoint(path, NULL, w / 2 - ptrW / 2, h - 0.5); CGPathCloseSubpath(path);
	shape.path = path; CGPathRelease(path); CGColorRef k = CGColorCreateGenericRGB(0, 0, 0, 1); shape.fillColor = k; CGColorRelease(k); [box addSublayer: shape];
	CATextLayer *tl = [CATextLayer layer]; tl.string = text; tl.font = font; tl.fontSize = 14; tl.alignmentMode = kCAAlignmentCenter; tl.contentsScale = 1;
	CGColorRef wh = CGColorCreateGenericRGB(1, 1, 1, 1); tl.foregroundColor = wh; CGColorRelease(wh);
	tl.frame = CGRectMake(0, round((h - (asc + desc)) / 2) - 1, w, asc + desc + 2); [box addSublayer: tl];
	CFRelease(font);
	return box;
}
- (void)tick
{
	CGEventRef ev = CGEventCreate(NULL); CGPoint p = CGEventGetLocation(ev); CFRelease(ev);
	if (ctl.root == nil) return; NSInteger i = [self tileAt: p]; if (shown == -2) { if (i < 0) shown = -1; return; }       /* -2: hidden on purpose (drag, menu) until the pointer leaves the bar */
	if (i == shown) return; shown = i; DockModel *model = self.model; CALayer *root = self.root;
	[CATransaction begin]; [CATransaction setDisableActions: YES];
	[label removeFromSuperlayer]; label = nil;
	if (i >= 0 && model.tiles[i].label.length + (model.tiles[i].kind == DOCK_TRASH) > 0) { label = [self labelFor: model.tiles[i]]; [root addSublayer: label]; }
	[CATransaction commit]; [CATransaction flush];
}
@end
