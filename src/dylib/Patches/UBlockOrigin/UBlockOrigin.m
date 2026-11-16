#import "Patches/UBlockOrigin/UBlockOrigin.h"
#import "Updates/Updates.h"

// Chromium reads extensions and its MV2 checks once, as Dia starts, so turning this on or off takes a relaunch.
static BOOL gRunning;
static BOOL gDownloading;

void DPAskToRelaunch(BOOL on) {
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
    if (gRunning || gDownloading) return;
    if (DPUBlockDownloaded()) return DPAskToRelaunch(YES);
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

// On a new Mac nothing is downloaded yet: fetch it while Dia starts and hold Chromium briefly so it loads on this launch.
// If it isn't ready in time, Chromium starts without it and the relaunch prompt follows once it is.
static void DPFetchBeforeChromium(void) {
    static const int64_t kWait = 10 * NSEC_PER_SEC;
    static BOOL gLate;
    static NSString *gProblem;
    static NSObject *gLock;
    gLock = [NSObject new];
    dispatch_semaphore_t ready = dispatch_semaphore_create(0);
    gDownloading = YES;
    // Not from here directly: this runs while dyld is still loading Dia, and starting the network then deadlocks.
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{ DPFetchUBlock(DPUBlockFolder(), ^(NSString *problem) {
        BOOL late;
        @synchronized(gLock) {
            gProblem = problem;
            late = gLate;
        }
        dispatch_semaphore_signal(ready);
        if (late) dispatch_async(dispatch_get_main_queue(), ^{
            gDownloading = NO;
            DPApplyUBlockOrigin(&DPUBlockOrigin);
        });
    }); });
    DPLoadExtension(DPUBlockFolder());
    DPBeforeExtensionsLoad(^{
        BOOL arrived = dispatch_semaphore_wait(ready, dispatch_time(DISPATCH_TIME_NOW, kWait)) == 0;
        @synchronized(gLock) {
            gLate = !arrived;
            if (arrived && !gProblem) gRunning = YES;
        }
        if (gRunning) {
            gDownloading = NO;
            return;
        }
        DPUnloadExtension(DPUBlockFolder());
        if (arrived) DPOnLaunch(^{
            gDownloading = NO;
            DPApplyUBlockOrigin(&DPUBlockOrigin);
        });
    });
}

static void DPInstallUBlockOrigin(void) {
    NSFileManager *files = NSFileManager.defaultManager;
    if (!DPUBlockOrigin.on) {
        [files removeItemAtPath:DPUBlockFolder() error:nil];
        [files removeItemAtPath:DPUBlockStaging() error:nil];
        return;
    }
    DPPromoteStagedUBlock();
    NSString *problem = DPOpenMV2Gates();
    if (problem) {
        NSLog(@"DiaPatches: uBlock Origin is unavailable: %@", problem);
        DPUBlockOrigin.unavailable = YES;
        DPUBlockOrigin.on = NO;
        return;
    }
    if (!DPUBlockInstalled()) return DPFetchBeforeChromium(), DPWatchUBlockStart();
    DPLoadExtension(DPUBlockFolder());
    gRunning = YES;
    DPWatchUBlockStart();
    // A newer pinned release waits beside this one and takes over at the next launch, with no prompt.
    if (!DPUBlockDownloaded()) DPOnLaunch(^{
        DPFetchUBlock(DPUBlockStaging(), ^(NSString *problem) {
            if (problem) NSLog(@"DiaPatches: couldn't stage the new uBlock Origin: %@", problem);
        });
    });
}

BOOL DPUBlockRunning(void) { return gRunning; }

DP_PATCH(DPUBlockOrigin) {
    .key = @"uBlockOrigin",
    .order = 106,
    .title = @"uBlock Origin",
    .detail = @"Block ads and trackers with the full uBlock Origin, which Dia’s Chromium no longer allows. DiaTweaks downloads a checked release, then reopens Chromium’s Manifest V2 check in memory each time Dia starts. Turning it on or off takes a relaunch. Experimental.",
    .symbol = @"shield.lefthalf.filled shield.fill",
    .tint = @"systemRedColor",
    .section = @"Privacy",
    .install = DPInstallUBlockOrigin,
    .apply = DPApplyUBlockOrigin,
};
