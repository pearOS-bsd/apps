#!/bin/sh
# creates fake devices in $1 (a directory) for platform_test: mixer, backlight, ifconfig, ngctl, service, each writing its state to $1/state.<name>
d=$1; mkdir -p $d
cat > $d/mixer <<'X'
#!/bin/sh
D=$(dirname "$0"); case "$1" in -s) echo "vol:$(cat $D/state.vol 2>/dev/null || echo 0.50):0.50";; vol=*) echo "${1#vol=}" > $D/state.vol;; esac
X
cat > $d/backlight <<'X'
#!/bin/sh
D=$(dirname "$0"); if [ -n "$1" ]; then echo "$1" > $D/state.bl; else cat $D/state.bl 2>/dev/null || echo 80; fi
X
cat > $d/ifconfig <<'X'
#!/bin/sh
D=$(dirname "$0"); case "$1" in -l) echo "vtnet0 wlan0 lo0";; wlan0) if [ -n "$2" ]; then echo $2 > $D/state.wlan; else if [ "$(cat $D/state.wlan 2>/dev/null)" = up ]; then echo "wlan0: flags=8843<UP,BROADCAST,RUNNING,SIMPLEX,MULTICAST> metric 0 mtu 1500"; else echo "wlan0: flags=8802<BROADCAST,SIMPLEX,MULTICAST> metric 0 mtu 1500"; fi; fi;; esac
X
cat > $d/ngctl <<'X'
#!/bin/sh
D=$(dirname "$0"); echo "There are 2 total nodes:"; echo "  Name: ubt0  Type: ubt  ID: 00000003  Num hooks: 1"; [ "$(cat $D/state.bt 2>/dev/null)" = onestart ] && echo "  Name: ubt0hci  Type: hci  ID: 00000004  Num hooks: 2"; exit 0
X
cat > $d/service <<'X'
#!/bin/sh
D=$(dirname "$0"); echo "$2" > $D/state.bt
X
chmod +x $d/*
