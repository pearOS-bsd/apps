#import "CCSkyLight.h"
#import <dlfcn.h>
const CCSkyLight *CCSkyLightLoad(void)
{
	static CCSkyLight a; static int tried;
	if (tried) return &a;
	tried = 1;
	void *h = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY);
	if (!h) h = dlopen("libSkyLight.so", RTLD_LAZY);
	if (!h) return &a;
	a.RegisterSortedWindow = dlsym(h, "SLSTransactionSystemStatusBarRegisterSortedWindow");
	a.SetWindowTags = dlsym(h, "SLSTransactionSetWindowTags");
	a.GetWindowPreferredPosition = dlsym(h, "SLSSystemStatusBarGetWindowPreferredPosition");
	a.SetWindowEventMask = dlsym(h, "SLSSetWindowEventMask");
	a.SetWindowTitle = dlsym(h, "SLSSetWindowTitle");
	a.SetWindowClientPerceivedType = dlsym(h, "SLSSetWindowClientPerceivedType");
	return &a;
}
