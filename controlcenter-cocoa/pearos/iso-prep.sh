# Prepares the ISO test VM (run as root): cache disk, nullfs copies of /System/Library and /usr/lib with the Mac dyld and /System/Library/dyld, the rebuilt darwinator.ko.  Needs /tmp/dyld_x86_64 (thin slice of the Mac dyld) and /tmp/darwinator.ko.
set -e
sysctl hw.physmem >/dev/null
mount | grep -q "/System/Volumes" || mount -t msdosfs -o ro /dev/vtbd0 /System/Volumes
mkdir -p /tmp/big && mount -t tmpfs -o size=900m tmpfs /tmp/big
mkdir -p /tmp/big/sl /tmp/big/ul
cp -a /System/Library/. /tmp/big/sl/
ln -s /System/Volumes/Preboot/Cryptexes/OS/System/Library/dyld /tmp/big/sl/dyld
cp -a /usr/lib/. /tmp/big/ul/
install -m 755 /tmp/dyld_x86_64 /tmp/big/ul/dyld
mount -t nullfs /tmp/big/sl /System/Library
mount -t nullfs /tmp/big/ul /usr/lib
kldunload darwinator || true
kldload /tmp/darwinator.ko
sysctl kern.darwinator.dyld=1 kern.darwinator.two_volumes=2 kern.darwinator.fast_sleep_ms=5 kern.darwinator.debug=0
binmiscctl disable macho64 || true; binmiscctl disable machofat || true
file /usr/lib/dyld | cut -c1-80; ls /System/Library/dyld | head -2
