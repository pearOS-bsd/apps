/* Declarations the open Foundation / CoreText headers of the build lack (the run time has them: they are the Mac's). */
#import <Foundation/Foundation.h>
@interface NSTimer (CCCompat)
+ (NSTimer *)scheduledTimerWithTimeInterval:(NSTimeInterval)interval repeats:(BOOL)repeats block:(void (^)(NSTimer *timer))block;
@end
extern const CFStringRef kCTForegroundColorFromContextAttributeName;
#import <CoreText/CoreText.h>
CGRect CTLineGetBoundsWithOptions(CTLineRef line, uint64_t options);
@protocol NSXPCProxyCreating; 
@interface NSXPCInterface : NSObject
+ (NSXPCInterface *)interfaceWithProtocol:(Protocol *)protocol;
@end
@interface NSXPCConnection : NSObject
- (instancetype)initWithMachServiceName:(NSString *)name options:(NSUInteger)options;
@property (retain) NSXPCInterface *remoteObjectInterface;
@property (copy) void (^invalidationHandler)(void);
@property (copy) void (^interruptionHandler)(void);
- (void)resume;
- (id)remoteObjectProxy;
- (id)remoteObjectProxyWithErrorHandler:(void (^)(NSError *error))handler;
@end
/* declared by the Mac SDK's headers, not by the open ones of the build: a call to an undeclared function would be compiled with the wrong ABI (the build refuses implicit declarations) */
CGPathRef CGPathCreateWithRoundedRect(CGRect rect, CGFloat cornerWidth, CGFloat cornerHeight, const CGAffineTransform *transform);
CGColorSpaceRef CGColorSpaceCreateWithName(CFStringRef name);
#include <sys/types.h>
int posix_spawn(pid_t *pid, const char *path, const void *file_actions, const void *attrp, char *const argv[], char *const envp[]);
