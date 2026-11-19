#import "CCGlass.h"
#import <objc/message.h>
/* the values the system sets on the glassBackground filter of a regular glass (Solarium docs/REAL-GLASS-VALUES.md, macOS 27.0, 340 x 200 and 120 x 120; 26.7.2 has 55 of the 77 keys: the others are ignored) */
static void setKeys(id f, BOOL small)
{
	NSDictionary *k = @{ @"SourceSublayerName": @0, @"InnerRefractionAmount": @-60, @"InnerRefractionHeight": @20, @"OuterRefractionAmount": small ? @30 : @50, @"OuterRefractionHeight": small ? @24 : @40,
		@"RefractionDistance0": @-1, @"RefractionDistance1": @0, @"RefractionOpacity": @0.6, @"BlurRadius": @5,
		@"BlurOpacity0": small ? @0.4666666 : @0.8, @"BlurOpacity1": small ? @0.2333333 : @0.4, @"BlurOpacity2": @0.5, @"BlurOpacity3": @1, @"BlurDistance0": small ? @-60 : @-100, @"BlurDistance1": @-1, @"BlurDistance2": @0, @"BlurDistance3": @0,
		@"FaceOpacity": @1, @"FaceColorMatrixWhite": @1.125, @"FaceColorMatrixBlack": @0.125, @"FaceColorMatrixSaturation": @1.3, @"FaceColorMatrixMaxLuma": @0.45, @"FaceColorMatrixMaxLumaSDR": @0.45,
		@"BleedAmount": small ? @42 : @70, @"BleedHeight": small ? @42 : @70, @"BleedBlurRadius": small ? @42 : @70, @"BleedDistance0": @1, @"BleedDistance1": @0, @"BleedOpacity": small ? @0.4666667 : @0.8, @"BleedDarkenBlend": @0,
		@"BleedColorMatrixWhite": @0.5, @"BleedColorMatrixBlack": @0.125, @"BleedColorMatrixSaturation": @1,
		@"ShadowAmount": @0, @"ShadowHeight": @0, @"ShadowOpacity": small ? @0.3666666 : @0.6, @"ShadowColorMatrixWhite": @1, @"ShadowColorMatrixBlack": @0, @"ShadowColorMatrixSaturation": @1, @"ShadowDistanceOffset": @0, @"ShadowBlurRadius": @0, @"ShadowRadius": small ? @15.66666666666667 : @24,
		@"RingShadowOffset": @8, @"RingShadowStrokeWidth": @4, @"RingShadowBlurRadius": @5, @"RingShadowOpacity": @0.06, @"RingShadowMask": @1,
		@"KeyFillHighlightHeight": @1, @"KeyFillHighlightAngle": @1.570796326794897, @"KeyFillHighlightSpread": @1.308996938995747, @"KeyFillHighlightSpreadSDR": @1.308996938995747, @"KeyFillHighlightAmount": @0.4, @"KeyFillHighlightEffectOffset": @-1, @"KeyFillHighlightColorBias": @-0.25,
		@"BlurFillBlurRadius": @8, @"BlurFillLightenOpacity": @0, @"BlurFillDarkenOpacity": @0.675, @"BlurFillNormalOpacity": @0, @"SDRHoldingToneEnabled": @0, @"SDRHoldingToneWhite": @1, @"SDRGradientDistance0": @0, @"SDRGradientDistance1": @0, @"SDRShadowOpacity": @0,
		@"MaxHeadroom": @9999, @"ShadowVibrancyContribution": @0, @"Clamp": @1.308311, @"ClampPreserveHue": @0 };
	for (NSString *name in k) [f setValue: k[name] forKey: [@"input" stringByAppendingString: name]];
	[f setValue: [NSValue valueWithSize: NSMakeSize(0, 8)] forKey: @"inputShadowOffset"];
}
CALayer *CCGlassLayer(CGRect frame, CGFloat radius)
{
	Class Back = NSClassFromString(@"CABackdropLayer"), SDF = NSClassFromString(@"CASDFLayer"), Elem = NSClassFromString(@"CASDFElementLayer"), Filter = NSClassFromString(@"CAFilter"), Out = NSClassFromString(@"CASDFOutputEffect"), Key = NSClassFromString(@"CASDFKeyFillHighlightEffect");
	if (!Back || !SDF || !Elem || !Filter || !Out || !Key) return nil;
	CGRect b = CGRectMake(0, 0, frame.size.width, frame.size.height);
	CALayer *container = [CALayer layer]; container.frame = frame;
	CALayer *backdrop = [Back layer]; backdrop.frame = b;
	id gf = [Filter filterWithType: @"glassBackground"]; setKeys(gf, MIN(frame.size.width, frame.size.height) < 160); backdrop.filters = @[ gf ];
	[(id)backdrop setValue: @YES forKey: @"windowServerAware"];
	CALayer *sdf = [SDF layer]; sdf.frame = b; id eff = [[Out alloc] init]; [eff setValue: @-10000 forKey: @"minimum"]; [eff setValue: @39.83030308810147 forKey: @"maximum"];
	[sdf setValue: eff forKey: @"effect"]; [sdf setValue: @8 forKey: @"smoothness"]; [sdf setValue: @0 forKey: @"gaussianRadius"];
	CALayer *holder = [CALayer layer]; holder.frame = CGRectZero;
	CALayer *el = [Elem layer]; el.frame = b; el.cornerRadius = radius; [el setValue: @"bounds" forKey: @"mode"]; [el setValue: @"union" forKey: @"operation"];
	[holder addSublayer: el]; [sdf addSublayer: holder]; [backdrop addSublayer: sdf]; [container addSublayer: backdrop];
	CALayer *hi = [SDF layer]; hi.frame = b; id ke = [[Key alloc] init]; [hi setValue: ke forKey: @"effect"]; [container addSublayer: hi];
	return container;
}
