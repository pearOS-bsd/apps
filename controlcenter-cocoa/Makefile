# make: builds ./ControlCenter.app (bundle like the real one: Contents/Info.plist, Contents/MacOS/ControlCenter).  Window code is shared with ../dock-cocoa (SkyLightAPI, DockWindow).
SRC = main.m CCServices.m
ControlCenter.app/Contents/MacOS/ControlCenter: $(SRC) CCServices.h Info.plist
	mkdir -p ControlCenter.app/Contents/MacOS
	clang -fobjc-arc -Wall -O1 -o $@ $(SRC) -framework Foundation -framework CoreFoundation -framework CoreGraphics -framework QuartzCore -framework CoreServices
	cp Info.plist ControlCenter.app/Contents/Info.plist
clean:
	rm -rf ControlCenter.app
