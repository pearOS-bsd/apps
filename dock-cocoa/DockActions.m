#import "DockActions.h"
#import "../dock/dock_layout.h"
#import "DockBounce.h"
#import <CoreServices/CoreServices.h>
#import <ApplicationServices/ApplicationServices.h>
void DockOpenTile(DockTile *t)
{
	NSString *path = t.kind == DOCK_TRASH ? [NSHomeDirectory() stringByAppendingPathComponent: @".Trash"] : t.path; if (!path.length) return;
	DockBounceStart(t);
	NSURL *u = [NSURL fileURLWithPath: path];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
	LSOpenCFURLRef((__bridge CFURLRef)u, NULL);
#pragma clang diagnostic pop
}
void DockQuitTile(DockTile *t)
{
	if (!t.bundleIdentifier.length) return;
	const char *bid = t.bundleIdentifier.UTF8String; AEDesc target; AppleEvent ev;
	if (AECreateDesc(typeApplicationBundleID, bid, strlen(bid), &target) != noErr) return;
	if (AECreateAppleEvent(kCoreEventClass, kAEQuitApplication, &target, kAutoGenerateReturnID, kAnyTransactionID, &ev) == noErr) { AESendMessage(&ev, NULL, kAENoReply, kAEDefaultTimeout); AEDisposeDesc(&ev); }
	AEDisposeDesc(&target);
}
void DockRevealTile(DockTile *t)
{
	if (!t.path.length) return;
	NSTask *k = [NSTask new]; k.launchPath = @"/usr/bin/open"; k.arguments = @[ @"-R", t.path ]; @try { [k launch]; } @catch (NSException *e) {}
}
