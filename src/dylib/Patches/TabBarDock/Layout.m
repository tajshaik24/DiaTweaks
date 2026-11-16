#import "Patches/TabBarDock/Layout.h"

static char DPDiaWidthKey, DPHiddenKey, DPShiftedFrameKey, DPShiftKey, DPPinnedHiddenKey;
static const CGFloat DPPillPadding = 10;
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

// Dia sizes the box to the switcher plus the pinned tabs, so it's empty when it's no wider than the switcher,
// or when this hides the pinned tabs.
static BOOL DPDockIsEmpty(NSView *dock) {
    NSView *switcher = DPSubview(dock, DPDiaTabStripSwitcher);
    return switcher && (DPHidePinnedTabsInTabBar.on || DPDiaWidth(dock) - NSWidth(switcher.frame) < 1);
}

// The box keeps its pinned tabs in TabSurface's dock, the one the sidebar uses too; only the box's copies hide.
static void DPHidePinnedTabs(NSView *dock) {
    for (NSView *sub in dock.subviews) {
        if (!DPIsKind(sub, "_TtC10TabSurface11TabDockView")) continue;
        BOOL ours = [DPGet(sub, &DPPinnedHiddenKey) boolValue];
        if (DPHidePinnedTabsInTabBar.on && !sub.hidden) {
            sub.hidden = YES;
            DPSet(sub, &DPPinnedHiddenKey, @YES);
        } else if (!DPHidePinnedTabsInTabBar.on && ours) {
            sub.hidden = NO;
            DPSet(sub, &DPPinnedHiddenKey, nil);
        }
    }
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

// Without the name the pill only needs room for the page dots, centred.
static void DPNarrowSwitcher(NSView *dock) {
    NSView *switcher = DPSubview(dock, DPDiaTabStripSwitcher);
    NSView *names = DPSubview(switcher, "_TtGC5ARCUI22FeatheredContainerViewCSo6NSView_");
    NSView *dots = DPFindView(switcher, ^BOOL(NSView *view) { return DPIsKind(view, "_TtC8TabStrip17PageIndicatorView"); });
    NSView *pinned = DPSubview(dock, "_TtC10TabSurface11TabDockView");
    if (!switcher || !names) return;
    names.hidden = DPHideProfileName.on;
    if (!DPHideProfileName.on || !DPMayAdjust(switcher)) return;
    CGFloat width = MAX(NSHeight(switcher.frame), (dots && !dots.hidden ? NSWidth(dots.frame) : 0) + 2 * DPPillPadding);
    CGFloat saved = NSWidth(switcher.frame) - width;
    if (saved <= 0) return;
    [switcher setFrameSize:NSMakeSize(width, NSHeight(switcher.frame))];
    if (pinned) [pinned setFrameOrigin:NSMakePoint(NSMinX(pinned.frame) - saved, NSMinY(pinned.frame))];
}

void DPUpdateTabBar(NSView *root) {
    NSView *dock = DPSubview(root, DPDiaTabStripDock), *strip = DPStripIn(root);
    if (!dock || !strip) return;
    BOOL hiddenByUs = [DPGet(dock, &DPHiddenKey) boolValue];
    BOOL collapse = DPHideEmptyTabBarDock.on && DPDockIsEmpty(dock) && (hiddenByUs || !dock.hidden);
    if (collapse != hiddenByUs) {
        dock.hidden = collapse;
        DPSet(dock, &DPHiddenKey, collapse ? @YES : nil);
    }
    CGFloat diaWidth = DPDiaWidth(dock), shift = 0;
    if (collapse) {
        CGFloat first = DPFirstTabX(strip);
        if (first < CGFLOAT_MAX) shift = MAX(0, [strip convertPoint:NSMakePoint(first, 0) toView:root].x + DPAppliedShift(strip) - NSMinX(dock.frame));
    } else {
        NSView *switcher = DPSubview(dock, DPDiaTabStripSwitcher);
        NSView *pinned = DPSubview(dock, "_TtC10TabSurface11TabDockView");
        BOOL pinnedShow = pinned && !pinned.hidden && NSWidth(pinned.frame) > 0;
        CGFloat end = MAX(NSMaxX(switcher.frame), pinnedShow ? NSMaxX(pinned.frame) : 0);
        if ((DPHideProfileName.on || DPHidePinnedTabsInTabBar.on) && end > 0 && end < diaWidth && DPMayAdjust(dock)) DPSizeDock(dock, end);
        shift = MAX(0, diaWidth - NSWidth(dock.frame));
    }
    DPShiftStrip(strip, shift);
}

static void DPRoot_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPRoot_layout, self);
    DPUpdateTabBar(self);
}

// Dia sets the box's size from its own model; remember it, and narrow the box again if the name is hidden.
static void DPDock_setFrameSize(NSView *self, SEL _cmd, NSSize size) {
    if (!DPSizing) DPSet(self, &DPDiaWidthKey, @(size.width));
    DPCallOriginal(DPDock_setFrameSize, self, size);
    if (!DPSizing && self.superview) {
        DPSizing = YES;
        DPUpdateTabBar(self.superview);
        DPSizing = NO;
    }
}

// The switcher puts its dots under the name; with the name gone they sit in the middle of the pill.
static void DPSwitcher_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPSwitcher_layout, self);
    NSView *dots = DPFindView(self, ^BOOL(NSView *view) { return DPIsKind(view, "_TtC8TabStrip17PageIndicatorView"); });
    if (!DPHideProfileName.on || !dots || !DPIsKind(self.superview, DPDiaTabStripDock)) return;
    [dots setFrameOrigin:NSMakePoint(round((NSWidth(self.bounds) - NSWidth(dots.frame)) / 2), round((NSHeight(self.bounds) - NSHeight(dots.frame)) / 2))];
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
        if (patch == &DPHideEmptyTabBarDock) {
            if (patch->on && DPDockIsEmpty(dock) && !dock.hidden) return @"empty profile box still shows";
            if ((!patch->on || !DPDockIsEmpty(dock)) && hiddenByUs) return @"profile box still hidden";
            CGFloat first = DPFirstTabX(strip);
            if (hiddenByUs && first < CGFLOAT_MAX && fabs([strip convertPoint:NSMakePoint(first, 0) toView:root].x - NSMinX(dock.frame)) > 1)
                return @"tabs didn't move into the box's place";
        } else if (patch == &DPHidePinnedTabsInTabBar) {
            for (NSView *sub in dock.subviews)
                if (DPIsKind(sub, "_TtC10TabSurface11TabDockView") && patch->on && !sub.hidden) return @"pinned tabs still show in the tab bar";
                else if (DPIsKind(sub, "_TtC10TabSurface11TabDockView") && !patch->on && [DPGet(sub, &DPPinnedHiddenKey) boolValue]) return @"pinned tabs still hidden";
        } else if (!dock.hidden) {
            NSView *names = DPSubview(DPSubview(dock, DPDiaTabStripSwitcher), "_TtGC5ARCUI22FeatheredContainerViewCSo6NSView_");
            if (names && names.hidden != patch->on) return patch->on ? @"profile name still shows" : @"profile name still hidden";
        }
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
