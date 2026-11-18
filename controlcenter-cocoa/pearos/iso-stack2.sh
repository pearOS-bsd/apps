# Restart of the minimal stack on the ISO test VM without killing the image's own launchd (pkill -f only ours); wsd from /Users/alex/stk/wsd.new (rebuilt on the lab VM); logs /tmp/wsd.log (WSD_CA_DEBUG, CA_DEBUG), shot with wsshot.
S=/Users/alex/stk
pkill -9 -f dnew/launchd/launchd; for p in notifyd wsbridge cfprefsd carender-stub lsd-stub svc-stub xpc-stub wsd wsd.new ControlCenter; do pkill -9 $p 2>/dev/null; done; sleep 1
sysctl kern.darwinator.dyld=1 kern.darwinator.two_volumes=2 kern.darwinator.fast_sleep_ms=5 kern.darwinator.debug=0 >/dev/null; dmesg -c >/dev/null
rm -f /tmp/wsd.sock /tmp/wsd-ca.sock /tmp/ca.bin /tmp/ca-ool-*
(WSD_OPSET=26 WSD_CA_DEBUG=1 CA_DEBUG=1 nohup $S/wsd.new -t -s /tmp/wsd.sock >/tmp/wsd.log 2>&1 &)
sleep 2
(cd /tmp; nohup $S/dnew/launchd/launchd $S/dnew/notifyd/notifyd $S/dnew/wsbridge/wsbridge "$S/macbins/usr/sbin/cfprefsd daemon" "$S/macbins/usr/sbin/cfprefsd agent" $S/dnew/lsd-stub/out/lsd-stub $S/dnew/carender-stub/out/carender-stub "$S/dnew/svc-stub/out/svc-stub com.apple.PowerManagement.control" >/tmp/launchd.log 2>&1 &)
sleep 10
cd /Users/alex/cc; (nohup ./ControlCenter.app/Contents/MacOS/ControlCenter </dev/null >/tmp/cc.out 2>&1 &); sleep 25
grep -v statfs /tmp/wsd.log | grep -v "scene 0 root" | tail -6 | cut -c1-150
WS_SOCKET=/tmp/wsd.sock wswins | head -8
WS_SOCKET=/tmp/wsd.sock wsshot /tmp/shot.ppm
