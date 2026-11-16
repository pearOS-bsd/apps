/* The SkyLight functions the Dock calls, resolved at run time (dlsym) so that the same source runs against Apple's SkyLight on a Mac and against pearOS's SkyLight (repository `SkyLight`).
 * Prototypes are OURS, written from (1) the call sites in the real Dock (REA: the Swift wrapper at 0x10021f09c passes cid, type, region, opaque region, options, tags, tag size 0x40, window id pointer,
 * context to SLSNewWindowWithOpaqueShapeAndContext) and (2) behaviour observed on the Mac VM; each one is marked verified or not. */
#import <CoreFoundation/CoreFoundation.h>
#import <CoreGraphics/CoreGraphics.h>
typedef int SLCid;
typedef uint32_t SLWid;
typedef struct {
	SLCid (*MainConnectionID)(void);                                                                                   /* verified: used by the real Dock */
	CGError (*NewRegionWithRect)(const CGRect *rect, CFTypeRef *region);                                                /* symbol CGSNewRegionWithRect (there is no SLS name: checked with dlsym on 26.7.2); prototype UNVERIFIED */
	CGError (*NewWindowWithOpaqueShapeAndContext)(SLCid cid, int type, CFTypeRef region, CFTypeRef opaque, int options, uint64_t *tags,
		float x, float y, int tagSize, SLWid *wid, void *context);                                                      /* argument order verified on the call site; semantics of type/options UNVERIFIED */
	CGError (*SetWindowLevel)(SLCid cid, SLWid wid, int level);                                                         /* same shape as in our SkyLight/include/SkyLight.h */
	CGError (*OrderWindow)(SLCid cid, SLWid wid, int mode, SLWid relativeTo);                                           /* UNVERIFIED prototype */
	CGError (*ReleaseWindow)(SLCid cid, SLWid wid);                                                                     /* UNVERIFIED prototype */
} SkyLightAPI;
/* returns NULL when SkyLight cannot be loaded */
const SkyLightAPI *SkyLightLoad(void);
