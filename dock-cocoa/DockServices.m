#import "DockServices.h"
#import <xpc/xpc.h>
#import <mach/mach.h>
#import <servers/bootstrap.h>
static void look(const char *name) { mach_port_t p = MACH_PORT_NULL; bootstrap_look_up(bootstrap_port, name, &p); }
static NSMutableArray *conns;
static void xpc(const char *name)
{
	xpc_connection_t c = xpc_connection_create_mach_service(name, NULL, 0);
	xpc_connection_set_event_handler(c, ^(xpc_object_t e) { (void)e; });
	xpc_connection_resume(c);
	[conns addObject: (id)c];
}
@implementation DockServices
+ (void)connectAll
{
	conns = [NSMutableArray array];
	look("com.apple.system.notification_center"); look("com.apple.logd");      /* TODO(feature): Foundation / os_log do this */
	xpc("com.apple.tccd.system"); xpc("com.apple.coreservices.launchservicesd"); xpc("com.apple.cfprefsd.daemon"); xpc("com.apple.cfprefsd.agent");
	look("com.apple.CARenderServer");                                           /* TODO(feature): QuartzCore, the render server of the window */
	xpc("com.apple.lsd.modifydb"); xpc("com.apple.distributed_notifications@Uv3"); xpc("com.apple.appsleep"); xpc("com.apple.analyticsd");
	look("com.apple.CoreServices.coreservicesd"); xpc("com.apple.lsd.mapdb"); look("com.apple.PowerManagement.control");
	look("com.apple.dock.server");                                              /* the real Dock looks up its own service before it checks in */
	xpc("com.apple.uninstall.service"); look("com.apple.windowserver.active"); xpc("com.apple.dock.notificationcenter");
	xpc("com.apple.dock.fullscreen"); xpc("com.apple.dock.spaces"); look("com.apple.fonts");
	xpc("com.apple.dock.remotedesktoppicture"); xpc("com.apple.wallpaper");
}
+ (void)checkInServer
{
	mach_port_t p = MACH_PORT_NULL; (void)bootstrap_check_in(bootstrap_port, "EyeCandyDiagnose", &p);
	p = MACH_PORT_NULL; (void)bootstrap_check_in(bootstrap_port, "com.apple.dock.server", &p);
	xpc("com.apple.coreservices.appleevents"); xpc("com.apple.usernoted.dock");
	xpc("com.apple.coreservices.sharedfilelistd.xpc"); xpc("com.apple.backgroundtaskmanagement"); xpc("com.apple.trustd.agent");
	xpc("com.apple.iconservices"); xpc("com.apple.iconservices.store"); xpc("com.apple.dmd.policy");
	xpc("com.apple.dock.sidecar"); xpc("com.apple.dock.ppt"); xpc("com.apple.windowmanager.external");
	xpc("com.apple.coreservices.lsbestappsuggestionmanager.xpc"); xpc("com.apple.ProgressReporting");
}
@end
