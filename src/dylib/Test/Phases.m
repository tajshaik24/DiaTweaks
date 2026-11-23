#import <objc/runtime.h>
#import "Test/Test.h"

// The test covers both tab layouts by setting them through Dia's own AppleScript support, run inside Dia: unlike the
// View menu, it needs no key window, which a Dia started for testing doesn't get while another app is in front.
// Auto-Hide Tabs isn't scriptable, so the run that wants it (DIAPATCH_TEST_AUTOHIDE) turns it on through Dia's own
// View > Auto-Hide Tabs item, sent to the item's own target, which needs no key window.

NSMutableArray<NSString *> *DPSwitchLog;

static NSString *DPScript(NSString *body) {
    NSString *source = [NSString stringWithFormat:@"tell application id \"%@\"\n%@\nend tell", NSBundle.mainBundle.bundleIdentifier, body];
    NSDictionary *error = nil;
    NSAppleEventDescriptor *result = [[[NSAppleScript alloc] initWithSource:source] executeAndReturnError:&error];
    return error ? [NSString stringWithFormat:@"error: %@", error[NSAppleScriptErrorMessage]] : result.stringValue ?: @"";
}

BOOL DPAutoHideRun(void) { return getenv("DIAPATCH_TEST_AUTOHIDE") != NULL; }

// Whether the front window's tabs are auto-hidden: the sidebar then waits off the window's left edge, and the top
// strip shrinks to a sliver, until the pointer reaches it.
static BOOL DPTabsHidden(void) {
    for (NSWindow *window in NSApp.orderedWindows) {
        NSView *root = window.contentView.superview ?: window.contentView;
        if (!window.isVisible || !DPFindView(root, ^BOOL(NSView *view) { return DPIsKind(view, DPDiaContentPane); })) continue;
        NSView *footer = DPFindView(root, ^BOOL(NSView *view) { return DPIsKind(view, DPDiaSidebarFooter); });
        if (footer) return NSMinX([footer convertRect:footer.bounds toView:nil]) < 0;
        NSView *clip = DPFindView(root, ^BOOL(NSView *view) { return DPIsKind(view, "_TtC6Window20TabStripClippingView"); });
        return clip && NSHeight(clip.frame) < 20;
    }
    return NO;
}

// nil when the tabs are auto-hidden exactly when this run expects them to be.
NSString *DPCheckAutoHide(void) {
    if (DPTabsHidden() == DPAutoHideRun()) return nil;
    return DPAutoHideRun() ? @"the tabs show, but this run saved Auto-Hide Tabs on" : @"the tabs are hidden, but this run saved Auto-Hide Tabs off";
}

NSString *DPPhaseName(void) {
    NSString *tabs = [DPTabLayout() isEqualToString:@"vertical"] ? @"sidebar" : @"top";
    return DPAutoHideRun() ? [tabs stringByAppendingString:@", auto-hide"] : tabs;
}

// Moves every window's tabs to the other layout, then waits for Dia to settle. `moved` says whether it took.
void DPSwitchLayout(void (^done)(BOOL moved)) {
    NSString *layout = DPTabLayout();
    NSString *target = [layout isEqualToString:@"vertical"] ? @"tabStrip" : @"sidebar";
    NSString *said = DPScript([NSString stringWithFormat:@"set tab layout of every window to \"%@\"", target]);
    __block int waits = 0;
    [NSTimer scheduledTimerWithTimeInterval:0.25 repeats:YES block:^(NSTimer *timer) {
        BOOL moved = ![DPTabLayout() isEqualToString:layout];
        if (!moved && ++waits < 40) return;
        [timer invalidate];
        if (!moved) {
            if (!DPSwitchLog) DPSwitchLog = [NSMutableArray array];
            [DPSwitchLog addObject:[NSString stringWithFormat:@"setting tab layout to %@ said \"%@\" and left it %@", target, said, DPTabLayout()]];
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{ done(moved); });
    }];
}

// With tabs auto-hidden, each patch on its own is enough to catch what hiding the tabs breaks.
NSArray<NSArray<NSString *> *> *DPAutoHideScenarios(NSArray<NSArray<NSString *> *> *all) {
    NSMutableArray<NSArray<NSString *> *> *some = [NSMutableArray array];
    for (NSArray<NSString *> *scenario in all)
        if (![scenario[0] hasPrefix:@"pairwise"] && ![scenario[0] isEqualToString:@"at launch"]) [some addObject:scenario];
    return some;
}

// View > Auto-Hide Tabs (Dia calls it Focus Mode inside), found by its title or its action.
static NSMenuItem *DPFocusModeItem(NSMenu *menu) {
    for (NSMenuItem *item in menu.itemArray) {
        if (item.action && ([item.title isEqualToString:@"Auto-Hide Tabs"]
                            || [NSStringFromSelector(item.action).lowercaseString containsString:@"focusmode"])) return item;
        NSMenuItem *found = item.submenu ? DPFocusModeItem(item.submenu) : nil;
        if (found) return found;
    }
    return nil;
}

static NSWindow *DPFrontBrowserWindow(void) {
    for (NSWindow *window in NSApp.orderedWindows) {
        NSView *root = window.contentView.superview ?: window.contentView;
        if (window.isVisible && DPFindView(root, ^BOOL(NSView *view) { return DPIsKind(view, DPDiaContentPane); })) return window;
    }
    return nil;
}

static void DPLog(NSString *line) {
    if (!DPSwitchLog) DPSwitchLog = [NSMutableArray array];
    [DPSwitchLog addObject:line];
}

// Readies the window a run tests in, so it needn't come from saved state: a web page in front, for the checks that
// need a real tab, and Auto-Hide Tabs set the way this run wants it.
void DPPrepareWindow(void (^done)(void)) {
    if (![DPScript(@"get URL of active tab of window 1") hasPrefix:@"http"])
        DPScript(@"make new tab at end of tabs of window 1 with properties {URL:\"https://example.com\"}");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (DPTabsHidden() == DPAutoHideRun()) return done();
        NSMenuItem *item = DPFocusModeItem(NSApp.mainMenu);
        if (!item) {
            DPLog(@"found no Auto-Hide Tabs menu item");
            return done();
        }
        // Dia applies the item to the key window, and only enables it while Dia is the front app. A test Dia in the
        // background has no key window, so for this one call AppKit reports the test window as key and main.
        NSWindow *window = DPFrontBrowserWindow();
        Method key = class_getInstanceMethod(NSApplication.class, @selector(keyWindow));
        Method main = class_getInstanceMethod(NSApplication.class, @selector(mainWindow));
        IMP oldKey = method_getImplementation(key), oldMain = method_getImplementation(main);
        IMP ours = imp_implementationWithBlock(^NSWindow *(id app) { return window; });
        method_setImplementation(key, ours);
        method_setImplementation(main, ours);
        BOOL sent = item.target && [NSApp sendAction:item.action to:item.target from:item];
        method_setImplementation(key, oldKey);
        method_setImplementation(main, oldMain);
        if (!sent) DPLog([NSString stringWithFormat:@"nothing took %@ to set Auto-Hide Tabs", NSStringFromSelector(item.action)]);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            if (DPTabsHidden() != DPAutoHideRun()) DPLog(@"Auto-Hide Tabs didn't change when the test set it");
            done();
        });
    });
}
