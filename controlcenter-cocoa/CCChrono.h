/* The controls of the apps and the system extensions, as the real Control Center gets them: chronod keeps the control descriptors of every installed extension in
 *   ~/Library/Group Containers/group.com.apple.chronod/chronod/chrono.sql, table Descriptors (descriptorType 2 = controls; data = a keyed archive of an array of CHSControlDescriptor:
 *   displayName, widgetDescription, kind, extensionIdentity { containerBundleIdentifier, extensionBundleIdentifier }, type 1 toggle / 2 button / 3 menu, hiddenControl, internal ...).
 * A control is offered in Edit Controls when its extension is installed (its .appex is in an app or in ExtensionKit).  CC_CHRONO_DB names another file, CC_CHRONO_ALL=1 skips the check of the extension. */
#import <Foundation/Foundation.h>
typedef struct { const char *kind, *name, *desc, *container, *extension; int type; } CCChronoControl;
size_t CCChronoCount(void);                                   /* the visible controls of the installed extensions */
const CCChronoControl *CCChronoAt(size_t i);
const CCChronoControl *CCChronoFind(const char *kind);        /* nil when not offered */
NSString *CCChronoCategory(const CCChronoControl *c);         /* the name of its group in the sidebar of Edit Controls */
BOOL CCChronoAvailable(void);                                 /* a database was found */
