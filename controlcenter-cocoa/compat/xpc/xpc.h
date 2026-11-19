/* The few declarations of the XPC API that ControlCenter and the Dock use (xpc_connection_create_mach_service and friends), written for building on pearOS without the header of a Mac SDK.  The functions are provided at run time by libxpc. */
#ifndef CC_COMPAT_XPC_H
#define CC_COMPAT_XPC_H
#include <dispatch/dispatch.h>
#include <stdint.h>
#ifdef __OBJC__
typedef id xpc_object_t;
#else
typedef void *xpc_object_t;
#endif
typedef xpc_object_t xpc_connection_t;
typedef const struct _xpc_type_s *xpc_type_t;
typedef void (^xpc_handler_t)(xpc_object_t object);
#define XPC_CONNECTION_MACH_SERVICE_LISTENER (1 << 0)
extern const struct _xpc_type_s _xpc_type_connection;
#define XPC_TYPE_CONNECTION (&_xpc_type_connection)
xpc_connection_t xpc_connection_create_mach_service(const char *name, dispatch_queue_t targetq, uint64_t flags);
void xpc_connection_set_event_handler(xpc_connection_t connection, xpc_handler_t handler);
void xpc_connection_resume(xpc_connection_t connection);
xpc_type_t xpc_get_type(xpc_object_t object);
#endif
