#import "DockIcons.h"
#import <objc/message.h>
#import <dlfcn.h>
static BOOL loaded;
static void load(void)
{
	if (loaded) return; loaded = YES;
	if (!dlopen("/System/Library/PrivateFrameworks/IconServices.framework/IconServices", RTLD_NOW)) dlopen("libIconServices.so", RTLD_NOW);   /* pearOS */
}
static CGImageRef render(id icon, CGFloat points, CGFloat scale)
{
	if (!icon) return NULL;
	Class D = NSClassFromString(@"ISImageDescriptor"); if (!D) return NULL;
	id d = ((id (*)(id, SEL, CGSize, double))objc_msgSend)([D alloc], sel_registerName("initWithSize:scale:"), CGSizeMake(points, points), scale);
	SEL s = sel_registerName("CGImageForImageDescriptor:"); if (!d || ![icon respondsToSelector: s]) return NULL;
	CGImageRef im = ((CGImageRef (*)(id, SEL, id))objc_msgSend)(icon, s, d);
	return im ? CGImageRetain(im) : NULL;
}
CGImageRef DockCopyBundleIcon(NSString *path, CGFloat points, CGFloat scale)
{
	load(); Class B = NSClassFromString(@"ISBundleIcon"); if (!B || !path) return NULL;
	id icon = ((id (*)(id, SEL, id))objc_msgSend)([B alloc], sel_registerName("initWithBundleURL:"), [NSURL fileURLWithPath: path]);
	return render(icon, points, scale);
}
CGImageRef DockCopyTypeIcon(NSString *uti, CGFloat points, CGFloat scale)
{
	load(); Class T = NSClassFromString(@"ISTypeIcon"); if (!T || !uti) return NULL;
	id icon = ((id (*)(id, SEL, id))objc_msgSend)([T alloc], sel_registerName("initWithType:"), uti);       /* ISTypeIcon initWithType: gives the folder icon for public.folder (checked on 26.7.2) */
	return render(icon, points, scale);
}

static void loadAsync(id icon, CGFloat points, CGFloat scale, DockIconCompletion done)
{
	Class D = NSClassFromString(@"ISImageDescriptor"); SEL s = sel_registerName("getCGImageForImageDescriptor:completion:");
	if (!icon || !D || ![icon respondsToSelector: s]) { done(NULL); return; }
	id d = ((id (*)(id, SEL, CGSize, double))objc_msgSend)([D alloc], sel_registerName("initWithSize:scale:"), CGSizeMake(points, points), scale);
	void (^cb)(CGImageRef) = ^(CGImageRef im) { done(im); };
	((void (*)(id, SEL, id, id))objc_msgSend)(icon, s, d, cb);
}
void DockLoadBundleIcon(NSString *path, CGFloat points, CGFloat scale, DockIconCompletion done)
{
	load(); Class B = NSClassFromString(@"ISBundleIcon"); if (!B || !path) { done(NULL); return; }
	loadAsync(((id (*)(id, SEL, id))objc_msgSend)([B alloc], sel_registerName("initWithBundleURL:"), [NSURL fileURLWithPath: path]), points, scale, done);
}
void DockLoadTypeIcon(NSString *uti, CGFloat points, CGFloat scale, DockIconCompletion done)
{
	load(); Class T = NSClassFromString(@"ISTypeIcon"); if (!T || !uti) { done(NULL); return; }
	loadAsync(((id (*)(id, SEL, id))objc_msgSend)([T alloc], sel_registerName("initWithType:"), uti), points, scale, done);
}
void DockLoadIcnsIcon(NSString *path, CGFloat points, CGFloat scale, DockIconCompletion done)
{
	load(); Class I = NSClassFromString(@"ISIcnsIcon"); if (!I || !path) { done(NULL); return; }
	loadAsync(((id (*)(id, SEL, id))objc_msgSend)([I alloc], sel_registerName("initWithContentOfURL:"), [NSURL fileURLWithPath: path]), points, scale, done);
}
