#import "DockWindow.h"
#import "SkyLightAPI.h"
@implementation DockWindow
{ const SkyLightAPI *sl; SLCid cid; }
- (instancetype)initWithFrame:(CGRect)frame level:(int)level
{
	if (!(self = [super init])) return nil;
	sl = SkyLightLoad(); if (getenv("DOCK_LOG")) NSLog(@"dock: skylight %p newwindow %p region %p", sl, sl ? sl->NewWindowWithOpaqueShapeAndContext : 0, sl ? sl->NewRegionWithRect : 0);
	if (!sl || !sl->NewWindowWithOpaqueShapeAndContext || !sl->NewRegionWithRect) return nil;
	cid = sl->MainConnectionID();
	CFTypeRef region = NULL, opaque = NULL; CGRect local = CGRectMake(0, 0, frame.size.width, frame.size.height);
	sl->NewRegionWithRect(&local, &region); sl->NewRegionWithRect(&local, &opaque);
	uint64_t tags[1] = { 0 }; SLWid wid = 0;
	CGError e = sl->NewWindowWithOpaqueShapeAndContext(cid, 2 /* buffered: 0 and 1 fail with error 1000 (tried on 26.7.2) */, region, opaque, 0, tags, (float)frame.origin.x, (float)frame.origin.y, 0x40, &wid, NULL);
	if (getenv("DOCK_LOG")) NSLog(@"dock: NewWindow cid %d error %d wid %u region %p", cid, e, wid, region);
	if (region) CFRelease(region); if (opaque) CFRelease(opaque);
	if (e != kCGErrorSuccess || !wid) return nil;
	_windowID = wid;
	if (sl->SetWindowLevel) sl->SetWindowLevel(cid, wid, level);
	return self;
}
- (void)orderIn { if (sl && sl->OrderWindow && _windowID) sl->OrderWindow(cid, _windowID, 1 /* above */, 0); }
@end
