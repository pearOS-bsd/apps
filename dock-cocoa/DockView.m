#import "DockView.h"
#import "../dock/dock_layout.h"
#import "DockIcons.h"
#import <CoreText/CoreText.h>
CALayer *DockBuildLayers(DockModel *model, CGSize display)
{
	/* the backing scale of the display: the icons are asked for at that scale (2x images squeezed into 1x pixels look jagged) */
	CGDirectDisplayID did = CGMainDisplayID(); CGFloat scale = CGDisplayBounds(did).size.width > 0 ? (CGFloat)CGDisplayPixelsWide(did) / CGDisplayBounds(did).size.width : 1; if (scale < 1) scale = 1;
	CALayer *root = [CALayer layer]; root.frame = CGRectMake(0, 0, display.width, display.height); root.geometryFlipped = YES;       /* top-left origin like SkyLight */
	BOOL side = model.orientation != 0;           /* the Dock on the left or on the right edge: tiles run top to bottom */
	CALayer *bar = [CALayer layer]; bar.frame = model.barRect; bar.cornerRadius = side ? 16 : 20;       /* the side radius is a guess */
	CGColorRef dark = CGColorCreateGenericRGB(0, 0, 0, 0.906);      /* matches the real bar over a white desktop (pixel 24); the real one is a blurred material, so on other backgrounds it differs */ bar.backgroundColor = dark; CGColorRelease(dark);
	[root addSublayer: bar];
	for (DockTile *t in model.tiles) {
		if (t.kind == DOCK_SEPARATOR) {
			CALayer *l = [CALayer layer]; l.frame = side ? CGRectMake(CGRectGetMinX(model.barRect) + 8, CGRectGetMidY(t.frame) - 0.5, model.barRect.size.width - 16, 1) : CGRectMake(CGRectGetMidX(t.frame) - 0.5, CGRectGetMinY(t.frame) + 10, 1, t.frame.size.height - 20);
			CGColorRef c = CGColorCreateGenericRGB(1, 1, 1, 0.25); l.backgroundColor = c; CGColorRelease(c); [root addSublayer: l]; continue;
		}
		CALayer *l = [CALayer layer]; CGFloat a = model.tileSize;      /* the icon image is tilesize wide; its artwork is ~0.81 of it (measured: 38 px visible at tile size 46) */
		/* whole pixels: the real Dock's icons are crisp, a fractional origin blurs them (the items are 49.9 apart, the art is placed on the pixel grid) */
		CGFloat px = round(side ? CGRectGetMidX(model.barRect) - a / 2 : CGRectGetMidX(t.frame) - a / 2), py = round(side ? CGRectGetMidY(t.frame) - a / 2 : CGRectGetMinY(t.frame) + 10 + (model.tileSize - a) / 2); a = round(a);
		l.frame = CGRectMake(px, py, a, a); l.cornerRadius = a * 0.22;
		CGColorRef c = t.kind == DOCK_TRASH ? CGColorCreateGenericRGB(0.7, 0.7, 0.7, 1) : t.kind == DOCK_OTHER ? CGColorCreateGenericRGB(0.3, 0.6, 0.9, 1) : CGColorCreateGenericRGB(0.9, 0.9, 0.95, 1);
		l.backgroundColor = c; CGColorRelease(c);
		DockIconCompletion done = ^(CGImageRef im) {
			if (getenv("DOCK_LOG")) NSLog(@"dock: icon %@ -> %@", t.path ?: @"(type)", im ? [NSString stringWithFormat: @"%zux%zu", CGImageGetWidth(im), CGImageGetHeight(im)] : @"NONE");
			if (!im) return; CGImageRetain(im);
			dispatch_async(dispatch_get_main_queue(), ^{
				[CATransaction begin]; [CATransaction setDisableActions: YES];
				l.contentsScale = scale; l.minificationFilter = kCAFilterTrilinear; l.magnificationFilter = kCAFilterLinear; l.contents = (__bridge id)im; l.backgroundColor = NULL; l.cornerRadius = 0; l.contentsGravity = kCAGravityResizeAspect;      /* the placeholder stays where IconServices gives nothing */
				[CATransaction commit]; [CATransaction flush]; CGImageRelease(im);
			});
		};
		/* the Trash and the Downloads folder: icns of CoreTypes.bundle (ISTypeIcon with a trash type gives a "?" document: tried com.apple.trash and com.apple.trash-empty on 26.7.2); other folders: ISTypeIcon public.folder */
		NSString *ct = @"/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/";
		if (t.kind == DOCK_TRASH) DockLoadIcnsIcon([ct stringByAppendingString: @"TrashIcon.icns"], a, scale, done);
		else if (t.kind == DOCK_OTHER && [t.path.lastPathComponent isEqualToString: @"Downloads"]) DockLoadIcnsIcon([ct stringByAppendingString: @"DownloadsFolder.icns"], a, scale, done);
		else if (t.kind == DOCK_OTHER) DockLoadTypeIcon(@"public.folder", a, scale, done);
		else DockLoadBundleIcon(t.path, a, scale, done);
		t.iconLayer = l; [root addSublayer: l];
		if (t.badge.length) {          /* the badge: measured on the real Dock (System Settings, 17 px red circle: x = icon right - 19, y = icon top, colour 244 63 53) */
			CGFloat d = 17; CALayer *b = [CALayer layer]; b.frame = CGRectMake(px + a - d - 2, py, d, d); b.cornerRadius = d / 2;
			CGColorRef red = CGColorCreateGenericRGB(244 / 255.0, 63 / 255.0, 53 / 255.0, 1); b.backgroundColor = red; CGColorRelease(red);
			CATextLayer *tx = [CATextLayer layer]; tx.string = t.badge; tx.fontSize = 12; tx.alignmentMode = kCAAlignmentCenter; tx.contentsScale = 1;
			CTFontRef bf = CTFontCreateUIFontForLanguage(kCTFontUIFontEmphasizedSystem, 12, NULL); tx.font = bf; CFRelease(bf);
			CGColorRef wh = CGColorCreateGenericRGB(1, 1, 1, 1); tx.foregroundColor = wh; CGColorRelease(wh); tx.frame = CGRectMake(0, 1.5, d, d - 2); [b addSublayer: tx]; [root addSublayer: b];
		}
		if (t.running) {           /* the dot under a running application */
			CALayer *dot = [CALayer layer]; dot.frame = side ? CGRectMake((model.orientation == 1 ? CGRectGetMinX(model.barRect) + 5 : CGRectGetMaxX(model.barRect) - 5) - 2, CGRectGetMidY(t.frame) - 2, 4, 4) : CGRectMake(CGRectGetMidX(t.frame) - 2, CGRectGetMinY(t.frame) + t.frame.size.height - 6.5, 4, 4); dot.cornerRadius = 2;       /* a side Dock: the dot is on the outer edge */
			CGColorRef w = CGColorCreateGenericRGB(1, 1, 1, 0.85); dot.backgroundColor = w; CGColorRelease(w); [root addSublayer: dot];
		}
	}
	return root;
}
