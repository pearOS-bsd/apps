/* cc -o platform_test test/platform_test.c CCPlatform.c -lm && ./platform_test
 * Without arguments: prints what this machine has (the FreeBSD VM has none of it: every value must be negative and the setters must refuse).
 * With "fake DIR" (after sh test/fake.sh DIR, CCP_FAKE=DIR in the environment): fake mixer, backlight, ifconfig, ngctl, service, and the functions must read and change their state. */
#include "../CCPlatform.h"
#include <stdio.h>
#include <string.h>
#include <math.h>
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); bad = 1; } } while (0)
int main(int argc, char **argv)
{
	char ifn[32] = ""; int bad = 0;
	if (argc > 1 && !strcmp(argv[1], "fake")) {
		CHECK(fabs(ccp_volume_get() - 0.50) < 0.01); CHECK(ccp_volume_set(0.8)); CHECK(fabs(ccp_volume_get() - 0.80) < 0.01);
		CHECK(fabs(ccp_brightness_get() - 0.80) < 0.01); CHECK(ccp_brightness_set(0.3)); CHECK(fabs(ccp_brightness_get() - 0.30) < 0.01);
		CHECK(ccp_wifi_interface(ifn, sizeof ifn) && !strcmp(ifn, "wlan0")); CHECK(ccp_wifi_power() == 0); CHECK(ccp_wifi_set(1)); CHECK(ccp_wifi_power() == 1); CHECK(ccp_wifi_set(0)); CHECK(ccp_wifi_power() == 0);
		{ char nm[16][64]; int cur; CHECK(ccp_sound_list(nm, 16, &cur) == 2); CHECK(!strcmp(nm[0], "Intel HDA Speakers") && !strcmp(nm[1], "USB Headset") && cur == 0); CHECK(ccp_wifi_scan(nm, 16) == 2); CHECK(!strcmp(nm[0], "Home Net") && !strcmp(nm[1], "Cafe")); }
		CHECK(ccp_bluetooth_power() == 0); CHECK(ccp_bluetooth_set(1)); CHECK(ccp_bluetooth_power() == 1); CHECK(ccp_bluetooth_set(0)); CHECK(ccp_bluetooth_power() == 0);
	} else {
		{ char nm[16][64]; int cur; printf("sound outputs %d, wifi scan %d\n", ccp_sound_list(nm, 16, &cur), ccp_wifi_scan(nm, 16)); }
		printf("freebsd %d\nvolume %.2f\nbrightness %.2f\nbattery %d charging %d\nkbd %.2f\nwifi %d power %d\nbluetooth %d\n", ccp_is_freebsd(), ccp_volume_get(), ccp_brightness_get(), ccp_battery_percent(), ccp_battery_charging(), ccp_kbd_get(), ccp_wifi_interface(ifn, sizeof ifn), ccp_wifi_power(), ccp_bluetooth_power());
		if (ccp_volume_get() < 0) CHECK(!ccp_volume_set(0.5));
		if (ccp_wifi_power() < 0) CHECK(!ccp_wifi_set(1));
		if (ccp_bluetooth_power() < 0) CHECK(!ccp_bluetooth_set(1));
	}
	printf(bad ? "FAIL\n" : "ok\n"); return bad;
}
