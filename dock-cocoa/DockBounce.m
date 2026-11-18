#import "DockBounce.h"
#import "DockController.h"
#import "DockMagnify.h"
#import "DockRunning.h"
#import "../dock/dock_layout.h"
#import <math.h>
static DockController *gCtl; static NSTimer *gTimer; static NSMutableDictionary<NSString *, NSMutableDictionary *> *gActive;
static const double kPeriod = 0.69, kHeightPerTile = 14.4 / 46.0, kDelay = 0.05;
static BOOL enabled(void)
{
	CFPropertyListRef v = CFPreferencesCopyAppValue(CFSTR("launchanim"), CFSTR("com.apple.dock")); BOOL on = YES;
	if (v) { if (CFGetTypeID(v) == CFBooleanGetTypeID()) on = CFBooleanGetValue(v); CFRelease(v); } return on;
}
static void tick(void)
{
	DockModel *m = gCtl.model; if (!m) return; double now = CACurrentMediaTime();
	static double lastCheck; BOOL check = now - lastCheck > 0.25; NSSet *running = nil;
	if (check) { lastCheck = now; NSMutableSet *s = [NSMutableSet set]; for (NSDictionary *a in DockRunningApplications()) [s addObject: [a[@"path"] stringByStandardizingPath]]; running = s; }
	for (NSString *key in [gActive allKeys]) {
		NSMutableDictionary *b = gActive[key]; double t0 = [b[@"t0"] doubleValue], el = now - t0 - kDelay;
		if (running && [running containsObject: key] && !b[@"ready"]) b[@"ready"] = @(now);
		DockTile *tile = nil; for (DockTile *x in m.tiles) if ([x.path.stringByStandardizingPath isEqualToString: key]) tile = x;
		double off = 0;
		if (el >= 0) {
			double cycles = el / kPeriod, u = cycles - floor(cycles);
			BOOL done = b[@"ready"] && el > ([b[@"ready"] doubleValue] - t0 - kDelay) && floor(cycles) > floor(([b[@"ready"] doubleValue] - t0 - kDelay) / kPeriod);      /* the cycle in progress when the application came up has ended */
			if (done || el > 30) { NSLog(@"dock: bounce of %@ ends after %.2f s (%.1f cycles, application up after %.2f s)", key.lastPathComponent, el + kDelay, cycles, b[@"ready"] ? [b[@"ready"] doubleValue] - t0 : -1.0); [gActive removeObjectForKey: key]; if (tile) tile.bounce = 0; continue; }
			off = (m.tileSize * kHeightPerTile) * sqrt(fmax(0, sin(M_PI * u)));
		}
		if (tile) tile.bounce = off;
	}
	/* apply: the magnification code includes tile.bounce when it runs; at rest we move the layers here */
	[CATransaction begin]; [CATransaction setDisableActions: YES];
	for (DockTile *t in m.tiles) {
		if (!t.iconLayer) continue; static NSMapTable *seen; if (!seen) seen = [NSMapTable weakToStrongObjectsMapTable];
		NSNumber *prev = [seen objectForKey: t]; if (t.bounce == 0 && !prev) continue;
		if (t.magnified) continue;
		CGRect f = t.iconLayer.frame; f.origin.y = t.baseIcon.origin.y - t.bounce; t.iconLayer.frame = f;
		if (t.badgeLayer) { CGRect bf = t.badgeLayer.frame; bf.origin.y = f.origin.y; t.badgeLayer.frame = bf; }
		if (t.bounce == 0) [seen removeObjectForKey: t]; else [seen setObject: @1 forKey: t];
	}
	[CATransaction commit]; [CATransaction flush];
	if (!gActive.count) { [gTimer invalidate]; gTimer = nil; }
}
void DockBounceInstall(DockController *c) { gCtl = c; gActive = [NSMutableDictionary dictionary]; }
void DockBounceStart(DockTile *t)
{
	if (!gCtl || t.kind != DOCK_APP || t.running || !t.path.length || !enabled()) return;
	NSString *key = t.path.stringByStandardizingPath; if (gActive[key]) return;
	gActive[key] = [@{ @"t0": @(CACurrentMediaTime()) } mutableCopy]; NSLog(@"dock: bounce of %@ starts", key.lastPathComponent);
	if (!gTimer) gTimer = [NSTimer scheduledTimerWithTimeInterval: 1.0 / 60 repeats: YES block: ^(NSTimer *x) { (void)x; tick(); }];
}
