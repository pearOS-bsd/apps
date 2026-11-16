#import "DockServer.h"
#import "DockAlea.h"
#import <mach/mach.h>
#import <servers/bootstrap.h>
#import <dispatch/dispatch.h>
/* MIG replies: header (id request + 100, MOVE_SEND_ONCE to the reply port), NDR record, return code, then `value` (0 = none). Evidence for the ids: the messages AppKit sends to com.apple.dock.server
 * when a window is made (dock-server.log of 2026-11-16): 96519 (complex, one port descriptor, no reply: a client registers) and 96521 (simple, reply port, two ints: 4 and 0). */
static void reply(mach_msg_header_t *req, int32_t retcode, int hasValue, int32_t value)
{
	struct { mach_msg_header_t h; NDR_record_t ndr; int32_t ret; int32_t val; } r; memset(&r, 0, sizeof r);
	r.h.msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_MOVE_SEND_ONCE, 0); r.h.msgh_remote_port = req->msgh_remote_port; r.h.msgh_id = req->msgh_id + 100;
	r.h.msgh_size = (mach_msg_size_t)(hasValue ? sizeof r : sizeof r - 4); r.ndr = NDR_record; r.ret = retcode; r.val = value;
	mach_msg(&r.h, MACH_SEND_MSG, r.h.msgh_size, 0, MACH_PORT_NULL, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);
}
static void logMessage(const char *service, mach_msg_header_t *h, size_t total)
{
	if (access("/tmp/dock-server.debug", F_OK) != 0) return;               /* logging only while the file /tmp/dock-server.debug exists */
	FILE *f = fopen("/tmp/dock-server.log", "a"); if (!f) return;
	fprintf(f, "%s: id %d size %u bits 0x%x remote %u local %u total %zu\n   ", service, h->msgh_id, h->msgh_size, h->msgh_bits, h->msgh_remote_port, h->msgh_local_port, total);
	const unsigned char *b = (const unsigned char *)h; for (size_t i = 0; i < total && i < 160; i++) { fprintf(f, "%02x", b[i]); if (i % 4 == 3) fputc(' ', f); } fputc('\n', f); fclose(f);
}
static DockMinimizeHandler minimizeHandler;
void DockServerSetMinimizeHandler(DockMinimizeHandler h) { minimizeHandler = [h copy]; }
void DockServerStart(const char *name)
{
	mach_port_t port = MACH_PORT_NULL; kern_return_t kr = bootstrap_check_in(bootstrap_port, name, &port);
	if (kr != KERN_SUCCESS) { if (getenv("DOCK_LOG")) NSLog(@"dock: check-in of %s failed: %s", name, mach_error_string(kr)); return; }
	dispatch_source_t src = dispatch_source_create(DISPATCH_SOURCE_TYPE_MACH_RECV, port, 0, dispatch_get_main_queue());
	char *service = strdup(name);
	dispatch_source_set_event_handler(src, ^{
		union { mach_msg_header_t h; char buf[8192]; } m; memset(&m, 0, sizeof m);
		kern_return_t r = mach_msg(&m.h, MACH_RCV_MSG | MACH_RCV_LARGE, 0, sizeof m, port, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);
		if (r != KERN_SUCCESS) return;
		logMessage(service, &m.h, m.h.msgh_size);
		if ((m.h.msgh_bits & MACH_MSGH_BITS_COMPLEX) && m.h.msgh_size >= 24 + 4 + 16) {       /* an out-of-line descriptor: keep the data for reading (/tmp/dock-ool-<id>-<n>.bin) */
			mach_msg_body_t *body = (mach_msg_body_t *)(&m.h + 1); mach_msg_ool_descriptor_t *d = (mach_msg_ool_descriptor_t *)(body + 1);
			if (m.h.msgh_id == 96508 && d->address && minimizeHandler) { NSString *t = nil; NSData *nd = [NSData dataWithBytes: d->address length: MIN(d->size, 4096)]; DockMinimizeRequest q = DockParseMinimize(nd, &t); if (q.ok) minimizeHandler(q.windowID, t ?: @"", q.animate); }
			if (access("/tmp/dock-server.debug", F_OK) == 0 && body->msgh_descriptor_count >= 1 && d->type == MACH_MSG_OOL_DESCRIPTOR && d->address) {
				static int n; char path[96]; snprintf(path, sizeof path, "/tmp/dock-ool-%d-%d.bin", m.h.msgh_id, n++); FILE *f = fopen(path, "w"); if (f) { fwrite(d->address, 1, d->size, f); fclose(f); }
			}
		}
		BOOL wantsReply = (m.h.msgh_bits & 0xff) == MACH_MSG_TYPE_MOVE_SEND_ONCE && m.h.msgh_remote_port != MACH_PORT_NULL;
		if (wantsReply) { const char *v = getenv("DOCK_SERVER_VALUE"); reply(&m.h, 0, 1, v ? atoi(v) : 1); }       /* unknown request: success and the value 1 (guess, to be corrected against the real Dock) */
	});
	dispatch_resume(src);
	static NSMutableArray *keep; if (!keep) keep = [NSMutableArray array]; [keep addObject: (id)src];
}
