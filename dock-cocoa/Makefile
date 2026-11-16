# make          builds ./Dock.app (a bundle like the real one: Contents/Info.plist with LSUIElement, Contents/MacOS/Dock), with the host's Foundation
# The real Dock does not link AppKit; neither do we.  A bare executable (no Info.plist) makes the system connect to services the real Dock does not touch at startup.
Dock.app/Contents/MacOS/Dock: main.m DockPrefs.m DockServices.m DockWindow.m SkyLightAPI.m DockModel.m DockView.m DockIcons.m DockWallpaper.m DockRunning.m dock_fit.c ../dock/dock_layout.c DockPrefs.h DockServices.h DockWindow.h SkyLightAPI.h Info.plist Resources/en.lproj/Localizable.strings
	mkdir -p Dock.app/Contents/MacOS
	clang -fobjc-arc -Wall -O1 -o $@ main.m DockPrefs.m DockServices.m DockWindow.m SkyLightAPI.m DockModel.m DockView.m DockIcons.m DockWallpaper.m DockRunning.m dock_fit.c ../dock/dock_layout.c -framework Foundation -framework CoreFoundation -framework CoreGraphics -framework QuartzCore -framework ImageIO -framework CoreServices
	cp Info.plist Dock.app/Contents/Info.plist
	mkdir -p Dock.app/Contents/Resources && cp -R Resources/en.lproj Dock.app/Contents/Resources/
clean:
	rm -rf Dock.app
check:
	$(CC) -O1 -o layout_check test/layout_check.c dock_fit.c ../dock/dock_layout.c -lm && ./layout_check; rm -f layout_check
.PHONY: check
