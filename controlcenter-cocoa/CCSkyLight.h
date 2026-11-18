/* SkyLight status-bar functions used by the real ControlCenter (not in ../dock-cocoa/SkyLightAPI).  Prototypes are from dtrace argument captures of the real process
 * (research/cc-trace/sbargs-real.txt, sbargs2-real.txt) and are UNVERIFIED until checked with REA on SkyLight's code; names resolved with dlsym. */
#import <CoreFoundation/CoreFoundation.h>
#import <CoreGraphics/CoreGraphics.h>
typedef struct {
	/* VERIFIED with REA (Ghidra pseudo-code of SkyLight's _SLSTransactionSystemStatusBarRegisterSortedWindow, x86_64): encodes opcode 0x3a, then packed64(wid), packed64(key), CFString(ident), packed64(a),
	 * packed64(b), the float (packed as integer when it is integral, else 0x48 + float), packed64(last).  Real call values (dtrace): key 0x7ffffff5 / 0x7fffffe1, a 0x590 / 0x490, b 0 / 2; f and last not captured yet (f is in xmm0). */
	CGError (*RegisterSortedWindow)(CFTypeRef tx, uint32_t wid, int key, CFStringRef ident, uint32_t a, int b, float f, uint32_t last);
	/* (tx, wid, tags*, tagsize 0x40, clear?) real: called twice per window (clear 0 and 1) */
	CGError (*SetWindowTags)(CFTypeRef tx, uint32_t wid, uint64_t *tags, int tagSize, int clear);
	CGError (*GetWindowPreferredPosition)(int cid, uint32_t wid, void *out);     /* out = 16 bytes seen */
	CGError (*SetWindowEventMask)(int cid, uint32_t wid, uint32_t mask);
	CGError (*SetWindowTitle)(int cid, uint32_t wid, CFStringRef title);
	CGError (*SetWindowClientPerceivedType)(int cid, uint32_t wid, int type);
} CCSkyLight;
const CCSkyLight *CCSkyLightLoad(void);

/* Orders a window in the way the real ControlCenter does it for its windows (dtrace): window tags (two calls), level and order in ONE transaction.  DockWindow's own orderIn left the panel at level 0 on pearOS. */
@class DockWindow;
void CCShowWindow(DockWindow *w, int level);
