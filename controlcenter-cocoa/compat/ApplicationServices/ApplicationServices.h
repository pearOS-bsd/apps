/* The part of ApplicationServices' CGEvent / Accessibility API that ControlCenter's input tap uses, declared here for building on pearOS (the functions and values are the Mac's: they come from the real frameworks at run time). */
#ifndef CC_COMPAT_APPLICATIONSERVICES_H
#define CC_COMPAT_APPLICATIONSERVICES_H
#include <CoreFoundation/CoreFoundation.h>
#include <CoreGraphics/CoreGraphics.h>
#include <stdint.h>
typedef struct __CGEvent *CGEventRef;
typedef struct __CGEventTapProxy *CGEventTapProxy;
typedef uint32_t CGEventType;
typedef uint64_t CGEventMask;
typedef uint32_t CGEventField;
typedef uint32_t CGEventTapLocation;
typedef uint32_t CGEventTapPlacement;
typedef uint32_t CGEventTapOptions;
enum { kCGEventLeftMouseDown = 1, kCGEventLeftMouseUp = 2, kCGEventMouseMoved = 5, kCGEventLeftMouseDragged = 6, kCGEventKeyDown = 10, kCGEventScrollWheel = 22, kCGEventTapDisabledByTimeout = 0xFFFFFFFE, kCGEventTapDisabledByUserInput = 0xFFFFFFFF };
enum { kCGSessionEventTap = 1 };
enum { kCGHeadInsertEventTap = 0 };
enum { kCGEventTapOptionDefault = 0, kCGEventTapOptionListenOnly = 1 };
enum { kCGKeyboardEventKeycode = 9, kCGScrollWheelEventPointDeltaAxis1 = 96 };
#define CGEventMaskBit(type) ((CGEventMask)1 << (type))
typedef CGEventRef (*CGEventTapCallBack)(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo);
CFMachPortRef CGEventTapCreate(CGEventTapLocation tap, CGEventTapPlacement place, CGEventTapOptions options, CGEventMask eventsOfInterest, CGEventTapCallBack callback, void *userInfo);
void CGEventTapEnable(CFMachPortRef tap, bool enable);
CGPoint CGEventGetLocation(CGEventRef event);
double CGEventGetDoubleValueField(CGEventRef event, CGEventField field);
int64_t CGEventGetIntegerValueField(CGEventRef event, CGEventField field);
void CGEventKeyboardGetUnicodeString(CGEventRef event, unsigned long maxStringLength, unsigned long *actualStringLength, UniChar unicodeString[]);
bool CGPreflightListenEventAccess(void);
bool CGPreflightPostEventAccess(void);
bool AXIsProcessTrusted(void);
#endif
