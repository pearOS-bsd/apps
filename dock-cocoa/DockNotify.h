/* Notifications of the window server to the Dock's connection (SLSRegisterConnectionNotifyProc).  The real Dock registers these types at startup (dtrace, 2026-11-16):
 * 906 907 904 905 102 103 | 1500-1503 | 106 107 763 764 | 750 751 | 1411-1414 1418-1422 | 119; before that it enables the window-modification and occlusion notifications and calls SLSSetUniversalOwner.
 * Which type is "minimize this window" is being found out: every notification is logged to /tmp/dock-notify.log while /tmp/dock-notify.debug exists. */
#import <Foundation/Foundation.h>
void DockNotifyStart(void);
