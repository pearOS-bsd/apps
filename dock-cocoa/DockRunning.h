/* The running applications the Dock shows (the middle section and the dots): LaunchServices, like the real Dock (it talks to coreservices.launchservicesd and lsd.mapdb).
 * Private API, resolved at run time: _LSCopyRunningApplicationArray(0xFFFFFFFE) lists the application serial numbers (0xFFFFFFFF and 0 return nothing: tried on 26.7.2),
 * _LSCopyApplicationInformation(-2, asn, NULL) gives LSDisplayName, LSBundlePath, CFBundleIdentifier, ApplicationType (Foreground / UIElement / BackgroundOnly).  The Dock shows Foreground ones. */
#import <Foundation/Foundation.h>
NSArray<NSDictionary *> *DockRunningApplications(void);      /* [{name, path, bundleIdentifier}] of the Foreground applications, in LaunchServices' order */
