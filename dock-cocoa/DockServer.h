/* The Mach services the Dock PROVIDES (com.apple.dock.server first): check in with the bootstrap server and receive. The launchd job must declare the names in MachServices
 * (research/dock-trace/dock-switch.sh does).  First step: every message is logged (id, size, the first bytes) to /tmp/dock-server.log so that the protocol can be read from real clients (AppKit asks the
 * Dock to minimize a window); no reply is sent yet. */
#import <Foundation/Foundation.h>
void DockServerStart(const char *serviceName);
