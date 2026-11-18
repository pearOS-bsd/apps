/* FreeBSD bindings of the Control Center's actions (temporary, until pearOS has the macOS frameworks behind the real calls: DisplayServices, CoreAudio, CoreWLAN, IOBluetooth, IOPS).
 * Taken from the earlier Control Center (apps/topbar/ControlCenter.m): mixer(8) for the volume, backlight(8) or the ACPI video sysctl for the brightness, hw.acpi.battery.* for the battery, the clevo_dchu sysctl for the keyboard
 * backlight; added: ifconfig(8) for Wi-Fi and ngctl(8) / service(8) for Bluetooth.  Plain C + POSIX (no Foundation): testable on the FreeBSD VM with test/platform_test.c.
 * Every function returns a negative number (or 0 for a setter) when the machine has no such device: the callers then fall back to something else or hide the control. */
#ifndef CCPLATFORM_H
#define CCPLATFORM_H
#ifdef __cplusplus
extern "C" {
#endif
int  ccp_is_freebsd(void);                       /* 1 when uname says FreeBSD */
double ccp_volume_get(void);                     /* 0..1, -1: no mixer */
int  ccp_volume_set(double v);                   /* 1 done */
double ccp_brightness_get(void);                 /* 0..1, -1: no backlight */
int  ccp_brightness_set(double v);
int  ccp_battery_percent(void);                  /* -1: no battery */
int  ccp_battery_charging(void);
double ccp_kbd_get(void);                        /* -1: no keyboard backlight */
int  ccp_kbd_set(double v);
int  ccp_wifi_interface(char *name, int size);   /* first wlan interface, 1 found */
int  ccp_wifi_power(void);                       /* 1 on (UP), 0 off, -1 no Wi-Fi */
int  ccp_wifi_set(int on);
int  ccp_bluetooth_power(void);                  /* 1 / 0, -1 no controller */
int  ccp_bluetooth_set(int on);
#ifdef __cplusplus
}
#endif
#endif
