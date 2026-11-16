#import "DockView.h"
#import "../dock/dock_layout.h"
#import "DockIcons.h"
CALayer *DockBuildLayers(DockModel *model, CGSize display)
{
	CALayer *root = [CALayer layer]; root.frame = CGRectMake(0, 0, display.width, display.height); root.geometryFlipped = YES;       /* top-left origin like SkyLight */
	CALayer *bar = [CALayer layer]; bar.frame = model.barRect; bar.cornerRadius = 20;
	CGColorRef dark = CGColorCreateGenericRGB(0.13, 0.13, 0.13, 0.78); bar.backgroundColor = dark; CGColorRelease(dark);
	[root addSublayer: bar];
	for (DockTile *t in model.tiles) {
		if (t.kind == DOCK_SEPARATOR) {
			CALayer *l = [CALayer layer]; l.frame = CGRectMake(CGRectGetMidX(t.frame) - 0.5, CGRectGetMinY(t.frame) + 10, 1, t.frame.size.height - 20);
			CGColorRef c = CGColorCreateGenericRGB(1, 1, 1, 0.25); l.backgroundColor = c; CGColorRelease(c); [root addSublayer: l]; continue;
		}
		CALayer *l = [CALayer layer]; CGFloat a = t.art > 0 ? t.art : model.tileSize * 0.81;
		l.frame = CGRectMake(CGRectGetMidX(t.frame) - a / 2, CGRectGetMinY(t.frame) + 10 + (model.tileSize - a) / 2, a, a); l.cornerRadius = a * 0.22;
		CGColorRef c = t.kind == DOCK_TRASH ? CGColorCreateGenericRGB(0.7, 0.7, 0.7, 1) : t.kind == DOCK_OTHER ? CGColorCreateGenericRGB(0.3, 0.6, 0.9, 1) : CGColorCreateGenericRGB(0.9, 0.9, 0.95, 1);
		l.backgroundColor = c; CGColorRelease(c);
		DockIconCompletion done = ^(CGImageRef im) {
			if (getenv("DOCK_LOG")) NSLog(@"dock: icon %@ -> %@", t.path ?: @"(type)", im ? [NSString stringWithFormat: @"%zux%zu", CGImageGetWidth(im), CGImageGetHeight(im)] : @"NONE");
			if (!im) return; CGImageRetain(im);
			dispatch_async(dispatch_get_main_queue(), ^{
				[CATransaction begin]; [CATransaction setDisableActions: YES];
				l.contents = (__bridge id)im; l.backgroundColor = NULL; l.cornerRadius = 0; l.contentsGravity = kCAGravityResizeAspect;      /* the placeholder stays where IconServices gives nothing */
				[CATransaction commit]; [CATransaction flush]; CGImageRelease(im);
			});
		};
		/* the Trash and the Downloads folder: icns of CoreTypes.bundle (ISTypeIcon with a trash type gives a "?" document: tried com.apple.trash and com.apple.trash-empty on 26.7.2); other folders: ISTypeIcon public.folder */
		NSString *ct = @"/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/";
		if (t.kind == DOCK_TRASH) DockLoadIcnsIcon([ct stringByAppendingString: @"TrashIcon.icns"], a, 2, done);
		else if (t.kind == DOCK_OTHER && [t.path.lastPathComponent isEqualToString: @"Downloads"]) DockLoadIcnsIcon([ct stringByAppendingString: @"DownloadsFolder.icns"], a, 2, done);
		else if (t.kind == DOCK_OTHER) DockLoadTypeIcon(@"public.folder", a, 2, done);
		else DockLoadBundleIcon(t.path, a, 2, done);
		[root addSublayer: l];
	}
	return root;
}
