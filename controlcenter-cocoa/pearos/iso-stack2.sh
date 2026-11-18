# Restart of the minimal stack on the ISO test VM without killing the image's own launchd (pkill -f only ours); WindowServer from /Users/alex/stk/WindowServer.new (rebuilt on the lab VM); logs /tmp/WindowServer.log (WSD_CA_DEBUG, CA_DEBUG), shot with wsshot.
S=/Users/alex/stk
pkill -9 -f dnew/launchd/launchd; for p in notifyd wsbridge cfprefsd carender-stub lsd-stub svc-stub xpc-stub WindowServer WindowServer.new ControlCenter; do pkill -9 $p 2>/dev/null; done; sleep 1
sysctl kern.darwinator.dyld=1 kern.darwinator.two_volumes=2 kern.darwinator.fast_sleep_ms=5 kern.darwinator.debug=0 >/dev/null; dmesg -c >/dev/null
rm -f /tmp/WindowServer.sock /tmp/WindowServer-ca.sock /tmp/ca.bin /tmp/ca-ool-*
(WSD_OPSET=26 WSD_APPEARANCE=dark WSD_CA_DEBUG=1 CA_DEBUG=1 nohup $S/WindowServer.new -t -s /tmp/WindowServer.sock >/tmp/WindowServer.log 2>&1 &)
sleep 2
(cd /tmp; nohup $S/dnew/launchd/launchd $S/dnew/notifyd/notifyd $S/dnew/wsbridge/wsbridge "$S/macbins/usr/sbin/cfprefsd daemon" "$S/macbins/usr/sbin/cfprefsd agent" $S/dnew/lsd-stub/out/lsd-stub $S/dnew/carender-stub/out/carender-stub "$S/dnew/svc-stub/out/svc-stub com.apple.PowerManagement.control" >/tmp/launchd.log 2>&1 &)
sleep 10
cd /Users/alex/cc; (nohup ./ControlCenter.app/Contents/MacOS/ControlCenter </dev/null >/tmp/cc.out 2>&1 &); sleep 25
grep -v statfs /tmp/WindowServer.log | grep -v "scene 0 root" | tail -6 | cut -c1-150
WS_SOCKET=/tmp/WindowServer.sock wswins | head -8
WS_SOCKET=/tmp/WindowServer.sock wsshot /tmp/shot.ppm
