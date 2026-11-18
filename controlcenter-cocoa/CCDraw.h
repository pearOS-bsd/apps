/* Drawing helpers for the panel and the gallery (Core Graphics + Core Text, screen coordinates with y down: the caller flips the context). */
#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
BOOL CCDarkTheme(void);                                  /* SLSGetAppearanceThemeLegacy */
void CCSetDarkTheme(BOOL dark);                          /* SLSSetAppearanceThemeLegacy */
CGContextRef CCBeginBitmap(CGSize size, CGPoint origin); /* device RGB bitmap, screen coordinates (origin = the screen position of the bitmap's top-left) */
CGImageRef CCEndBitmap(CGContextRef c);
void CCFillGrey(CGContextRef c, CGFloat v, CGFloat a);   /* fill and stroke colour from a grey value 0..255 (device RGB: equal to the screenshot's pixels) */
void CCFillRGB(CGContextRef c, int r, int g, int b);
void CCRRect(CGContextRef c, CGRect r, CGFloat radius);  /* adds the path */
void CCFillRRect(CGContextRef c, CGRect r, CGFloat radius, CGFloat grey);
void CCFillDisc(CGContextRef c, CGPoint ctr, CGFloat diameter, CGFloat grey);
void CCText(CGContextRef c, NSString *s, CGFloat x, CGFloat baseline, CGFloat size, BOOL bold, CGFloat grey, CGFloat align);   /* align 0 left, 0.5 centre, 1 right */
double CCTextWidth(NSString *s, CGFloat size, BOOL bold);
/* named vector glyphs drawn with the current fill/stroke colour, centred on ctr, roughly `size` points wide */
void CCGlyph(CGContextRef c, NSString *name, CGPoint ctr, CGFloat size);

/* Puts a large image on a layer as horizontal bands (sublayers of bandHeight rows).  A layer with one big CGImage (the 656 x 964 panel) did not reach the render server of pearOS at all
 * (its commit never arrived: images of this size are handled differently by CoreAnimation); bands of ~80 KB travel like the small images of the status items.  Harmless on a Mac. */
#import <QuartzCore/QuartzCore.h>
void CCSetBandedContents(CALayer *layer, CGImageRef img, int bandHeight);
void CCSetBandedContentsFade(CALayer *layer, CGImageRef img, int bandHeight, BOOL fade);     /* fade: a cross-fade of the bands (0.15 s) for a change the user made */
