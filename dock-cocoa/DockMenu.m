#import "DockMenu.h"
#import <CoreText/CoreText.h>
@implementation DockMenuItem
+ (instancetype)item:(NSString *)title action:(void (^)(void))action { DockMenuItem *i = [DockMenuItem new]; i.title = title; i.enabled = YES; i.action = action; return i; }
+ (instancetype)separator { DockMenuItem *i = [DockMenuItem new]; i.isSeparator = YES; return i; }
@end
static const CGFloat kRow = 22, kPad = 6, kSep = 9;
@implementation DockMenu
{ NSArray<DockMenuItem *> *items; CALayer *panel; CALayer *hi; DockMenu *sub; NSInteger hot; CGRect rect; NSMutableArray *rows; }
- (instancetype)initWithItems:(NSArray<DockMenuItem *> *)it { if (!(self = [super init])) return nil; items = it; hot = -1; rows = [NSMutableArray array]; return self; }
- (CGRect)frame { return rect; }
- (CATextLayer *)text:(NSString *)s bold:(BOOL)b color:(CGColorRef)c
{
	CATextLayer *t = [CATextLayer layer]; t.string = s; t.fontSize = 13; t.contentsScale = 1; t.foregroundColor = c;
	CTFontRef f = CTFontCreateUIFontForLanguage(b ? kCTFontUIFontEmphasizedSystem : kCTFontUIFontSystem, 13, NULL); t.font = f; CFRelease(f); return t;
}
- (CGFloat)widthOf:(NSString *)s bold:(BOOL)b
{
	CTFontRef f = CTFontCreateUIFontForLanguage(b ? kCTFontUIFontEmphasizedSystem : kCTFontUIFontSystem, 13, NULL);
	CTLineRef l = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)[[NSAttributedString alloc] initWithString: s attributes: @{ (__bridge id)kCTFontAttributeName: (__bridge id)f }]);
	double w = CTLineGetTypographicBounds(l, NULL, NULL, NULL); CFRelease(l); CFRelease(f); return ceil(w);
}
- (void)showInLayer:(CALayer *)root at:(CGPoint)anchor displayHeight:(CGFloat)dh
{
	CGFloat w = 120, h = 2 * kPad;
	for (DockMenuItem *i in items) { h += i.isSeparator ? kSep : kRow; if (!i.isSeparator) w = MAX(w, [self widthOf: i.title bold: i.isTitle] + 44); }
	CGFloat x = _leftTop ? anchor.x : round(anchor.x - w / 2), y = _leftTop ? anchor.y : anchor.y - h - 4; if (y < 34) y = 34;
	rect = CGRectMake(MAX(4, x), y, w, h);
	panel = [CALayer layer]; panel.frame = rect; panel.cornerRadius = 10; panel.masksToBounds = NO;
	CGColorRef bg = CGColorCreateGenericRGB(0.14, 0.14, 0.15, 0.96); panel.backgroundColor = bg; CGColorRelease(bg);
	CGColorRef bd = CGColorCreateGenericRGB(1, 1, 1, 0.18); panel.borderColor = bd; panel.borderWidth = 1; CGColorRelease(bd);
	hi = [CALayer layer]; hi.cornerRadius = 5; CGColorRef bl = CGColorCreateGenericRGB(0.04, 0.45, 0.98, 1); hi.backgroundColor = bl; CGColorRelease(bl); hi.hidden = YES; [panel addSublayer: hi];
	CGColorRef white = CGColorCreateGenericRGB(1, 1, 1, 1), grey = CGColorCreateGenericRGB(1, 1, 1, 0.45), line = CGColorCreateGenericRGB(1, 1, 1, 0.2);
	CGFloat cy = kPad;
	for (DockMenuItem *i in items) {
		if (i.isSeparator) { CALayer *l = [CALayer layer]; l.frame = CGRectMake(10, cy + kSep / 2, w - 20, 1); l.backgroundColor = line; [panel addSublayer: l]; cy += kSep; continue; }
		CATextLayer *t = [self text: i.title bold: i.isTitle color: (i.enabled || i.isTitle) ? white : grey]; t.frame = CGRectMake(22, cy + 2, w - 44, kRow - 2); [panel addSublayer: t];
		if (i.checked) { CATextLayer *c = [self text: @"✓" bold: NO color: white]; c.frame = CGRectMake(6, cy + 2, 14, kRow - 2); [panel addSublayer: c]; }
		if (i.submenu) { CATextLayer *c = [self text: @"›" bold: NO color: white]; c.frame = CGRectMake(w - 18, cy + 2, 12, kRow - 2); [panel addSublayer: c]; }
		[rows addObject: @{ @"item": i, @"y": @(cy) }]; cy += kRow;
	}
	CGColorRelease(white); CGColorRelease(grey); CGColorRelease(line);
	[CATransaction begin]; [CATransaction setDisableActions: YES]; [root addSublayer: panel]; [CATransaction commit]; [CATransaction flush];
}
- (void)close { [sub close]; sub = nil; [CATransaction begin]; [CATransaction setDisableActions: YES]; [panel removeFromSuperlayer]; panel = nil; [CATransaction commit]; [CATransaction flush]; }
- (BOOL)containsPoint:(CGPoint)p { return panel && (CGRectContainsPoint(rect, p) || [sub containsPoint: p]); }
- (NSInteger)rowAt:(CGPoint)p { if (!CGRectContainsPoint(rect, p)) return -1; for (NSUInteger k = 0; k < rows.count; k++) { CGFloat y = rect.origin.y + [rows[k][@"y"] doubleValue]; if (p.y >= y && p.y < y + kRow) return (NSInteger)k; } return -1; }
- (void)mouseMovedTo:(CGPoint)p
{
	if ([sub containsPoint: p]) { [sub mouseMovedTo: p]; return; }
	NSInteger r = [self rowAt: p]; if (r == hot) return; hot = r;
	[CATransaction begin]; [CATransaction setDisableActions: YES];
	DockMenuItem *it = r >= 0 ? rows[r][@"item"] : nil;
	if (r >= 0 && it.enabled && !it.isTitle) { hi.hidden = NO; hi.frame = CGRectMake(5, [rows[r][@"y"] doubleValue], rect.size.width - 10, kRow); } else hi.hidden = YES;
	[sub close]; sub = nil;
	if (it.submenu.count) { sub = [[DockMenu alloc] initWithItems: it.submenu]; sub.leftTop = YES; [sub showInLayer: panel.superlayer at: CGPointMake(rect.origin.x + rect.size.width - 2, rect.origin.y + [rows[r][@"y"] doubleValue] - kPad) displayHeight: 0]; }
	[CATransaction commit]; [CATransaction flush];
}
- (BOOL)clickAt:(CGPoint)p
{
	if ([sub containsPoint: p]) return [sub clickAt: p];
	NSInteger r = [self rowAt: p]; if (r < 0) return NO; DockMenuItem *it = rows[r][@"item"];
	if (!it.enabled || it.isTitle || it.submenu.count) return NO;
	[self close]; if (it.action) it.action(); return YES;
}
@end
