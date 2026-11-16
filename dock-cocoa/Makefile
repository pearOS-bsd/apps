# make          builds ./Dock with the host's Cocoa (a Mac, or pearOS with the `open` AppKit)
Dock: main.m DockPrefs.m DockServices.m DockPrefs.h DockServices.h
	clang -fobjc-arc -Wall -O1 -o $@ main.m DockPrefs.m DockServices.m -framework Cocoa -framework CoreFoundation
clean:
	rm -f Dock
