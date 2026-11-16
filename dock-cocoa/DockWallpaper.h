/* The wallpaper: the real Dock draws it in its second window (display size, level -2147483624, SLSNewWindow...options 1).  Configuration: ~/Library/Application Support/com.apple.wallpaper/Store/Index.plist
 * (AllSpacesAndDisplays / SystemDefault -> Linked -> Content -> Choices[0] -> Provider and Files). Skeleton: a picture file when the configuration names one; the "default" provider is the system's dynamic
 * wallpaper, which the real stack resolves through the Wallpaper / DynamicDesktop frameworks: NOT done, a plain colour stands in (white, what the real Dock shows on the Mac VM where that asset is not downloaded). */
#import <QuartzCore/QuartzCore.h>
CALayer *DockWallpaperLayer(CGSize display);
