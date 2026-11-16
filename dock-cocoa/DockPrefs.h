/* The preferences of the Dock (domain com.apple.dock), read through CFPreferences (cfprefsd) exactly like the real Dock: same keys, same order.
 * Evidence: research/dock-trace/real-dock-startup-macos26.7.2.txt (the PREF lines).  The defaults of the real Dock are NOT known yet (docs/development/DOCK-CONFIG.md):
 * a key that is not set reads as nil here and the consumer decides, until the defaults are traced. */
#import <Foundation/Foundation.h>
@interface DockPrefs : NSObject
@property (readonly) NSDictionary<NSString *, id> *values;      /* key -> value (only keys that are set) */
- (instancetype)initFromPreferences;                            /* reads every key of +keys in the order of the real Dock */
- (void)readSystemKeys;                                          /* the keys of other domains the real Dock reads at startup (ImageIO, Siri) */
+ (NSArray<NSString *> *)keys;
+ (void)setValue:(id)value forKey:(NSString *)key;                 /* CFPreferencesSetAppValue + AppSynchronize in com.apple.dock (through cfprefsd, like the real Dock) */
@end
