/* The layout of Control Center as the real one stores it (macOS 26 / 27, found by reading the preferences of a Mac, 2026-11-19):
 *   ~/Library/Preferences/ByHost/com.apple.controlcenter.bentoboxes.<host>.plist
 *     boxes = JSON (Data): [ { menuBarIconName, grid: { width 4, maxHeight 8, elements: [ { id {rawValue UUID}, location {x, y}, size { square1x1 | rect2x1 | square2x2 | rect4x1 | rect1x2 : {} } } ],
 *                              occupiedLocations, unoccupiedLocations, allLocations }, displayablesData = base64(binary plist { instanceIds [ {rawValue} ], chronoControls = Data(plist [ {rawValue} ]),
 *                              modules = Data(plist [ { id {rawValue}, size { small | medium | large : {} }, moduleId "WiFi" | "Bluetooth" | "AirDrop" | "Display" | "Sound" | "FocusModes" | "NowPlaying" |
 *                              "ScreenMirroring" | "Battery" | "KeyboardBrightness" } ]) }) } ]
 *   ~/Library/Preferences/com.apple.controlcenter.plist: ControlCenterDisplayableChronoControlsProviderConfiguration = JSON (Data) { Controls: [ { Identifier [UUID], DisplayName, ControlSize, ControlType,
 *                              ControlIdentity = base64(keyed archive of CHSControlIdentity: ...com.apple.controls.display.screen-saver...) } ] } for the controls that are extensions (Screen Saver, Dark Mode ...).
 * The element's id is the instance id of a module or of a chrono control.  CCBento reads that and writes it back (the file is read through CFPreferences, and directly from the file when that has nothing:
 * pearOS; CC_BENTO_FILE / CC_CHRONO_FILE name the files for a test). */
#import <Foundation/Foundation.h>
#import "CCControls.h"
@interface CCBento : NSObject
+ (instancetype)load;                                       /* nil when there is no such layout (then the old preference of ours is used) */
@property (readonly) NSArray<CCControl *> *controls;        /* the placed controls, with instanceId, kind, col, row, w, h */
- (void)saveControls:(NSArray<CCControl *> *)controls;      /* writes the grid, the instances and the sizes of the chrono controls back */
@end
