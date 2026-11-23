#import "Test/Test.h"

// The test covers both tab layouts by setting them through Dia's own AppleScript support, run inside Dia: unlike the
// View menu, it needs no key window, which a Dia started for testing doesn't get while another app is in front.
// Auto-Hide Tabs isn't scriptable, so the run that wants it (DIAPATCH_TEST_AUTOHIDE) turns it on through Dia's own
// Toggle Focus Mode action, sent along the window's responder chain, which also needs no key window.

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

// Dia's Toggle Focus Mode (Auto-Hide Tabs) item, found by its action so its title doesn't matter.
static NSMenuItem *DPFocusModeItem(NSMenu *menu) {
    for (NSMenuItem *item in menu.itemArray) {
        if (item.action && [NSStringFromSelector(item.action).lowercaseString containsString:@"focusmode"]) return item;
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
        if (DPTabsHidden() != DPAutoHideRun()) {
            NSMenuItem *item = DPFocusModeItem(NSApp.mainMenu);
            NSWindow *window = DPFrontBrowserWindow();
            if (!item) DPLog(@"found no Toggle Focus Mode menu item to set Auto-Hide Tabs");
            else if (![window.firstResponder ?: window tryToPerform:item.action with:item] && ![NSApp sendAction:item.action to:nil from:item])
                DPLog([NSString stringWithFormat:@"nothing took %@ to set Auto-Hide Tabs", NSStringFromSelector(item.action)]);
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), done);
    });
}
