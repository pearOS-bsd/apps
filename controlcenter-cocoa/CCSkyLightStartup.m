/* The SkyLight calls the real ControlCenter makes at startup besides the window ones (research/cc-trace/sbargs3-real.txt: first-call arguments from dtrace; real process = AppKit + CoreGraphics make them).
 * Prototypes are generic here: (long x6), pointer arguments get a zeroed scratch buffer, so a wrong guess about an out parameter cannot write outside it.  Each entry: name + argument kinds
 * (C = connection id, D = main display id, P = pointer to scratch, number = literal).  TODO(verify): exact prototypes with REA on SkyLight, then replace by typed calls.  Hot-key registrations (SLSSetSymbolicHotKey*, SLSSetHotKey*)
 * are NOT made: they change the user's shortcuts. */
#import "CCSkyLightStartup.h"
#import "../dock-cocoa/SkyLightAPI.h"
#import <dlfcn.h>
#import <stdlib.h>

typedef long (*GenericFn)(long, long, long, long, long, long);
typedef struct { const char *name; const char *args[6]; } Call;
static const Call kCalls[] = {
	{ "SLSPackagesEnableConnectionWindowModificationNotifications", { "C", "1", "P" } },       /* a third argument (a pointer) in the real call: without it the function crashed */
	{ "SLSPackagesEnableConnectionOcclusionNotifications", { "C", "1", "P" } },
	{ "SLSSetKitVersion", { "4" } },
	{ "SLSGetEventPort", { "C", "P" } },
	{ "SLSGetGestureEventSubmask", { "C", "P" } },
	{ "SLSSetGestureEventSubmask", { "C", "0x2000000000000000" } },
	{ "SLSGetDenyWindowServerConnections", { "P" } },
	{ "SLSDisplayStatusQuery", { "D", "1" } },
	{ "SLSGetNumberOfDisplays", { "P" } },
	{ "SLSGetOnlineDisplayList", { "5", "P", "P" } },
	{ "SLSGetDisplayList", { "0x20", "P", "P" } },
	{ "SLSGetActiveDisplayList", { "0x20", "P", "P" } },
	{ "SLSGetDisplayBounds", { "D", "P" } },
	{ "SLSCopyDisplayColorSpace", { "D", "P" } },
	{ "SLSGetDisplayDepth", { "D", "P" } },
	{ "SLSCopyDisplayUUID", { "D", "P" } },
	{ "SLSGetDisplayAppleThemeLegacyRect", { "D", "P" } },
	{ "SLSGetDisplayMenubarHeight", { "D", "P" } },
	{ "SLSDisplayGetCapabilities", { "D" } },
	{ "SLSGetCurrentDisplayMode", { "D", "P" } },
	{ "SLSGetNumberOfDisplayModes", { "D", "P" } },
	{ "SLSGetDisplayModeDescriptionOfLength", { "D", "0", "P", "0xd4" } },
	{ "SLSDisplayGetCurrentHeadroom", { "D" } },
	{ "SLSDisplayGetPotentialHeadroom", { "D" } },
	{ "SLSDisplayGetReferenceHeadroom", { "D" } },
	{ "SLSDisplayGetPresetCount", { "D" } },
	{ "SLSIsDisplayModeProMotion", { "D", "0" } },
	{ "SLSIsDisplayModeVRR", { "D", "0" } },
	{ "SLSGetDisplayModeMinRefreshRate", { "D", "0", "P" } },
	{ "SLSDisplayGetTiming", { "P", "0", "D" } },
	{ "SLSGetDockRectWithOrientation", { "C", "P", "P", "P" } },
	{ "SLSGetMenuBarUseBlurredAppearance", { "P" } },
	{ "SLSServerMightHaveAcceleration", { "P" } },
	{ "SLSGetCurrentCursorLocation", { "C", "P" } },
	{ "SLSGetSessionUID", { "C", "P" } },
	{ "SLSGetBackgroundEventMask", { "C", "P" } },
	{ "SLSGetCoalesceEventsMask", { "C", "P" } },
	{ "SLSCoalesceEventsInMask", { "C", "0x20000000" } },
	{ "SLSGetSpaceManagementMode", { "C", "P" } },
	{ "SLSGetSpaceNeedsSafeAperture", { "C", "1", "3" } },
	{ "SLSSpaceGetType", { "C", "1" } },
	{ "SLSPersistenceGetSessionStatus", { "C", "P" } },
	{ "SLSGetLastUsedKeyboardID", { "P" } },
	{ "SLSInputModifierKeyState", { "0" } },
	{ "SLSSupportsSecureLayerValidation", { "P" } },
	{ "SLSServerOperationState", { "4" } },
	{ "SLSConnectionDispatchNotificationsToMainQueueIfNotMainThread", { "C", "1" } },
};

void CCSkyLightStartup(void)
{
	const SkyLightAPI *sl = SkyLightLoad(); if (!sl) return;
	void *h = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY); if (!h) h = dlopen("libSkyLight.so", RTLD_LAZY); if (!h) return;
	long cid = sl->MainConnectionID(); long disp = sl->MainDisplayID ? (long)sl->MainDisplayID() : 0;
	if (getenv("CC_SKIP_SLS")) return;
	for (size_t i = 0; i < sizeof kCalls / sizeof *kCalls; i++) {
		GenericFn f = dlsym(h, kCalls[i].name); if (!f) continue;
		void *scratch = calloc(1, 4096); long a[6] = { 0 };
		for (int k = 0; k < 6 && kCalls[i].args[k]; k++) {
			const char *s = kCalls[i].args[k];
			a[k] = s[0] == 'C' ? cid : s[0] == 'D' ? disp : s[0] == 'P' ? (long)scratch : strtol(s, NULL, 0);
		}
		(void)f(a[0], a[1], a[2], a[3], a[4], a[5]);
		free(scratch);
	}
}
