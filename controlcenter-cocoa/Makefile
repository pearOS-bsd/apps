# make: builds ./ControlCenter.app (bundle like the real one: Contents/Info.plist, Contents/MacOS/ControlCenter).  Window code is shared with ../dock-cocoa (SkyLightAPI, DockWindow).
SRC = CCPlatform.c CCGlass.m main.m CCServices.m CCStatusBar.m CCSkyLight.m CCSkyLightStartup.m CCPrefs.m CCPanel.m CCInput.m CCDraw.m CCSymbols.m CCControls.m CCBento.m CCGallery.m CCExtras.m ../dock-cocoa/DockWindow.m ../dock-cocoa/SkyLightAPI.m
ControlCenter.app/Contents/MacOS/ControlCenter: $(SRC) CCServices.h Info.plist
	mkdir -p ControlCenter.app/Contents/MacOS
	clang -fobjc-arc -Wall -Wno-objc-literal-conversion -O1 -o $@ $(SRC) -framework Foundation -framework CoreFoundation -framework CoreGraphics -framework QuartzCore -framework CoreServices -framework CoreText -framework IOKit -framework ImageIO -framework ApplicationServices
	cp Info.plist ControlCenter.app/Contents/Info.plist
clean:
	rm -rf ControlCenter.app
# FreeBSD bindings (CCPlatform.c): run on the FreeBSD VM, also against fake devices:  make check-platform
check-platform:
	$(CC) -Wall -o platform_test test/platform_test.c CCPlatform.c -lm && ./platform_test && sh test/fake.sh /tmp/ccp-fake && CCP_FAKE=/tmp/ccp-fake ./platform_test fake; rm -f platform_test
.PHONY: check-platform
