#import "CCInput.h"
#import "CCGallery.h"
#import "CCExtras.h"
#import <ApplicationServices/ApplicationServices.h>
#include <fcntl.h>
#include <unistd.h>
@implementation CCInput
{ CCPanel *panel; CCStatusBar *bar; CGRect item; CFMachPortRef tap; BOOL swallowUp; }
static CGEventRef onEvent(CGEventTapProxy proxy, CGEventType type, CGEventRef ev, void *ref)
{
	CCInput *self = (__bridge CCInput *)ref; CCPanel *panel = self->panel;
	if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) { CGEventTapEnable(self->tap, true); return ev; }
	CGPoint p = CGEventGetLocation(ev);
	if (getenv("CC_TRACE")) { static int n; if (n < 40) { n++; int fd = open("/Users/alex/cc-ev.txt", O_WRONLY | O_CREAT | O_APPEND, 0644); if (fd >= 0) { dprintf(fd, "event type %d at %.0f,%.0f\n", (int)type, p.x, p.y); close(fd); } } }
	if (type == kCGEventLeftMouseDown) {
		CCKind ek; CGFloat mid; if (self->bar && [[self->bar extras] kindAtPoint: p kind: &ek midX: &mid]) { self->swallowUp = YES; dispatch_async(dispatch_get_main_queue(), ^{ [panel toggleExtra: ek atX: mid]; }); return NULL; }
		if (CGRectContainsPoint(self->item, p)) { self->swallowUp = YES; dispatch_async(dispatch_get_main_queue(), ^{ [panel toggle]; }); return NULL; }
		if (panel.visible && [panel containsScreenPoint: p]) { self->swallowUp = YES; dispatch_async(dispatch_get_main_queue(), ^{ [panel mouseDown: p]; }); return NULL; }
		if (panel.visible && !panel.editing) dispatch_async(dispatch_get_main_queue(), ^{ [panel hide]; });
	} else if (type == kCGEventMouseMoved) {
		if (panel.visible) dispatch_async(dispatch_get_main_queue(), ^{ [panel hoverAt: p]; });
	} else if (type == kCGEventLeftMouseDragged && self->swallowUp) {
		dispatch_async(dispatch_get_main_queue(), ^{ [panel mouseDragged: p]; }); return NULL;
	} else if (type == kCGEventLeftMouseUp && self->swallowUp) {
		self->swallowUp = NO; dispatch_async(dispatch_get_main_queue(), ^{ [panel mouseUp: p]; }); return NULL;
	} else if (type == kCGEventScrollWheel && panel.editing && [panel containsScreenPoint: p]) {
		double dy = CGEventGetDoubleValueField(ev, kCGScrollWheelEventPointDeltaAxis1); dispatch_async(dispatch_get_main_queue(), ^{ [panel scrollGallery: dy]; }); return NULL;
	} else if (type == kCGEventKeyDown && panel.editing) {
		UniChar ch[8]; UniCharCount n = 0; CGEventKeyboardGetUnicodeString(ev, 8, &n, ch); int key = (int)CGEventGetIntegerValueField(ev, kCGKeyboardEventKeycode);
		NSString *s = key == 51 ? @"\b" : (n ? [NSString stringWithCharacters: ch length: n] : nil);
		if (key == 53) { dispatch_async(dispatch_get_main_queue(), ^{ [panel setEditing: NO]; }); return NULL; }              /* Escape = Done */
		if (s && (key == 51 || [s characterAtIndex: 0] >= 32)) { dispatch_async(dispatch_get_main_queue(), ^{ [panel typeInGallery: s]; }); return NULL; }
	}
	return ev;
}
- (instancetype)initWithPanel:(CCPanel *)p controlItemFrame:(CGRect)f statusBar:(CCStatusBar *)b
{
	if (!(self = [super init])) return nil;
	panel = p; item = f; bar = b;     /* CC_LISTEN_ONLY=1 (pearOS: WindowServer serves listen-only taps; the events that the panel uses are then not swallowed) */
	CGEventMask m = (getenv("CC_NO_HOVER") ? 0 : CGEventMaskBit(kCGEventMouseMoved)) | CGEventMaskBit(kCGEventLeftMouseDown) | CGEventMaskBit(kCGEventLeftMouseUp) | CGEventMaskBit(kCGEventLeftMouseDragged) | CGEventMaskBit(kCGEventScrollWheel) | CGEventMaskBit(kCGEventKeyDown);
	tap = CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap, getenv("CC_LISTEN_ONLY") ? kCGEventTapOptionListenOnly : kCGEventTapOptionDefault, m, onEvent, (__bridge void *)self);
	if (getenv("CC_TRACE")) { int fd = open("/Users/alex/cc-tap.txt", O_WRONLY | O_CREAT | O_TRUNC, 0644); if (fd >= 0) { dprintf(fd, "tap=%p\n", (void *)tap); close(fd); } }       /* not AXIsProcessTrusted / CGPreflight...: those ask tccd through the bridge and the main thread could wait for ever */
	if (!tap) { NSLog(@"cc: no event tap (AXIsProcessTrusted %d, listen %d, post %d)", AXIsProcessTrusted(), CGPreflightListenEventAccess(), CGPreflightPostEventAccess()); return self; }
	CFRunLoopSourceRef src = CFMachPortCreateRunLoopSource(NULL, tap, 0); CFRunLoopAddSource(CFRunLoopGetMain(), src, kCFRunLoopCommonModes); CFRelease(src); CGEventTapEnable(tap, true);
	return self;
}
@end
