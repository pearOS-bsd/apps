#import "CCSkyLight.h"
#import "../dock-cocoa/DockWindow.h"
#import "../dock-cocoa/SkyLightAPI.h"
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

void CCShowWindow(DockWindow *w, int level)
{
	const SkyLightAPI *sl = SkyLightLoad(); const CCSkyLight *cc = CCSkyLightLoad(); if (!sl || !w) return;
	int cid = sl->MainConnectionID(); uint32_t wid = w.windowID; CFTypeRef tx = sl->TransactionCreate(cid); if (!tx) return;
	uint64_t tags[1] = { 0 };
	if (cc->SetWindowTags) { cc->SetWindowTags(tx, wid, tags, 0x40, 0); cc->SetWindowTags(tx, wid, tags, 0x40, 1); }
	sl->TransactionSetWindowLevel(tx, wid, level); sl->TransactionOrderWindow(tx, wid, 1, 0); sl->TransactionCommit(tx, 1); CFRelease(tx);
}
