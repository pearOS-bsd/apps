/* Liquid Glass built the way macOS 26 builds it (docs of github.com/pearOS-bsd/Solarium: INTEGRATION.md, REAL-GLASS-VALUES.md, RENDER-STREAM.md; the layer tree of NSGlassEffectView read on a real Mac):
 *   container CALayer
 *     CABackdropLayer  with the CAFilter "glassBackground" (the keys the system sets)
 *       CASDFLayer     (CASDFOutputEffect, smoothness 8)       the shape as a signed distance field
 *         CALayer
 *           CASDFElementLayer  (mode bounds, operation union, cornerRadius)
 *     CASDFLayer       (CASDFKeyFillHighlightEffect)            the lit rim
 * All the classes are Core Animation's (private, looked up by name): the window server draws the glass from the commit stream, as on the Mac. */
#import <QuartzCore/QuartzCore.h>
CALayer *CCGlassLayer(CGRect frame, CGFloat cornerRadius);     /* nil when the classes are missing */
