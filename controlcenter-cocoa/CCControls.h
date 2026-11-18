/* The controls of Control Center: catalog (what the gallery offers), layout (what the panel shows, in a 4-column grid, saved in our preferences), actions (what a click does). */
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
typedef NS_ENUM(int, CCKind) {
	CCWifi, CCBluetooth, CCAirDrop, CCNowPlaying, CCStageManager, CCScreenMirroring, CCDarkMode, CCScreenshot, CCFocus, CCDisplay, CCSound,       /* the default panel */
	CCAlarm, CCStopwatch, CCTimer, CCScene, CCTileWindows, CCRunShortcut, CCVoiceMemo, CCQuickNote, CCRecognizeMusic, CCScreenSaver, CCKeyboardBrightness, CCLockScreen,
	CCFastUserSwitching, CCBattery, CCClockMenu, CCKindCount
};
typedef struct { CCKind kind; const char *id, *title, *category, *glyph; int w, h; int icon; } CCCatalogEntry;   /* icon = sidebar/gallery colour index */
const CCCatalogEntry *CCCatalog(size_t *count);
const CCCatalogEntry *CCCatalogFor(CCKind k);
extern NSArray<NSString *> *CCCategories(void);

@interface CCControl : NSObject
@property CCKind kind; @property int col, row;
- (const CCCatalogEntry *)entry;
- (CGRect)frame;                         /* screen rectangle in the panel */
@end

@interface CCLayout : NSObject
@property (readonly) NSMutableArray<CCControl *> *controls;
+ (instancetype)shared;
- (void)load; - (void)save;
- (int)rows;                             /* rows in use (max row + 1) */
- (CCControl *)controlAtPoint:(CGPoint)p;
- (BOOL)add:(CCKind)k;                   /* first free place; NO when the grid is full or the kind is already there */
- (void)remove:(CCControl *)c;
- (BOOL)contains:(CCKind)k;
- (BOOL)moveControl:(CCControl *)c toCol:(int)col row:(int)row;
- (void)resetDefaults;
@end
CGRect CCCellRect(int col, int row, int w, int h);      /* screen rectangle of a grid area */
int CCMaxRows(void);

/* actions */
NSString *CCStateText(CCKind k);         /* "Off", "On", subtitle, or nil */
BOOL CCIsOn(CCKind k);
void CCPerform(CCKind k);                /* a click on the control */
double CCSliderGet(CCKind k);            /* Display, Sound: 0..1 */
void CCSliderSet(CCKind k, double v);
void CCMediaCommand(int command);        /* MediaRemote: 0 play, 1 pause, 2 toggle, 4 next, 5 previous */
NSString *CCNowPlayingTitle(void);
