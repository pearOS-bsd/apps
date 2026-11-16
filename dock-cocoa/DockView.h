/* The content of the Dock window: the bar and the tiles as Core Animation layers (no AppKit), built from the DockModel. Skeleton: the bar and a placeholder square per tile (the icons come from IconServices next). */
#import <QuartzCore/QuartzCore.h>
#import "DockModel.h"
CALayer *DockBuildLayers(DockModel *model, CGSize display);
