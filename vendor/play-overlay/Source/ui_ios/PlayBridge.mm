// PlayBridge.mm — see PlayBridge.h.
// AYS2 overlay file for vendor/play-overlay (see docs/AYS2_PLAY_OVERLAY.md).
// SPDX-License-Identifier: GPL-3.0+

#import "PlayBridge.h"
#import "EmulatorViewController.h"
#import "../ui_shared/BootablesProcesses.h"
#import "../ui_shared/BootablesDbClient.h"
#import "PathUtils.h"
#include <ctime>

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

@end
