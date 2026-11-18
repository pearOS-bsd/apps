#include "CCPlatform.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <ctype.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/sysctl.h>
#include <sys/utsname.h>

static int run(const char *cmd, char *out, size_t size)           /* runs a shell command, captures stdout; returns the exit status, -1 when it could not start */
{
	FILE *p = popen(cmd, "r"); if (!p) return -1; size_t n = 0; if (out && size) { n = fread(out, 1, size - 1, p); out[n] = 0; } else { char b[256]; while (fread(b, 1, sizeof b, p) > 0) {} }
	int st = pclose(p); return st == -1 ? -1 : (st >> 8) & 0xff;
}
/* tests: CCP_FAKE=dir makes every tool path /usr/sbin/mixer ... resolve to dir/mixer, so scripts there can stand in for the devices */
static const char *P(const char *path, char *buf, size_t n) { const char *d = getenv("CCP_FAKE"); if (!d) return path; const char *b = strrchr(path, '/'); snprintf(buf, n, "%s%s", d, b); return buf; }
static int tool(const char *path) { char b[256]; return access(P(path, b, sizeof b), X_OK) == 0; }
static int runp(const char *path, const char *args, char *out, size_t size) { char b[256], c[512]; snprintf(c, sizeof c, "%s %s", P(path, b, sizeof b), args); return run(c, out, size); }
static int sys_int(const char *name, int *v) { size_t n = sizeof *v; return sysctlbyname(name, v, &n, NULL, 0) == 0; }
static int set_int(const char *name, int v) { return sysctlbyname(name, NULL, NULL, &v, sizeof v) == 0; }

int ccp_is_freebsd(void) { struct utsname u; return uname(&u) == 0 && !strcmp(u.sysname, "FreeBSD"); }

/* mixer(8): "mixer -s vol" prints "vol:0.50:0.50" (FreeBSD 14: "vol = 0.50:0.50" with -s too); the first number is the left channel */
static double first_float(const char *s)
{
	for (; *s; s++) if (isdigit((unsigned char)*s) && (s == (char *)s || 1)) { char *e; double v = strtod(s, &e); if (e != s) return v; }
	return -1;
}
double ccp_volume_get(void)
{
	if (!tool("/usr/sbin/mixer")) return -1; char o[256]; if (runp("/usr/sbin/mixer", "-s vol 2>/dev/null", o, sizeof o) != 0 || !*o) return -1;
	const char *colon = strchr(o, ':'); return first_float(colon ? colon + 1 : o);
}
int ccp_volume_set(double v)
{
	if (!tool("/usr/sbin/mixer") || ccp_volume_get() < 0) return 0; if (v < 0) v = 0; if (v > 1) v = 1; char a[48]; snprintf(a, sizeof a, "vol=%.2f >/dev/null 2>&1", v); return runp("/usr/sbin/mixer", a, NULL, 0) == 0;
}
/* brightness: backlight(8) (a KMS driver) prints the percent; else the ACPI video sysctl (percent) */
double ccp_brightness_get(void)
{
	char o[128];
	if (tool("/usr/bin/backlight") && runp("/usr/bin/backlight", "2>/dev/null", o, sizeof o) == 0) { double v = first_float(o); if (v >= 0) return v / 100.0; }
	int v; if (sys_int("hw.acpi.video.lcd0.brightness", &v)) return v / 100.0;
	return -1;
}
int ccp_brightness_set(double x)
{
	if (ccp_brightness_get() < 0) return 0; int pc = (int)lround((x < 0 ? 0 : x > 1 ? 1 : x) * 100);
	if (tool("/usr/bin/backlight")) { char a[48]; snprintf(a, sizeof a, "%d >/dev/null 2>&1", pc); if (runp("/usr/bin/backlight", a, NULL, 0) == 0) return 1; }
	return set_int("hw.acpi.video.lcd0.brightness", pc);
}
int ccp_battery_percent(void) { int v; return sys_int("hw.acpi.battery.life", &v) && v >= 0 && v <= 100 ? v : -1; }
int ccp_battery_charging(void) { int v; return sys_int("hw.acpi.battery.state", &v) && (v & 2); }
double ccp_kbd_get(void) { int v; return sys_int("dev.clevo_dchu.0.kb_brightness", &v) ? v / 255.0 : -1; }
int ccp_kbd_set(double x) { return set_int("dev.clevo_dchu.0.kb_brightness", (int)lround((x < 0 ? 0 : x > 1 ? 1 : x) * 255)); }

/* Wi-Fi: the first wlan interface of "ifconfig -l"; power = the UP flag */
int ccp_wifi_interface(char *name, int size)
{
	if (!tool("/sbin/ifconfig")) return 0; char o[512]; if (runp("/sbin/ifconfig", "-l 2>/dev/null", o, sizeof o) != 0) return 0;
	for (char *t = strtok(o, " \n"); t; t = strtok(NULL, " \n")) if (!strncmp(t, "wlan", 4)) { snprintf(name, size, "%s", t); return 1; }
	return 0;
}
int ccp_wifi_power(void)
{
	char ifn[32], a[64], o[1024]; if (!ccp_wifi_interface(ifn, sizeof ifn)) return -1;
	snprintf(a, sizeof a, "%s 2>/dev/null", ifn); if (runp("/sbin/ifconfig", a, o, sizeof o) != 0) return -1;
	char *f = strstr(o, "flags="); if (!f) return -1; char *lt = strchr(f, '<'), *gt = lt ? strchr(lt, '>') : NULL; if (!lt || !gt) return -1;
	*gt = 0; return strstr(lt, "UP") != NULL;
}
int ccp_wifi_set(int on)
{
	char ifn[32], a[64]; if (!ccp_wifi_interface(ifn, sizeof ifn)) return 0;
	snprintf(a, sizeof a, "%s %s >/dev/null 2>&1", ifn, on ? "up" : "down"); return runp("/sbin/ifconfig", a, NULL, 0) == 0;
}
/* Bluetooth: a controller is a netgraph node of type ubt (USB) with an hci node above it; power = the bluetooth rc service running (service bluetooth onestart / onestop) */
int ccp_bluetooth_power(void)
{
	if (!tool("/usr/sbin/ngctl")) return -1; char o[2048]; if (runp("/usr/sbin/ngctl", "list 2>/dev/null", o, sizeof o) != 0) return -1;
	if (!strstr(o, "type: ubt") && !strstr(o, "Type: ubt") && !strstr(o, "type: btccc") && !strstr(o, "ubt")) return -1;
	return strstr(o, "hci") != NULL;
}
int ccp_bluetooth_set(int on)
{
	if (ccp_bluetooth_power() < 0) return 0; char a[64]; snprintf(a, sizeof a, "bluetooth %s >/dev/null 2>&1", on ? "onestart" : "onestop"); return runp("/usr/sbin/service", a, NULL, 0) == 0;
}

/* sound: /dev/sndstat lines look like "pcm0: <Intel Alder Lake-P (HDA Realtek ALC...)> (play/rec) default"; the unit number is the digits after "pcm" */
static int sound_units[16];
int ccp_sound_list(char names[][64], int max, int *current)
{
	char b[256]; const char *path = P("/dev/sndstat", b, sizeof b); FILE *f = fopen(path, "r"); if (!f) return 0; char line[512]; int n = 0; if (current) *current = -1;
	while (fgets(line, sizeof line, f) && n < max && n < 16) {
		if (strncmp(line, "pcm", 3) || !isdigit((unsigned char)line[3])) continue;
		int unit = atoi(line + 3); char *lt = strchr(line, '<'), *gt = lt ? strrchr(line, '>') : NULL; if (!lt || !gt || gt < lt) continue;
		*gt = 0; if (!strstr(gt + 1, "play")) continue;                      /* outputs only */
		snprintf(names[n], 64, "%s", lt + 1); sound_units[n] = unit; if (current && strstr(gt + 1, "default")) *current = n; n++;
	}
	fclose(f); return n;
}
int ccp_sound_set(int index)
{
	char names[16][64]; int cur, n = ccp_sound_list(names, 16, &cur); if (index < 0 || index >= n) return 0; return set_int("hw.snd.default_unit", sound_units[index]);
}
/* Wi-Fi scan: the first column of "ifconfig wlanN list scan" is the SSID (it can contain spaces: the BSSID column starts at a fixed offset, so cut at the first MAC-looking field) */
int ccp_wifi_scan(char names[][64], int max)
{
	char ifn[32], a[64], o[8192]; if (!ccp_wifi_interface(ifn, sizeof ifn)) return 0; snprintf(a, sizeof a, "%s list scan 2>/dev/null", ifn); if (runp("/sbin/ifconfig", a, o, sizeof o) != 0) return 0;
	int n = 0; char *save = NULL; (void)strtok_r(o, "\n", &save);                      /* header */
	for (char *l = strtok_r(NULL, "\n", &save); l && n < max; l = strtok_r(NULL, "\n", &save)) {
		char *m = l; int cut = -1; for (; *m; m++) if (m[2] == ':' && isxdigit((unsigned char)m[0]) && isxdigit((unsigned char)m[1]) && m[5] == ':') { cut = (int)(m - l); break; }
		if (cut <= 0) continue; int e = cut; while (e > 0 && l[e - 1] == ' ') e--; if (e <= 0) continue; if (e > 63) e = 63; memcpy(names[n], l, e); names[n][e] = 0; n++;
	}
	return n;
}
