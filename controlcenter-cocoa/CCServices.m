/* The Mach services of the real ControlCenter at startup, in the order of the trace (research/cc-trace/real-controlcenter-startup-macos26.7.2.txt, macOS 26.7.2).
 * LOOKUP = bootstrap_look_up, XPC = connection to a service (resumed, errors ignored), LISTEN = a service ControlCenter provides (declared in its launchd plist, com.apple.controlcenter).
 * Most of the clients are made by frameworks in the real process (TODO(feature): they come back by themselves when the framework behind them is used here). */
#import "CCServices.h"
#import <xpc/xpc.h>
#import <mach/mach.h>
#import <servers/bootstrap.h>
static NSMutableArray *conns;
static void look(const char *name) { mach_port_t p = MACH_PORT_NULL; bootstrap_look_up(bootstrap_port, name, &p); }
static void xpc(const char *name)
{
	xpc_connection_t c = xpc_connection_create_mach_service(name, NULL, 0);
	xpc_connection_set_event_handler(c, ^(xpc_object_t e) { (void)e; });
	xpc_connection_resume(c);
	[conns addObject: (id)c];
}
static void listen(const char *name)
{
	xpc_connection_t c = xpc_connection_create_mach_service(name, NULL, XPC_CONNECTION_MACH_SERVICE_LISTENER);
	xpc_connection_set_event_handler(c, ^(xpc_object_t peer) {
		if (xpc_get_type(peer) != XPC_TYPE_CONNECTION) return;
		xpc_connection_set_event_handler((xpc_connection_t)peer, ^(xpc_object_t m) { (void)m; });
		xpc_connection_resume((xpc_connection_t)peer);
	});
	xpc_connection_resume(c);
	[conns addObject: (id)c];
}
@implementation CCServices
+ (void)connectAll
{
	conns = [NSMutableArray array];
	look("com.apple.system.notification_center");
	look("com.apple.logd");
	xpc("com.apple.cfprefsd.daemon");
	xpc("com.apple.cfprefsd.agent");
	xpc("com.apple.analyticsd");
	xpc("com.apple.coreservices.launchservicesd");
	xpc("com.apple.pasteboard.1");
	xpc("com.apple.distributed_notifications@Uv3");
	xpc("com.apple.tccd.system");
	look("com.apple.CARenderServer");
	xpc("com.apple.backlightd");
	look("com.apple.CoreServices.coreservicesd");
	xpc("com.apple.lsd.modifydb");
	xpc("com.apple.lsd.mapdb");
	xpc("com.apple.runningboard");
	look("com.apple.dock.server");
	xpc("com.apple.linkd.autoShortcut");
	look("com.apple.windowserver.active");
	xpc("com.apple.AirPlayXPCHelper");
	xpc("com.apple.ProgressReporting");
	xpc("com.apple.siri.VoiceShortcuts.xpc");
	xpc("com.apple.powerui.smartChargeManager");
	look("com.apple.PowerManagement.control");
	look("com.apple.SystemConfiguration.configd");
	xpc("com.apple.locationd.desktop.registration");
	look("com.apple.CoreLocation.agent");
	xpc("com.apple.locationd-events");
	xpc("com.apple.proactive.PersonalizationPortrait.SocialHighlight");
	xpc("com.apple.sociallayerd");
	xpc("com.apple.tccd");
	xpc("com.apple.telephonyutilities.callservicesdaemon.callcapabilities");
	xpc("com.apple.remindd");
	xpc("com.apple.telephonyutilities.callservicesdaemon.conversationmanager");
	xpc("com.apple.AddressBook.ContactsAccountsService");
	xpc("com.apple.iconservices");
	xpc("com.apple.CalendarAgent");
	xpc("com.apple.iconservices.store");
	xpc("com.apple.cmio.registerassistantservice.system-extensions");
	xpc("com.apple.mediaremoted.xpc");
	xpc("com.apple.coremedia.routingcontext.xpc");
	xpc("com.apple.coremedia.volumecontroller.xpc");
	xpc("com.apple.coremedia.routediscoverer.xpc");
	xpc("com.apple.intelligentroutingd.xpc.media");
	xpc("com.apple.coremedia.endpoint.xpc");
	xpc("com.apple.HearingModeService");
	xpc("com.apple.locationd.desktop.synchronous");
	xpc("com.apple.systemstatus");
	xpc("com.apple.accountsd.accountmanager");
	xpc("com.apple.MobileTimer.timerserver");
	xpc("com.apple.system.opendirectoryd.api");
	listen("com.apple.controlcenter.show.toggles");
	xpc("com.apple.replayd");
	xpc("com.apple.containermanagerd");
	xpc("com.apple.cmio.registerassistantservice");
	look("com.apple.dockling.server");
	xpc("com.apple.backgroundtaskmanagement");
	xpc("com.apple.sharingd.nsxpc");
	listen("com.apple.controlcenter.controlcentermodule");
	listen("com.apple.controlcenter.statusitems");
	listen("com.apple.SystemBanner");
	listen("com.apple.SystemBannerService");
	xpc("com.apple.contactsd.persistence");
	xpc("com.apple.contacts.account-caching");
	xpc("com.apple.coreservices.appleevents");
	xpc("com.apple.xpc.activity");
	xpc("com.apple.FileCoordination");
	look("com.apple.DiskArbitration.diskarbitrationd");
	xpc("com.apple.AudioAccessoryServices");
	look("com.apple.system.logger");
	xpc("com.apple.dock.fullscreen");
	look("com.apple.fonts");
	xpc("com.apple.spotlight.IndexAgent");
}
@end
