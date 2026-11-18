/* SkyLight status-bar functions used by the real ControlCenter (not in ../dock-cocoa/SkyLightAPI).  Prototypes are from dtrace argument captures of the real process
 * (research/cc-trace/sbargs-real.txt, sbargs2-real.txt) and are UNVERIFIED until checked with REA on SkyLight's code; names resolved with dlsym. */
#import <CoreFoundation/CoreFoundation.h>
#import <CoreGraphics/CoreGraphics.h>
typedef struct {
	/* (tx, wid, sort key counted from the right edge: real values 0x7ffffff5 / 0x7fffffe1, identifier object, 0x590 / 0x490, 0 / 2) */
	CGError (*RegisterSortedWindow)(CFTypeRef tx, uint32_t wid, uint32_t key, CFTypeRef ident, uint32_t a4, uint32_t a5);
	/* (tx, wid, tags*, tagsize 0x40, clear?) real: called twice per window (clear 0 and 1) */
	CGError (*SetWindowTags)(CFTypeRef tx, uint32_t wid, uint64_t *tags, int tagSize, int clear);
	CGError (*GetWindowPreferredPosition)(int cid, uint32_t wid, void *out);     /* out = 16 bytes seen */
	CGError (*SetWindowEventMask)(int cid, uint32_t wid, uint32_t mask);
	CGError (*SetWindowTitle)(int cid, uint32_t wid, CFStringRef title);
	CGError (*SetWindowClientPerceivedType)(int cid, uint32_t wid, int type);
} CCSkyLight;
const CCSkyLight *CCSkyLightLoad(void);
