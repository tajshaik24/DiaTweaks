#import "Patches/TabBarDock/Layout.h"

static char DPDiaWidthKey, DPHiddenKey, DPShiftedFrameKey, DPShiftKey;
static BOOL DPSizing;  // Set while this resizes the box itself, so only Dia's sizes are remembered.

static void DPSizeDock(NSView *dock, CGFloat width) {
    BOOL was = DPSizing;
    DPSizing = YES;
    [dock setFrameSize:NSMakeSize(width, NSHeight(dock.frame))];
    DPSizing = was;
}

static NSView *DPStripIn(NSView *root) {
    return DPFindView(root, ^BOOL(NSView *view) { return DPIsKind(view, DPDiaTabStripContainer); });
}

// The width Dia gave the box, before this narrowed it.
static CGFloat DPDiaWidth(NSView *dock) {
    NSNumber *width = DPGet(dock, &DPDiaWidthKey);
    return width ? width.doubleValue : NSWidth(dock.frame);
}

static CGFloat DPFirstTabX(NSView *strip) {
    CGFloat x = CGFLOAT_MAX;
    for (NSView *sub in strip.subviews)
        if (!sub.hidden && (DPIsKind(sub, DPDiaTabView) || DPIsKind(sub, DPDiaTabGroupView) || DPIsKind(sub, DPDiaTabSurfaceButton))) x = MIN(x, NSMinX(sub.frame));
    return x;
}

// The strip moves left by `shift` and grows by as much, so its right end stays and its own layout is untouched.
static void DPShiftStrip(NSView *strip, CGFloat shift) {
    NSValue *ours = DPGet(strip, &DPShiftedFrameKey);
    CGFloat applied = ours && NSEqualRects(ours.rectValue, strip.frame) ? [DPGet(strip, &DPShiftKey) doubleValue] : 0;
    NSRect frame = NSMakeRect(NSMinX(strip.frame) + applied - shift, NSMinY(strip.frame), NSWidth(strip.frame) - applied + shift, NSHeight(strip.frame));
    if (NSEqualRects(frame, strip.frame) || !DPMayAdjust(strip)) return;
    strip.frame = frame;
    DPSet(strip, &DPShiftedFrameKey, shift ? [NSValue valueWithRect:frame] : nil);
    DPSet(strip, &DPShiftKey, shift ? @(shift) : nil);
}

static CGFloat DPAppliedShift(NSView *strip) {
    NSValue *ours = DPGet(strip, &DPShiftedFrameKey);
    return ours && NSEqualRects(ours.rectValue, strip.frame) ? [DPGet(strip, &DPShiftKey) doubleValue] : 0;
}

// Once the toggles leave the box with neither pinned tabs nor a name to show, it goes: dots alone don't keep it.
static BOOL DPDockEmpty(NSView *dock) {
    return (DPHidePinnedTabsInTabBar.on || DPHideProfileName.on) && !DPPinnedTabsShow(dock) && !DPProfileNameShows(dock);
}

void DPUpdateTabBar(NSView *root) {
    NSView *dock = DPSubview(root, DPDiaTabStripDock), *strip = DPStripIn(root);
    if (!dock || !strip) return;
    BOOL hiddenByUs = [DPGet(dock, &DPHiddenKey) boolValue];
    BOOL collapse = DPDockEmpty(dock) && (hiddenByUs || !dock.hidden);
    if (collapse != hiddenByUs) {
        dock.hidden = collapse;
        DPSet(dock, &DPHiddenKey, collapse ? @YES : nil);
    }
    CGFloat diaWidth = DPDiaWidth(dock), shift = 0;
    if (collapse) {
        CGFloat first = DPFirstTabX(strip);
        if (first < CGFLOAT_MAX) shift = MAX(0, [strip convertPoint:NSMakePoint(first, 0) toView:root].x + DPAppliedShift(strip) - NSMinX(dock.frame));
    } else {
        // What's left decides the box's width: the pill, and the pinned tabs unless they're hidden.
        NSView *switcher = DPSubview(dock, DPDiaTabStripSwitcher), *pinned = DPPinnedTabsIn(dock);
        CGFloat end = MAX(NSMaxX(switcher.frame), DPPinnedTabsShow(dock) ? NSMaxX(pinned.frame) : 0);
        BOOL toggled = DPHidePinnedTabsInTabBar.on || DPHideProfileName.on;
        if (toggled && end > 0 && end < diaWidth && DPMayAdjust(dock)) DPSizeDock(dock, end);
        shift = MAX(0, diaWidth - NSWidth(dock.frame));
    }
    DPShiftStrip(strip, shift);
}

static void DPRoot_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPRoot_layout, self);
    DPUpdateTabBar(self);
}

// Dia sets the box's size from its own model; remember it, and narrow the box again if the toggles call for it.
static void DPDock_setFrameSize(NSView *self, SEL _cmd, NSSize size) {
    if (!DPSizing) DPSet(self, &DPDiaWidthKey, @(size.width));
    DPCallOriginal(DPDock_setFrameSize, self, size);
    if (!DPSizing && self.superview) {
        DPSizing = YES;
        DPUpdateTabBar(self.superview);
        DPSizing = NO;
    }
}

static void DPSwitcher_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPSwitcher_layout, self);
    DPCenterDots(self);
}

static void DPDock_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPDock_layout, self);
    DPHidePinnedTabs(self);
    DPNarrowSwitcher(self);
    if (!DPSizing && self.superview) {
        DPSizing = YES;
        DPUpdateTabBar(self.superview);
        DPSizing = NO;
    }
}

void DPUpdateTabBars(DPPatch *patch) {
    for (NSView *dock in DPFindViews(DPDiaTabStripDock)) {
        DPSizeDock(dock, DPDiaWidth(dock));
        DPHidePinnedTabs(dock);
        dock.needsLayout = YES;
        DPSubview(dock, DPDiaTabStripSwitcher).needsLayout = YES;
        [dock layoutSubtreeIfNeeded];
    }
    for (NSView *root in DPFindViews(DPDiaTabStrip)) DPUpdateTabBar(root);
}

NSString *DPVerifyTabBars(DPPatch *patch) {
    for (NSView *root in DPFindViews(DPDiaTabStrip)) {
        NSView *dock = DPSubview(root, DPDiaTabStripDock), *strip = DPStripIn(root);
        if (!root.window.isVisible || !dock || !strip) continue;
        BOOL hiddenByUs = [DPGet(dock, &DPHiddenKey) boolValue];
        if (patch == &DPHidePinnedTabsInTabBar) {
            if (patch->on && !hiddenByUs && DPPinnedTabsShow(dock)) return @"pinned tabs still show in the tab bar";
            if (!patch->on && DPPinnedTabsHiddenByUs(dock)) return @"pinned tabs still hidden";
        } else if (!hiddenByUs && DPProfileNameHidden(dock) != patch->on) {
            return patch->on ? @"profile name still shows" : @"profile name still hidden";
        }
        if (DPDockEmpty(dock) && !dock.hidden) return @"the box beside the window buttons shows with nothing in it";
        if (hiddenByUs && !DPDockEmpty(dock)) return @"the box beside the window buttons is hidden with something to show";
        CGFloat first = DPFirstTabX(strip);
        if (hiddenByUs && first < CGFLOAT_MAX && fabs([strip convertPoint:NSMakePoint(first, 0) toView:root].x - NSMinX(dock.frame)) > 1)
            return @"tabs didn't move into the box's place";
    }
    return nil;
}

void DPInstallTabBarDock(void) {
    static BOOL done;
    if (done) return;
    done = YES;
    DPHook(DPDiaTabStrip, @selector(layout), (IMP)DPRoot_layout);
    DPHook(DPDiaTabStripDock, @selector(setFrameSize:), (IMP)DPDock_setFrameSize);
    DPHook(DPDiaTabStripDock, @selector(layout), (IMP)DPDock_layout);
    DPHook(DPDiaTabStripSwitcher, @selector(layout), (IMP)DPSwitcher_layout);
}
