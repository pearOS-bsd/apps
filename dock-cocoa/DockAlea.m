#import "DockAlea.h"
static NSData *utf16(NSString *s) { return [s dataUsingEncoding: NSUTF16LittleEndianStringEncoding]; }
DockMinimizeRequest DockParseMinimize(NSData *d, NSString **title)
{
	DockMinimizeRequest r = { NO, 0, YES }; const uint8_t *b = d.bytes; NSUInteger n = d.length;
	if (n < 16 || memcmp(b, "alea", 4) != 0) return r;
	NSRange rt = [d rangeOfData: utf16(@"title") options: 0 range: NSMakeRange(0, n)];
	if (rt.location != NSNotFound) {                     /* after the key: u32 type, u32 length, u32 0, characters */
		NSUInteger p = rt.location + rt.length + 4;      /* the 4 bytes between the key's characters and the value's length (observed 00 00 00 00 / 00 00 -- shifted by one in places) */
		for (NSUInteger q = p - 4; q < p + 8 && q + 8 <= n; q++) {       /* find the value's length u32 followed by u32 0 and plausible characters */
			uint32_t len = *(uint32_t *)(b + q), z = *(uint32_t *)(b + q + 4);
			if (len > 0 && len < 256 && z == 0 && q + 8 + len * 2 <= n && q > rt.location + rt.length) { if (title) *title = [[NSString alloc] initWithBytes: b + q + 8 length: len * 2 encoding: NSUTF16LittleEndianStringEncoding]; break; }
		}
	}
	NSRange ri = [d rangeOfData: utf16(@"item") options: 0 range: NSMakeRange(0, n)];
	if (ri.location != NSNotFound) {                     /* after the key: u32 1, u32 3, u32 4, u32 0, u32 <window id> (observed twice) */
		NSUInteger p = ri.location + ri.length;
		if (p + 20 <= n) { uint32_t w[5]; memcpy(w, b + p, 20); if (w[0] == 1 && w[1] == 3 && w[2] == 4) { r.windowID = w[4]; r.ok = r.windowID != 0; } }
	}
	NSRange ra = [d rangeOfData: utf16(@"animate") options: 0 range: NSMakeRange(0, n)];
	if (ra.location != NSNotFound && ra.location + ra.length + 8 <= n) r.animate = *(uint32_t *)(b + ra.location + ra.length + 4) != 0;       /* the one example had type 2 then 0 */
	return r;
}
