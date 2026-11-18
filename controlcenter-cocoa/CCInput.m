#import "CCInput.h"
#import <ApplicationServices/ApplicationServices.h>
@implementation CCInput
{ CCPanel *panel; CGRect item; CFMachPortRef tap; }
static CGEventRef onEvent(CGEventTapProxy proxy, CGEventType type, CGEventRef ev, void *ref)
{
	CCInput *self = (__bridge CCInput *)ref;
	if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) { CGEventTapEnable(self->tap, true); return ev; }
	if (type == kCGEventLeftMouseDown) {
		CGPoint p = CGEventGetLocation(ev);
		if (CGRectContainsPoint(self->item, p)) { dispatch_async(dispatch_get_main_queue(), ^{ [self->panel toggle]; }); return NULL; }
		if (self->panel.visible && [self->panel containsScreenPoint: p]) { dispatch_async(dispatch_get_main_queue(), ^{ [self->panel clickAtScreenPoint: p]; }); return NULL; }
		if (self->panel.visible) dispatch_async(dispatch_get_main_queue(), ^{ [self->panel hide]; });
	}
	return ev;
}
- (instancetype)initWithPanel:(CCPanel *)p controlItemFrame:(CGRect)f
{
	if (!(self = [super init])) return nil;
	panel = p; item = f;
	tap = CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap, kCGEventTapOptionDefault, CGEventMaskBit(kCGEventLeftMouseDown), onEvent, (__bridge void *)self);
	if (!tap) { NSLog(@"cc: no event tap (AXIsProcessTrusted %d, listen %d, post %d)", AXIsProcessTrusted(), CGPreflightListenEventAccess(), CGPreflightPostEventAccess()); return self; }
	CFRunLoopSourceRef src = CFMachPortCreateRunLoopSource(NULL, tap, 0); CFRunLoopAddSource(CFRunLoopGetMain(), src, kCFRunLoopCommonModes); CFRelease(src); CGEventTapEnable(tap, true);
	return self;
}
@end
