# The minimal stack for ControlCenter on the ISO test VM (run as root after iso-prep.sh; files in /Users/alex/stk: WindowServer built from WindowServer, dnew/ = d/darwin/build.sh output, macbins/usr/sbin/cfprefsd taken from the Mac).  Do not pkill launchd twice: it kills the image's own launchd and the ssh session.
S=/Users/alex/stk
pkill -9 launchd notifyd wsbridge cfprefsd carender-stub lsd-stub svc-stub xpc-stub WindowServer ControlCenter 2>/dev/null; sleep 1
sysctl kern.darwinator.dyld=1 kern.darwinator.two_volumes=2 kern.darwinator.fast_sleep_ms=5 kern.darwinator.debug=1 >/dev/null; dmesg -c >/dev/null
rm -f /tmp/WindowServer.sock /tmp/WindowServer-ca.sock
(WSD_OPSET=26 WSD_APPEARANCE=dark WSD_CA_DEBUG=1 CA_DEBUG=1 nohup $S/WindowServer -t -s /tmp/WindowServer.sock >/tmp/WindowServer.log 2>&1 &)
sleep 2
(cd /tmp; nohup $S/dnew/launchd/launchd $S/dnew/notifyd/notifyd $S/dnew/wsbridge/wsbridge "$S/macbins/usr/sbin/cfprefsd daemon" "$S/macbins/usr/sbin/cfprefsd agent" $S/dnew/lsd-stub/out/lsd-stub $S/dnew/carender-stub/out/carender-stub "$S/dnew/svc-stub/out/svc-stub com.apple.PowerManagement.control" >/tmp/launchd.log 2>&1 &)
sleep 8
ps -axo pid,state,command | grep -E "launchd|notifyd|wsbridge|cfprefsd|stub|WindowServer" | grep -v grep | cut -c1-100
tail -3 /tmp/WindowServer.log; tail -5 /tmp/launchd.log
