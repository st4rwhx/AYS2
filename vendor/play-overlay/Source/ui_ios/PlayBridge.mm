// PlayBridge.mm — see PlayBridge.h.
// AYS2 overlay file for vendor/play-overlay (see docs/AYS2_PLAY_OVERLAY.md).
// SPDX-License-Identifier: GPL-3.0+

#import "PlayBridge.h"
#import "EmulatorViewController.h"
#import "SettingsViewController.h"
#import "AltServerJitService.h"
#import "../ui_shared/BootablesProcesses.h"
#import "../ui_shared/BootablesDbClient.h"
#import "PathUtils.h"
#include <ctime>

// AYS2: not a public header declaration (seam) — same undocumented syscall
// AYS2's own DarwinMisc.cpp uses for its IsJITAvailable(). CS_OPS_STATUS is
// 0; bit 0x10000000 in the returned flags is CS_DEBUGGED.
extern "C" int csops(pid_t pid, unsigned int ops, void* useraddr, size_t usersize);

@implementation PlayBridge

+ (void)refreshLibrary
{
	// Mirrors CoverViewController's own buildCollectionWithForcedFullScan:NO
	// path (non-destructive default scan, not the "full device scan" the
	// Settings screen can trigger) — same locations, same order.
	auto activeDirs = GetActiveBootableDirectories();
	for (const auto& activeDir : activeDirs)
	{
		ScanBootables(activeDir, false);
	}
	// Always scan app storage too — the app's sandbox path changes on
	// reinstall, so games from a previous install won't be found otherwise.
	ScanBootables(Framework::PathUtils::GetPersonalDataPath());
	PurgeInexistingFiles();
	FetchGameTitles();
}

+ (NSArray<NSDictionary<NSString*, NSString*>*>*)availableGames
{
	auto bootables = BootablesDb::CClient::GetInstance().GetBootables();
	NSMutableArray<NSDictionary<NSString*, NSString*>*>* result = [NSMutableArray arrayWithCapacity:bootables.size()];
	for (const auto& bootable : bootables)
	{
		[result addObject:@{
			@"title" : [NSString stringWithUTF8String:bootable.title.c_str()],
			@"path" : [NSString stringWithUTF8String:bootable.path.native().c_str()],
			@"coverUrl" : [NSString stringWithUTF8String:bootable.coverUrl.c_str()],
		}];
	}
	return result;
}

+ (void)bootGameAtPath:(NSString*)path presentingFrom:(UIViewController*)presenter
{
	fs::path bootablePath([path UTF8String]);
	BootablesDb::CClient::GetInstance().SetLastBootedTime(bootablePath, time(nullptr));

	UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
	EmulatorViewController* emulatorVC = [storyboard instantiateViewControllerWithIdentifier:@"EmulatorViewController"];
	emulatorVC.bootablePath = path;
	emulatorVC.modalPresentationStyle = UIModalPresentationFullScreen;
	[presenter presentViewController:emulatorVC animated:YES completion:nil];
}

+ (void)presentSettingsFrom:(UIViewController*)presenter
{
	UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
	UINavigationController* navVC = [storyboard instantiateViewControllerWithIdentifier:@"PlaySettingsNav"];
	SettingsViewController* settingsVC = (SettingsViewController*)navVC.visibleViewController;
	settingsVC.allowFullDeviceScan = true;
	settingsVC.allowGsHandlerSelection = true;
	// Mirrors CoverViewController's prepareForSegue:sender: handling for
	// "showSettings" exactly — restart AltServer's JIT process (settings may
	// have changed the script/state) and re-scan the library if the user hit
	// Full Device Scan. The scan itself runs off the main thread, same as
	// CoverViewController's own buildCollectionWithForcedFullScan: — a full
	// /private/var/mobile walk is real disk I/O, and this completion handler
	// fires on the main thread.
	settingsVC.completionHandler = ^(bool fullScanRequested) {
		[[AltServerJitService sharedAltServerJitService] startProcess];
		if (fullScanRequested)
		{
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
				ScanBootables("/private/var/mobile");
				ScanBootables(Framework::PathUtils::GetPersonalDataPath());
				PurgeInexistingFiles();
				FetchGameTitles();
			});
		}
	};
	[presenter presentViewController:navVC animated:YES completion:nil];
}

+ (BOOL)isJITAvailable
{
	uint32_t csFlags = 0;
	int rv = csops(getpid(), 0 /* CS_OPS_STATUS */, &csFlags, sizeof(csFlags));
	return (rv == 0) && ((csFlags & 0x10000000u) != 0); // CS_DEBUGGED
}

@end
