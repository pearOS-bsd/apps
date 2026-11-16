/* Owns what the Dock is: the preferences, the model, the windows, the content layers; rebuilds them when a preference changes (drag, resize, keep / remove). */
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import "DockPrefs.h"
#import "DockModel.h"
#import "DockWindow.h"
@interface DockController : NSObject
@property (readonly) DockPrefs *prefs;
@property (readonly) DockModel *model;
@property (readonly) CALayer *root;
@property (readonly) CGRect display;
- (void)start;
- (void)reload;                                          /* read the preferences again, rebuild the layers */
- (void)setPreference:(id)value forKey:(NSString *)key;  /* write (cfprefsd) and reload */
- (NSArray<NSDictionary *> *)persistentApps;             /* the tile dictionaries of the first section, in order (Finder is implicit and not in the file) */
- (void)setPersistentApps:(NSArray<NSDictionary *> *)apps;
@end
