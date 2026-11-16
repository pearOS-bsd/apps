#import "DockWallpaper.h"
#import <ImageIO/ImageIO.h>
CALayer *DockWallpaperLayer(CGSize display)
{
	CALayer *root = [CALayer layer]; root.frame = CGRectMake(0, 0, display.width, display.height);
	NSString *idx = [NSHomeDirectory() stringByAppendingPathComponent: @"Library/Application Support/com.apple.wallpaper/Store/Index.plist"];
	NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile: idx];
	NSDictionary *content = d[@"AllSpacesAndDisplays"][@"Linked"][@"Content"] ?: d[@"SystemDefault"][@"Linked"][@"Content"];
	NSDictionary *choice = [content[@"Choices"] firstObject];
	NSString *file = [[choice[@"Files"] firstObject] isKindOfClass: [NSDictionary class]] ? [choice[@"Files"] firstObject][@"relative"] : nil;      /* shape of a file entry: UNVERIFIED (none on this Mac) */
	CGImageRef img = NULL;
	if (file.length) { NSURL *u = [NSURL URLWithString: file] ?: [NSURL fileURLWithPath: file]; CGImageSourceRef src = CGImageSourceCreateWithURL((__bridge CFURLRef)u, NULL); if (src) { img = CGImageSourceCreateImageAtIndex(src, 0, NULL); CFRelease(src); } }
	if (img) { root.contents = (__bridge id)img; root.contentsGravity = kCAGravityResizeAspectFill; CGImageRelease(img); }
	else { CGColorRef w = CGColorCreateGenericRGB(1, 1, 1, 1); root.backgroundColor = w; CGColorRelease(w); }       /* TODO(feature): the "default" provider */
	return root;
}
