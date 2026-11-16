#import "Patches/UBlockOrigin/UBlockOrigin.h"

// Chromium can still turn the extension away, so a few seconds after launch this asks Dia whether uBlock Origin
// actually started, and offers the relaunch instead of leaving it to be noticed on the extensions page.
static NSString *const kID = @"fhlpapgmjejklmhcgeafaeilmmhdcack";
static NSHashTable *DPBrowsers;

static void DPBrowser_setWindow(id self, SEL _cmd, NSWindow *window) {
    DPCallOriginal(DPBrowser_setWindow, self, window);
    if (window) [DPBrowsers addObject:self];
}

static BOOL DPStarted(id browser) {
    id extensions = [[browser performSelector:@selector(context)] performSelector:@selector(extensions)];
    for (id info in [extensions performSelector:@selector(listExtensions)])
        if ([[info valueForKey:@"id"] isEqual:kID]) return [[info valueForKey:@"enabled"] boolValue];
    return NO;
}

void DPWatchUBlockStart(void) {
    DPBrowsers = [NSHashTable weakObjectsHashTable];
    DPHook(DPDiaBrowser, @selector(setWindow:), (IMP)DPBrowser_setWindow);
    DPOnLaunch(^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 8 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            id browser = DPBrowsers.anyObject;
            if (!DPUBlockOrigin.on || !DPUBlockRunning() || !browser || DPStarted(browser)) return;
            NSLog(@"DiaPatches: uBlock Origin was handed to Chromium but didn't start");
            // A damaged copy would fail again, so the relaunch fetches a clean one before Chromium starts.
            [NSFileManager.defaultManager removeItemAtPath:DPUBlockFolder() error:nil];
            DPAskToRelaunch(YES);
        });
    });
}
