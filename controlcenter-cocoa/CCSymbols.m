#import "CCSymbols.h"
#import <objc/message.h>
#import <dlfcn.h>
#import <unistd.h>
static const char *kPaths[2] = { "/System/Library/CoreServices/CoreGlyphs.bundle/Contents/Resources/Assets.car", "/System/Library/CoreServices/CoreGlyphsPrivate.bundle/Contents/Resources/Assets.car" };
static id catalog(int which)
{
	static id cur; static int curWhich = -1; if (curWhich == which) return cur;
	cur = nil; curWhich = which;                                                 // the previous catalog is released before the other one is opened
	void *h = dlopen("/System/Library/PrivateFrameworks/CoreUI.framework/CoreUI", RTLD_LAZY); Class C = h ? NSClassFromString(@"CUICatalog") : nil; if (!C) return nil;
	if (access(kPaths[which], R_OK) != 0) return nil;
	cur = ((id (*)(id, SEL, id, NSError **))objc_msgSend)([C alloc], sel_registerName("initWithURL:error:"), [NSURL fileURLWithPath: [NSString stringWithUTF8String: kPaths[which]]], NULL);
	return cur;
}
CGImageRef CCSymbolImage(NSString *name, CGFloat pointSize, CGFloat grey, CGFloat alpha) { return CCSymbolImageRGB(name, pointSize, grey, grey, grey, alpha); }
CGImageRef CCSymbolImageRGB(NSString *name, CGFloat pointSize, CGFloat gr, CGFloat gg, CGFloat gb, CGFloat alpha)
{
	static NSMutableDictionary *cache; if (!cache) cache = [NSMutableDictionary dictionary];
	NSString *key = [NSString stringWithFormat: @"%@|%.1f|%.0f,%.0f,%.0f|%.2f", name, pointSize, gr, gg, gb, alpha]; id hit = cache[key]; if (hit) return hit == [NSNull null] ? NULL : (__bridge CGImageRef)hit;
	CGImageRef img = NULL;
	for (int w = 0; w < 2 && !img; w++) {
		id cat = catalog(w); if (!cat) continue;
		id g = ((id (*)(id, SEL, id, double, long, long, long, long, double, id))objc_msgSend)(cat, sel_registerName("namedVectorGlyphWithName:scaleFactor:deviceIdiom:layoutDirection:glyphSize:glyphWeight:glyphPointSize:appearanceName:"), name, 2.0, 0L, 0L, 2L, 7L, (double)pointSize, @"NSAppearanceNameDarkAqua");
		if (!g) continue;
		CGFloat k[4] = { gr / 255, gg / 255, gb / 255, alpha }; CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB(); CGColorRef tint = CGColorCreate(cs, k); CGColorSpaceRelease(cs);
		img = ((CGImageRef (*)(id, SEL, id, double, CGSize))objc_msgSend)(g, sel_registerName("rasterizeImageWithTintColor:usingScaleFactor:forTargetSize:"), (__bridge id)tint, 2.0, CGSizeMake(pointSize, pointSize));
		CGColorRelease(tint); if (img) CGImageRetain(img);
	}
	if (!img && getenv("CC_SYMDEBUG")) NSLog(@"cc: symbol %@ not found", name);
	cache[key] = img ? (__bridge_transfer id)img : (id)[NSNull null];
	return img;
}
