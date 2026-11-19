/* The controls of Control Center: catalog (what the gallery offers), layout (what the panel shows, in a 4-column grid, saved in our preferences), actions (what a click does). */
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
typedef NS_ENUM(int, CCKind) {
	CCWifi, CCBluetooth, CCAirDrop, CCNowPlaying, CCStageManager, CCScreenMirroring, CCDarkMode, CCScreenshot, CCFocus, CCDisplay, CCSound,       /* the default panel */
	CCAlarm, CCStopwatch, CCTimer, CCScene, CCTileWindows, CCRunShortcut, CCVoiceMemo, CCQuickNote, CCRecognizeMusic, CCScreenSaver, CCKeyboardBrightness, CCLockScreen,
	CCFastUserSwitching, CCBattery, CCClockMenu, CCTrueTone, CCNightShift, CCZoom, CCKindCount
};
typedef struct { CCKind kind; const char *id, *title, *category, *glyph; int w, h; int icon; } CCCatalogEntry;   /* icon = sidebar/gallery colour index */
const CCCatalogEntry *CCCatalog(size_t *count);
const CCCatalogEntry *CCCatalogFor(CCKind k);
extern NSArray<NSString *> *CCCategories(void);

@interface CCControl : NSObject
@property CCKind kind; @property int col, row; @property int w, h;       /* w, h: the size in cells the user chose in Edit Controls (0 = the catalog size) */
@property (copy) NSString *instanceId;                      /* the id of the instance in the real layout file (CCBento); nil for a control added here */
- (const CCCatalogEntry *)entry;
- (int)cw; - (int)ch;                    /* the size in cells now */
- (CGRect)frame;                         /* screen rectangle in the panel */
@end

@interface CCLayout : NSObject
@property (readonly) NSMutableArray<CCControl *> *controls;
+ (instancetype)shared;
- (void)load; - (void)save;
- (int)rows;                             /* rows in use (max row + 1) */
- (CCControl *)controlAtPoint:(CGPoint)p;
- (BOOL)add:(CCKind)k atCol:(int)col row:(int)row;      /* a control dropped on a cell */
- (BOOL)add:(CCKind)k;                   /* first free place; NO when the grid is full or the kind is already there */
- (void)remove:(CCControl *)c;
- (BOOL)contains:(CCKind)k;
- (BOOL)moveControl:(CCControl *)c toCol:(int)col row:(int)row;
- (BOOL)resizeControl:(CCControl *)c toW:(int)w h:(int)h;     /* only to a size the control offers (CCSizesFor) and that fits */
- (void)commit;                          /* saves */
- (void)resetDefaults;
@end
typedef struct { int w, h; } CCSize;
const CCSize *CCSizesFor(CCKind k, int *count);         /* the sizes the real Edit Controls offers a control (the resize handle snaps to them) */
CGRect CCCellRect(int col, int row, int w, int h);      /* screen rectangle of a grid area */
int CCMaxRows(void);

/* actions */
NSString *CCFocusActiveMode(void); void CCFocusSet(NSString *mode); NSString *CCFocusName(NSString *mode);
NSString *CCStateText(CCKind k);         /* "Off", "On", subtitle, or nil */
BOOL CCIsOn(CCKind k);
void CCPerform(CCKind k);                /* a click on the control */
void CCSliderRange(CCControl *c, CGFloat *x0, CGFloat *x1);   /* the track of a slider control in screen x, by its width */
double CCSliderGet(CCKind k);            /* Display, Sound: 0..1 */
void CCSliderSet(CCKind k, double v);
void CCMediaCommand(int command);        /* MediaRemote: 0 play, 1 pause, 2 toggle, 4 next, 5 previous */
NSString *CCNowPlayingTitle(void);       /* nil when nothing plays; refreshed by CCNowPlayingStart() */
NSString *CCNowPlayingArtist(void);
CGImageRef CCNowPlayingArtwork(void);
BOOL CCNowPlayingIsPlaying(void);
void CCNowPlayingStart(void);            /* polls MediaRemote once a second */

/* detail pages (the small panel that replaces the main one when the chevron / label of a tile is clicked; measured on the real Wi-Fi page: 308 wide at x 964, y 36, rows 42 high, a switch on the title row, a divider, links) */
typedef NS_ENUM(int, CCRowType) { CCRowSwitch, CCRowRadio, CCRowLink, CCRowHeader };
@interface CCRow : NSObject
@property CCRowType type; @property (copy) NSString *title; @property BOOL on; @property (copy) void (^action)(void);
+ (instancetype)row:(CCRowType)t title:(NSString *)s on:(BOOL)on action:(void (^)(void))a;
@end
NSArray<CCRow *> *CCPageRows(CCKind k);                  /* nil when the control has no page */
void CCOpenSettings(NSString *pane);                     /* x-apple.systempreferences:<pane> */
