# Fresh stack on the ISO test VM (run as root, after iso-prep.sh): copies the fonts, starts WindowServer + the d daemons (launchd log to /dev/null: it fills the 20 MB /tmp in seconds) and the panel (CC_OPEN=1 opens it, CC_NO_SYSTEM_SERVICES=1 keeps the system frameworks unloaded). A restart of ControlCenter alone over an old stack hangs: always run the whole script.
S=/Users/alex/stk
cp $S/fonts/* /tmp/big/sl/Fonts/ 2>&1 | tail -1
for p in notifyd wsbridge cfprefsd carender-stub lsd-stub svc-stub xpc-stub WindowServer ControlCenter; do pkill -9 $p 2>/dev/null; done; pkill -9 -f dnew/launchd/launchd; sleep 1
sysctl kern.darwinator.dyld=1 kern.darwinator.two_volumes=2 kern.darwinator.fast_sleep_ms=5 kern.darwinator.debug=0 >/dev/null; dmesg -c >/dev/null
rm -f /tmp/WindowServer.sock /tmp/WindowServer-ca.sock /tmp/ca.bin /tmp/ca-ool-*
chmod +x $S/WindowServer $S/dnew/*/out/* $S/dnew/launchd/launchd $S/dnew/notifyd/notifyd $S/dnew/wsbridge/wsbridge $S/macbins/usr/sbin/cfprefsd 2>/dev/null
(WSD_OPSET=26 WSD_APPEARANCE=dark nohup $S/WindowServer -t -s /tmp/WindowServer.sock >/dev/null 2>&1 &)
sleep 2
(cd /tmp; nohup $S/dnew/launchd/launchd $S/dnew/notifyd/notifyd $S/dnew/wsbridge/wsbridge "$S/macbins/usr/sbin/cfprefsd daemon" "$S/macbins/usr/sbin/cfprefsd agent" $S/dnew/lsd-stub/out/lsd-stub $S/dnew/carender-stub/out/carender-stub "$S/dnew/svc-stub/out/svc-stub com.apple.PowerManagement.control" >/dev/null 2>&1 &)
sleep 10
cd /Users/alex/cc; (CC_NO_SYSTEM_SERVICES=1 CC_OPEN=1 nohup ./ControlCenter.app/Contents/MacOS/ControlCenter </dev/null >/tmp/cc.out 2>&1 &); sleep 60
ps -axo pid,state,command | grep -E "ControlCenter|WindowServer|launchd" | grep -v grep | cut -c1-90
tail -3 /tmp/cc.out | cut -c1-200
which wswins wsshot; WS_SOCKET=/tmp/WindowServer.sock wswins 2>&1 | head -8
WS_SOCKET=/tmp/WindowServer.sock wsshot /tmp/shot.ppm 2>&1 | tail -1
