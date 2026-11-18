#import "DockMagnify.h"
#import "DockController.h"
#import "DockHover.h"
#import "../dock/dock_layout.h"
#import <math.h>
@implementation DockMagnify
{ DockController *ctl; NSTimer *timer; CGFloat str; CGFloat lastMouse; BOOL inZone; BOOL dirty; }
- (CGFloat)strength { return str; }
- (instancetype)initWithController:(DockController *)c
{
	if (!(self = [super init])) return nil;
	ctl = c; lastMouse = 0;
	timer = [NSTimer scheduledTimerWithTimeInterval: 1.0 / 60 target: self selector: @selector(tick) userInfo: nil repeats: YES];
	return self;
}
- (void)modelChanged { str = 0; dirty = NO; }
static double G(double d)                       /* the magnification profile of the real Dock (fitted) */
{
	double u = fabs(d) / 175.0; if (u >= 1) return 0; return 0.5 * (1 + cos(M_PI * pow(u, 1.2)));
}
- (void)tick
{
	DockModel *m = ctl.model; CALayer *root = ctl.root; if (!m || !root || !m.magnification) return;
	CGEventRef ev = CGEventCreate(NULL); CGPoint p = CGEventGetLocation(ev); CFRelease(ev);
	int ori = m.orientation; CGFloat large = m.largeSize, tile = m.tileSize, extra = MAX(0, large - tile);
	/* the zone where the Dock reacts: the bar at rest, widened by the room the icons take when they grow */
	CGRect zone = m.baseBarRect; if (ori == 0) { zone.origin.y -= extra + 4; zone.size.height += extra + 4; } else if (ori == 1) zone.size.width += extra + 4; else { zone.origin.x -= extra + 4; zone.size.width += extra + 4; }
	BOOL now = CGRectContainsPoint(zone, p);
	CGFloat target = now ? 1 : 0; CGFloat prev = str;
	str += (target - str) * 0.35; if (fabs(target - str) < 0.01) str = target;      /* eased: about 0.1 s */
	CGFloat mouse = ori == 0 ? p.x : p.y; if (now) lastMouse = mouse;
	if (str == 0 && prev == 0 && !dirty) { m.magExtra = 0; for (DockTile *t0 in m.tiles) t0.magnified = NO; return; }
	CGFloat mx = lastMouse;
	NSArray<DockTile *> *tiles = m.tiles; NSUInteger n = tiles.count; if (!n) return;
	double sl[n], c[n], base[n]; double delta = extra, sepgrow = 0.415 * delta * str;
	for (NSUInteger i = 0; i < n; i++) {
		DockTile *t = tiles[i]; CGRect b = t.baseFrame; double lo = ori == 0 ? CGRectGetMinX(b) : CGRectGetMinY(b), hi = ori == 0 ? CGRectGetMaxX(b) : CGRectGetMaxY(b);
		base[i] = hi - lo; c[i] = (lo + hi) / 2; double g = G(c[i] - mx) * str;
		sl[i] = base[i] + (t.kind == DOCK_SEPARATOR ? 14.0 / 33.7 * delta * g : delta * g);
		(void)sepgrow;
	}
	/* the anchor rule: the slot under the pointer keeps the pointer at the same fraction */
	NSUInteger k = 0; for (NSUInteger i = 0; i < n; i++) { DockTile *t = tiles[i]; double lo = ori == 0 ? CGRectGetMinX(t.baseFrame) : CGRectGetMinY(t.baseFrame); if (lo <= mx) k = i; }
	double lok = ori == 0 ? CGRectGetMinX(tiles[k].baseFrame) : CGRectGetMinY(tiles[k].baseFrame); double u = base[k] > 0 ? (mx - lok) / base[k] : 0;
	double before = 0; for (NSUInteger i = 0; i < k; i++) before += sl[i];
	double lo0 = ori == 0 ? CGRectGetMinX(tiles[0].baseFrame) : CGRectGetMinY(tiles[0].baseFrame);
	double start = str > 0 ? mx - u * sl[k] - before : lo0;
	if (str == 0) start = lo0;
	double pos = start; CGRect bar0 = m.baseBarRect; double padLo = lo0 - (ori == 0 ? CGRectGetMinX(bar0) : CGRectGetMinY(bar0));
	double padHi = (ori == 0 ? CGRectGetMaxX(bar0) : CGRectGetMaxY(bar0)) - (ori == 0 ? CGRectGetMaxX(tiles[n - 1].baseFrame) : CGRectGetMaxY(tiles[n - 1].baseFrame));
	[CATransaction begin]; [CATransaction setDisableActions: YES];
	for (NSUInteger i = 0; i < n; i++) {
		DockTile *t = tiles[i]; t.magnified = str > 0; CGRect b = t.baseFrame; double g = G(c[i] - mx) * str, s = t.kind == DOCK_SEPARATOR ? 0 : tile + extra * g;
		CGRect f = b; if (ori == 0) { f.origin.x = pos; f.size.width = sl[i]; } else { f.origin.y = pos; f.size.height = sl[i]; } t.frame = f;
		double mid = pos + sl[i] / 2;
		if (t.kind == DOCK_SEPARATOR) { CGRect s0 = t.sepLayer.frame; if (ori == 0) s0.origin.x = mid - 0.5; else s0.origin.y = mid - 0.5; t.sepLayer.frame = s0; }
		else if (t.iconLayer) {
			CGRect b0 = t.baseIcon, a = b0; double a0 = b0.size.width, sz = round(s); if (sz < 1) sz = a0;
			if (ori == 0) { a.size = CGSizeMake(sz, sz); a.origin.x = round(mid - sz / 2); a.origin.y = b0.origin.y + a0 - sz - t.bounce; }                        /* the bottom stays on the baseline (plus the launch bounce) */
			else { a.size = CGSizeMake(sz, sz); a.origin.y = round(mid - sz / 2); a.origin.x = ori == 1 ? b0.origin.x : b0.origin.x + a0 - sz; }          /* away from the edge */
			t.iconLayer.frame = a;
			if (t.badgeLayer) { CGRect bf = t.badgeLayer.frame; bf.origin.x = a.origin.x + a.size.width - bf.size.width - 2; bf.origin.y = a.origin.y; t.badgeLayer.frame = bf; }
			if (t.dotLayer) { CGRect df = t.dotLayer.frame; if (ori == 0) df.origin.x = mid - 2; else df.origin.y = mid - 2; t.dotLayer.frame = df; }
		}
		pos += sl[i];
	}
	CGRect bar = bar0; if (ori == 0) { bar.origin.x = start - padLo; bar.size.width = (pos - start) + padLo + padHi; } else { bar.origin.y = start - padLo; bar.size.height = (pos - start) + padLo + padHi; }
	m.barRect = bar; m.barLayer.frame = bar; m.magExtra = extra * str;
	[CATransaction commit]; [CATransaction flush];
	dirty = str > 0; inZone = now;
	[[ctl valueForKey: @"hoverObject"] relayoutLabel];
}
@end
