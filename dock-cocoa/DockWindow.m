#import "DockWindow.h"
#import "SkyLightAPI.h"
#import <objc/message.h>
@implementation DockWindow
{ const SkyLightAPI *sl; SLCid cid; int _level; id context; }
- (instancetype)initWithFrame:(CGRect)frame level:(int)level
{
	if (!(self = [super init])) return nil;
	sl = SkyLightLoad(); if (getenv("DOCK_LOG")) NSLog(@"dock: skylight %p newwindow %p region %p", sl, sl ? sl->NewWindowWithOpaqueShapeAndContext : 0, sl ? sl->NewRegionWithRect : 0);
	if (!sl || !sl->NewWindowWithOpaqueShapeAndContext || !sl->NewRegionWithRect) return nil;
	cid = sl->MainConnectionID();
	/* the layer context first, then the window that carries it (the order of the real Dock: CAContext contextWithCGSConnection:options: -> SLSNewWindowWithOpaqueShapeAndContext), CAContext is a private class of QuartzCore */
	Class C = NSClassFromString(@"CAContext"); if (!C) return nil;
	context = ((id (*)(Class, SEL, int, id))objc_msgSend)(C, sel_registerName("contextWithCGSConnection:options:"), cid, @{});
	if (!context) return nil;
	CFTypeRef region = NULL, opaque = NULL; CGRect local = CGRectMake(0, 0, frame.size.width, frame.size.height);
	sl->NewRegionWithRect(&local, &region); sl->NewRegionWithRect(&local, &opaque);
	uint64_t tags[1] = { 0 }; SLWid wid = 0;
	CGError e = sl->NewWindowWithOpaqueShapeAndContext(cid, 5 /* the real Dock passes type 5 (dtrace); 0 and 1 fail with error 1000, 2 makes a window without content */, region, opaque, 0, tags, (float)frame.origin.x, (float)frame.origin.y, 0x40, &wid, (__bridge void *)context);
	if (getenv("DOCK_LOG")) NSLog(@"dock: NewWindow cid %d error %d wid %u region %p", cid, e, wid, region);
	if (region) CFRelease(region); if (opaque) CFRelease(opaque);
	if (e != kCGErrorSuccess || !wid) return nil;
	_windowID = wid;
	_level = level;
	return self;
}
+ (CGRect)mainDisplayBounds
{
	const SkyLightAPI *a = SkyLightLoad(); CGRect b = CGRectMake(0, 0, 1280, 800);
	if (a && a->MainDisplayID && a->GetDisplayBounds) a->GetDisplayBounds(a->MainDisplayID(), &b);
	return b;
}
/* level and order through a transaction, like the real Dock (SLSTransactionCreate, SetWindowLevel, OrderWindow, Commit) */
- (void)setRootLayer:(CALayer *)layer
{
	if (!context) return;
	((void (*)(id, SEL, id))objc_msgSend)(context, sel_registerName("setLayer:"), layer);          /* after the window exists, like the real Dock */
	[CATransaction flush];
}
- (void)orderIn
{
	if (!sl || !_windowID) return;
	if (sl->TransactionCreate && sl->TransactionSetWindowLevel && sl->TransactionOrderWindow && sl->TransactionCommit) {
		CFTypeRef tx = sl->TransactionCreate(cid);
		if (tx) { sl->TransactionSetWindowLevel(tx, _windowID, _level); sl->TransactionOrderWindow(tx, _windowID, 1 /* above */, 0); sl->TransactionCommit(tx, 1); CFRelease(tx); return; }
	}
	if (sl->SetWindowLevel) sl->SetWindowLevel(cid, _windowID, _level);
	if (sl->OrderWindow) sl->OrderWindow(cid, _windowID, 1, 0);
}
@end
