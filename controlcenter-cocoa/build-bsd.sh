#!/bin/sh
# Builds ControlCenter.app ON FreeBSD (pearOS), without a Mac: clang for x86_64-apple-macosx + ld64.lld, the header tree of dyld/tools/sdk (open sources), the headers of our repositories (ravynOS' Foundation / CoreGraphics patched, QuartzCore, SDK, CoreText, IOKit) and compat/ (the few declarations that none of them has).
# The frameworks are text stubs (install names only): the symbols bind at run time to the frameworks the dyld finds (pearOS' own, or the cache of the Mac that macdeps copied).
#   sh build-bsd.sh OUTDIR       SDK_WORK (default /root/oss) = where dyld/tools/sdk was run; the repositories next to apps/ (QuartzCore, SDK, CoreText, IOKit, darwinator, SkyLight)
set -e
OUT="${1:?output directory}"; H="$(cd "$(dirname "$0")" && pwd)"; P="$(dirname "$(dirname "$H")")"; W="${SDK_WORK:-/root/oss}"; I="$W/sdk/usr/include"
RES=$(ls -d /usr/local/llvm*/lib/clang/*/include 2>/dev/null | tail -1); LD=$(ls /usr/local/llvm*/bin/ld64.lld 2>/dev/null | tail -1)
rm -rf "$OUT/ravyn"; mkdir -p "$OUT/o" "$OUT/hdr/IOKit/ps" "$OUT/hdr/CoreText" "$OUT/fw"
cp "$P/IOKit/upstream/IOKitUser/ps.subproj"/*.h "$OUT/hdr/IOKit/ps/"; cp "$P/CoreText/upstream/ravynos-CoreText"/*.h "$OUT/hdr/CoreText/"
# ravynOS' CoreGraphics headers say `typedef float CGFloat`; Apple's CGFloat is a double on 64 bits and that is what the real frameworks (and every struct they pass: CGPoint, CGRect) use: a copy of the tree with the right type
cp -R "$W/sdk/ravyn" "$OUT/ravyn"; grep -rl "typedef float CGFloat;" "$OUT/ravyn" | while read f; do sed -i.bak "s/typedef float CGFloat;/typedef double CGFloat;/" "$f"; rm -f "$f.bak"; done
T="--target=x86_64-apple-macosx14.0 -DXNU_PLATFORM_MacOSX -nostdinc -isystem $RES -isystem $I"
OBJC="$T -x objective-c -fobjc-runtime=macosx-14.0 -fobjc-arc -Wno-everything -Werror=implicit-function-declaration -Werror=int-conversion -O1 -isystem $OUT/ravyn -isystem $W/sdk/stubs -isystem $OUT/hdr -isystem $P/SDK/include -I$P/QuartzCore/include -I$H/compat -include $H/compat/CCCompat.h -I$H -I$H/../dock-cocoa"
set +e; for f in main CCServices CCStatusBar CCSkyLight CCSkyLightStartup CCPrefs CCPanel CCInput CCDraw CCSymbols CCControls CCGallery CCExtras ../dock-cocoa/DockWindow ../dock-cocoa/SkyLightAPI; do clang $OBJC -c "$H/$f.m" -o "$OUT/o/$(basename $f).o" 2>&1 | grep "error"; done; set -e
clang $T -std=gnu11 -Wno-everything -O1 -c "$H/CCPlatform.c" -o "$OUT/o/CCPlatform.o"
# one empty-symbol stub for each framework the program links
FW=""; for n in Foundation CoreFoundation CoreGraphics QuartzCore CoreServices CoreText ImageIO ApplicationServices IOKit; do
	V=A; [ $n = Foundation ] && V=C; mkdir -p "$OUT/fw/$n.framework"; printf -- "--- !tapi-tbd\ntbd-version:     4\ntargets:         [ x86_64-macos ]\ninstall-name:    '/System/Library/Frameworks/$n.framework/Versions/$V/$n'\ncurrent-version: 1\nexports:\n  - targets:         [ x86_64-macos ]\n    symbols:         []\n...\n" > "$OUT/fw/$n.framework/$n.tbd"; FW="$FW -framework $n"; done
$LD -arch x86_64 -platform_version macos 14.0 14.0 -undefined dynamic_lookup -F"$OUT/fw" -L"$P/darwinator/tests/macho-toolchain" -L"$P/darwinator/tests/macho-toolchain/objc" -lSystem -lobjc $FW -o "$OUT/ControlCenter" "$OUT"/o/*.o
mkdir -p "$OUT/ControlCenter.app/Contents/MacOS"; cp "$OUT/ControlCenter" "$OUT/ControlCenter.app/Contents/MacOS/ControlCenter"; cp "$H/Info.plist" "$OUT/ControlCenter.app/Contents/Info.plist"
file "$OUT/ControlCenter" | cut -c1-120
