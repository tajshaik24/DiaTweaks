#import "Patches/UBlockOrigin/UBlockOrigin.h"
#import "Updates/Updates.h"

// Chromium reads extensions and its MV2 checks once, as Dia starts, so turning this on or off takes a relaunch.
static BOOL gRunning;
static BOOL gDownloading;

static void DPAskToRelaunch(BOOL on) {
    NSAlert *alert = [NSAlert new];
    alert.messageText = on ? @"Relaunch Dia to start uBlock Origin" : @"Relaunch Dia to stop uBlock Origin";
    [alert addButtonWithTitle:@"Relaunch"];
    [alert addButtonWithTitle:@"Later"];
    if ([alert runModal] == NSAlertFirstButtonReturn) DPHandOffAndQuit(@[ @"apply" ]);
}

static void DPApplyUBlockOrigin(DPPatch *patch) {
    if (patch->on != DPSavedOn(patch)) return;  // The self-test flips patches without saving.
    if (!patch->on) {
        if (gRunning) DPAskToRelaunch(NO);
        return;
    }
    if (gRunning) return;
    if (DPUBlockDownloaded()) return DPAskToRelaunch(YES);
    if (gDownloading) return;
    gDownloading = YES;
    DPDownloadUBlock(^(NSString *problem) {
        gDownloading = NO;
        if (!problem) return DPAskToRelaunch(YES);
        DPSetPatch(&DPUBlockOrigin, NO, YES);
        NSAlert *alert = [NSAlert new];
        alert.messageText = @"Couldn’t turn on uBlock Origin";
        alert.informativeText = problem;
        [alert runModal];
    });
}

static void DPInstallUBlockOrigin(void) {
    if (!DPUBlockOrigin.on) {
        [NSFileManager.defaultManager removeItemAtPath:DPUBlockFolder() error:nil];
        return;
    }
    if (!DPUBlockDownloaded()) return DPOnLaunch(^{ DPApplyUBlockOrigin(&DPUBlockOrigin); });
    NSString *problem = DPOpenMV2Gates();
    if (problem) {
        NSLog(@"DiaPatches: uBlock Origin is unavailable: %@", problem);
        DPUBlockOrigin.unavailable = YES;
        DPUBlockOrigin.on = NO;
        return;
    }
    DPLoadExtension(DPUBlockFolder());
    gRunning = YES;
    NSLog(@"DiaPatches: uBlock Origin %@ loaded with Dia's MV2 checks open", DPUBlockFolder());
}

DP_PATCH(DPUBlockOrigin) {
    .key = @"uBlockOrigin",
    .order = 106,
    .title = @"uBlock Origin",
    .detail = @"Block ads and trackers with the full uBlock Origin, which Dia’s Chromium no longer allows. DiaTweaks downloads a checked release, then reopens Chromium’s Manifest V2 check in memory each time Dia starts. Needs a relaunch. Experimental.",
    .symbol = @"shield.lefthalf.filled shield.fill",
    .tint = @"systemRedColor",
    .section = @"Privacy",
    .install = DPInstallUBlockOrigin,
    .apply = DPApplyUBlockOrigin,
};
