/* SF Symbols from the Mac's own glyph catalogs, read at run time with CoreUI (CUICatalog): /System/Library/CoreServices/CoreGlyphs.bundle (public symbols) and CoreGlyphsPrivate.bundle (private: bluetooth,
 * airdrop ...).  Apple's files are never stored in a repository: on a Mac they are the system's, on pearOS `macdeps` fetches them from the user's Mac to the same paths (CoreUI/README.md).
 * Finding (Mac VM 26.7.2): with both catalogs open at once the public one stops finding names, so only one CUICatalog is alive at a time (the images are cached by name and size). */
#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
CGImageRef CCSymbolImage(NSString *name, CGFloat pointSize, CGFloat grey, CGFloat alpha);      /* retained by the cache (do not release); NULL when the symbol does not exist */
