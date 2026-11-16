#import "DockNotify.h"
#import "SkyLightAPI.h"
static void onNotify(uint32_t type, void *data, size_t length, void *ctx, SLCid cid)
{
	if (access("/tmp/dock-notify.debug", F_OK) != 0) return;
	FILE *f = fopen("/tmp/dock-notify.log", "a"); if (!f) return;
	fprintf(f, "type %u length %zu data", type, length); const unsigned char *b = data; for (size_t i = 0; b && i < length && i < 96; i++) fprintf(f, " %02x", b[i]); fputc(10, f); fclose(f);
}
void DockNotifyStart(void)
{
	const SkyLightAPI *sl = SkyLightLoad(); if (!sl || !sl->RegisterConnectionNotifyProc) return;
	SLCid cid = sl->MainConnectionID();
	if (sl->EnableWindowModificationNotifications) sl->EnableWindowModificationNotifications(cid, 1);
	/* SLSPackagesEnableConnectionOcclusionNotifications(cid, 1) crashes with this prototype (it reads a pointer argument that is not (cid, int)): NOT called until its real signature is known */
	if (sl->SetUniversalOwner) sl->SetUniversalOwner(cid);
	/* every type the real Dock registers, plus a wide range while the minimize notification is unknown (the debug file switches the logging on) */
	for (uint32_t t = 100; t < 1600; t++) sl->RegisterConnectionNotifyProc(cid, onNotify, t, NULL);
}
