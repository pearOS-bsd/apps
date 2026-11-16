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
	uint32_t (*MainDisplayID)(void);                                                                                    /* verified on 26.7.2 (returned 1535231424) */
	CGError (*GetDisplayBounds)(uint32_t display, CGRect *bounds);                                                      /* verified: 0 0 1280 800 */
	CGError (*GetDisplayMenubarHeight)(uint32_t display, uint32_t *height);                                             /* verified: 30 */
	CFTypeRef (*TransactionCreate)(SLCid cid);                                                                          /* verified: returns an object (CF type) */
	CGError (*TransactionSetWindowLevel)(CFTypeRef tx, SLWid wid, int level);                                           /* UNVERIFIED prototype (checked by the window list) */
	CGError (*TransactionOrderWindow)(CFTypeRef tx, SLWid wid, int mode, SLWid relativeTo);                             /* UNVERIFIED prototype */
	CGError (*TransactionCommit)(CFTypeRef tx, int synchronous);                                                        /* UNVERIFIED prototype */
	CGError (*RegisterConnectionNotifyProc)(SLCid cid, void (*proc)(uint32_t type, void *data, size_t length, void *context, SLCid cid), uint32_t type, void *context);   /* shape from the real Dock's calls (dtrace: cid, proc, type, ctx); the callback's parameters are a GUESS (community prototype) */
	CGError (*SetUniversalOwner)(SLCid cid);                                                                           /* called once by the real Dock; second argument unknown */
	CGError (*EnableWindowModificationNotifications)(SLCid cid, int enable);                                           /* SLSPackagesEnableConnectionWindowModificationNotifications */
	CGError (*EnableOcclusionNotifications)(SLCid cid, int enable);                                                    /* SLSPackagesEnableConnectionOcclusionNotifications */
} SkyLightAPI;
/* returns NULL when SkyLight cannot be loaded */
const SkyLightAPI *SkyLightLoad(void);
