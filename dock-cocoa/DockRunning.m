#import "DockRunning.h"
#import <dlfcn.h>
NSArray<NSDictionary *> *DockRunningApplications(void)
{
	CFArrayRef (*run)(uint32_t) = dlsym(RTLD_DEFAULT, "_LSCopyRunningApplicationArray");
	CFDictionaryRef (*info)(int, CFTypeRef, CFArrayRef) = dlsym(RTLD_DEFAULT, "_LSCopyApplicationInformation");
	if (!run || !info) return @[];
	NSArray *asns = (__bridge_transfer NSArray *)run(0xFFFFFFFE); NSMutableArray *out = [NSMutableArray array];
	for (id asn in asns) {
		NSDictionary *d = (__bridge_transfer NSDictionary *)info(-2, (__bridge CFTypeRef)asn, NULL);
		if (![[d[@"ApplicationType"] description] isEqual: @"Foreground"]) continue;
		NSString *path = [d[@"LSBundlePath"] description]; if (!path.length) continue;
		NSString *label = nil; id sl = d[@"StatusLabel"];                 /* NSDockTile badgeLabel of the application: {label = "3"} */
		if ([sl isKindOfClass: [NSDictionary class]]) label = [sl[@"label"] description];
		else if ([sl isKindOfClass: [NSString class]]) { NSRange r = [sl rangeOfString: @"label\\s*=\\s*\"?([^\";} ]+)" options: NSRegularExpressionSearch]; if (r.location != NSNotFound) { NSString *m = [sl substringWithRange: r]; label = [[m componentsSeparatedByString: @"="].lastObject stringByTrimmingCharactersInSet: [NSCharacterSet characterSetWithCharactersInString: @" \""]]; } }
		[out addObject: @{ @"name": [d[@"LSDisplayName"] description] ?: path.lastPathComponent, @"path": path, @"bundleIdentifier": [d[@"CFBundleIdentifier"] description] ?: @"", @"badge": label ?: @"" }];
	}
	return out;
}
