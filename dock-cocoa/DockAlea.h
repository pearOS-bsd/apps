/* The serialization CoreDock uses in the out-of-line data of com.apple.dock.server messages (magic "alea", version 3).  Read from messages on the Mac VM (docs/development/DOCK-SERVER.md):
 *   "alea" u32 3, u32 1, u32 0 | u32 4 (dictionary), u32 entry count, u32 0, u32 0 | entries: key = u32 length, u32 0, UTF-16 characters; value = u32 type ... (string: u32 length, u32 0, UTF-16 characters).
 * Only what the minimize message needs is decoded (title, item = a window id, animate); the rest of the format is NOT understood and this reader looks for the keys instead of parsing generally. */
#import <Foundation/Foundation.h>
typedef struct { BOOL ok; uint32_t windowID; BOOL animate; } DockMinimizeRequest;
DockMinimizeRequest DockParseMinimize(NSData *alea, NSString **title);
