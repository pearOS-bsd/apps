#import "SkyLightAPI.h"
#import <dlfcn.h>
const SkyLightAPI *SkyLightLoad(void)
{
	static SkyLightAPI api; static int tried;
	if (tried) return api.MainConnectionID ? &api : NULL;
	tried = 1;
	void *h = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY);
	if (!h) h = dlopen("libSkyLight.so", RTLD_LAZY);                       /* pearOS: the SkyLight repository's client library */
	if (!h) return NULL;
	api.MainConnectionID = dlsym(h, "SLSMainConnectionID");
	api.NewRegionWithRect = dlsym(h, "CGSNewRegionWithRect");
	api.NewWindowWithOpaqueShapeAndContext = dlsym(h, "SLSNewWindowWithOpaqueShapeAndContext");
	api.SetWindowLevel = dlsym(h, "SLSSetWindowLevel");
	api.OrderWindow = dlsym(h, "SLSOrderWindow");
	api.ReleaseWindow = dlsym(h, "SLSReleaseWindow");
	return api.MainConnectionID ? &api : NULL;
}
