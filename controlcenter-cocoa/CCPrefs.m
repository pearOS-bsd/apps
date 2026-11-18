/* Preference keys the real ControlCenter reads at startup (CFPreferencesCopyAppValue, current application), in trace order (research/cc-trace).  The real process reads most of them
 * through frameworks (Foundation, AppKit, CoreGraphics, ...); ours reads them here until the same frameworks do it.  TODO(feature): values are not used yet. */
#import "CCPrefs.h"
#import <CoreFoundation/CoreFoundation.h>
static CFStringRef const kKeys[] = {
	(__bridge CFStringRef)@"AppleLanguages",
	(__bridge CFStringRef)@"IIOEnableOOP",
	(__bridge CFStringRef)@"NSTallLocalizedStrings",
	(__bridge CFStringRef)@"NSAppNapLaunchDelay",
	(__bridge CFStringRef)@"AppleReduceDesktopTinting",
	(__bridge CFStringRef)@"automatic_fig_notes",
	(__bridge CFStringRef)@"avauvoiceiochatflavor_trace",
	(__bridge CFStringRef)@"avcaptureproprietarydefaultssingleton_trace",
	(__bridge CFStringRef)@"gm_signpost",
	(__bridge CFStringRef)@"classroomRoles",
	(__bridge CFStringRef)@"avcapturedevice_trace",
	(__bridge CFStringRef)@"avcapturedaldevice_trace",
	(__bridge CFStringRef)@"camera_stack_initiator_logging",
	(__bridge CFStringRef)@"cmcaptureframereceiver_trace",
	(__bridge CFStringRef)@"gestures-enabled-default",
	(__bridge CFStringRef)@"Device Access Allowed",
	(__bridge CFStringRef)@"Assistant Enabled",
	(__bridge CFStringRef)@"AppleICUForce12HourTime",
	(__bridge CFStringRef)@"AppleICUForce24HourTime",
	(__bridge CFStringRef)@"AppleFirstWeekday",
	(__bridge CFStringRef)@"AppleCollationOrder",
	(__bridge CFStringRef)@"AppleICUNumberSymbols",
	(__bridge CFStringRef)@"AppleMetricUnits",
	(__bridge CFStringRef)@"AppleMeasurementUnits",
	(__bridge CFStringRef)@"AppleICUDateFormatStrings",
	(__bridge CFStringRef)@"AppleICUTimeFormatStrings",
	(__bridge CFStringRef)@"AppleICUDateTimeSymbols",
	(__bridge CFStringRef)@"NSUserKeyEquivalents",
	(__bridge CFStringRef)@"ImageIO_CopyInputData",
	(__bridge CFStringRef)@"AppleTISLocalCFPrefsRead",
	(__bridge CFStringRef)@"AppleTestLiveResize",
	(__bridge CFStringRef)@"AppleDebugPrintWindowList",
	(__bridge CFStringRef)@"CUIHotKeys",
	(__bridge CFStringRef)@"TSMTraceInputSourceNotifications",
	(__bridge CFStringRef)@"FloatingIndicatorEnabled",
	(__bridge CFStringRef)@"TSMLanguageIndicatorEnabled",
	(__bridge CFStringRef)@"TISDisableAbortOnNonMainThread",
	(__bridge CFStringRef)@"AppleTISTraceCacheRebuild",
	(__bridge CFStringRef)@"ABDefaultSourceID",
	(__bridge CFStringRef)@"AppleEnabledThirdPartyInputSources",
	(__bridge CFStringRef)@"TSMTraceInputSourceSelection",
	(__bridge CFStringRef)@"AppleTISAllowCapsLockLayoutSwitching",
	(__bridge CFStringRef)@"Session Language",
	(__bridge CFStringRef)@"Additional Languages",
	(__bridge CFStringRef)@"TSMTraceCapsLockPressAndHold",
	(__bridge CFStringRef)@"ABMetadataValidationLogLevel",
	(__bridge CFStringRef)@"ABMetadataLastOilChange"
};
void CCReadPreferences(void)
{
	for (size_t i = 0; i < sizeof kKeys / sizeof *kKeys; i++) {
		CFTypeRef v = CFPreferencesCopyAppValue(kKeys[i], kCFPreferencesCurrentApplication);     /* constant strings: the trace reads the key from the string's data pointer */
		if (v) CFRelease(v);
	}
}
