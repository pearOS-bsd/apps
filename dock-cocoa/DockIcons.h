/* Icons of the tiles through IconServices, the way the real Dock does it (dtrace: ISBundleIcon initWithBundleURL:, ISImageDescriptor initWithSize:scale:, ISIcon prepareImagesForImageDescriptors: ...).
 * IconServices is a private framework: loaded at run time (dlopen), classes called through the Objective-C runtime; on pearOS the same names are served by the IconServices repository. */
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
/* the icon of an application bundle / a file type, `points` square, `scale` 1 or 2; NULL when IconServices is not there. Caller releases. */
CGImageRef DockCopyBundleIcon(NSString *bundlePath, CGFloat points, CGFloat scale);
CGImageRef DockCopyTypeIcon(NSString *uti, CGFloat points, CGFloat scale);        /* e.g. public.folder, com.apple.trash-empty */
/* asynchronous: the completion runs when IconServices has the image (the first ask of an icon that is not cached returns nothing); completion gets NULL on failure */
typedef void (^DockIconCompletion)(CGImageRef image);
void DockLoadBundleIcon(NSString *bundlePath, CGFloat points, CGFloat scale, DockIconCompletion done);
void DockLoadTypeIcon(NSString *uti, CGFloat points, CGFloat scale, DockIconCompletion done);
void DockLoadIcnsIcon(NSString *icnsPath, CGFloat points, CGFloat scale, DockIconCompletion done);      /* ISIcnsIcon initWithContentOfURL: (the Trash and the Downloads folder of CoreTypes.bundle) */
