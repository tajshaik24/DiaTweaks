#import "Patches/TabBarDock/Layout.h"

// What the box beside the window buttons holds: the profile pill (its name over the profile dots) and the profile's
// pinned tabs, in the same TabSurface dock the sidebar uses. Each toggle hides one; the box goes once both are gone.

static char DPPinnedHiddenKey;
static const CGFloat DPPillPadding = 10;
#define DPPinnedDock "_TtC10TabSurface11TabDockView"
#define DPPillNames  "_TtGC5ARCUI22FeatheredContainerViewCSo6NSView_"
#define DPPillDots   "_TtC8TabStrip17PageIndicatorView"

NSView *DPPinnedTabsIn(NSView *dock) { return DPSubview(dock, DPPinnedDock); }

static NSView *DPNamesIn(NSView *dock) { return DPSubview(DPSubview(dock, DPDiaTabStripSwitcher), DPPillNames); }

void DPHidePinnedTabs(NSView *dock) {
    for (NSView *sub in dock.subviews) {
        if (!DPIsKind(sub, DPPinnedDock)) continue;
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

BOOL DPPinnedTabsHiddenByUs(NSView *dock) {
    for (NSView *sub in dock.subviews)
        if (DPIsKind(sub, DPPinnedDock) && [DPGet(sub, &DPPinnedHiddenKey) boolValue]) return YES;
    return NO;
}

BOOL DPPinnedTabsShow(NSView *dock) {
    for (NSView *sub in dock.subviews)
        if (DPIsKind(sub, DPPinnedDock) && !sub.hidden && NSWidth(sub.frame) > 0) return YES;
    return NO;
}

// A profile's name shows unless this hides it; Dia shows none on an account with only one profile.
BOOL DPProfileNameShows(NSView *dock) {
    NSView *names = DPNamesIn(dock);
    if (!names || names.hidden) return NO;
    return DPFindView(names, ^BOOL(NSView *view) {
        if (![view isKindOfClass:NSTextField.class] || !((NSTextField *)view).stringValue.length) return NO;
        for (NSView *up = view; up && up != names; up = up.superview) if (up.hidden || up.alphaValue < 0.01) return NO;
        return YES;
    }) != nil;
}

BOOL DPProfileNameHidden(NSView *dock) { return DPNamesIn(dock).hidden; }

// Without the name the pill only needs room for the profile dots.
void DPNarrowSwitcher(NSView *dock) {
    NSView *switcher = DPSubview(dock, DPDiaTabStripSwitcher), *names = DPNamesIn(dock);
    NSView *dots = DPFindView(switcher, ^BOOL(NSView *view) { return DPIsKind(view, DPPillDots); });
    NSView *pinned = DPPinnedTabsIn(dock);
    if (!switcher || !names) return;
    names.hidden = DPHideProfileName.on;
    if (!DPHideProfileName.on || !DPMayAdjust(switcher)) return;
    CGFloat width = MAX(NSHeight(switcher.frame), (dots && !dots.hidden ? NSWidth(dots.frame) : 0) + 2 * DPPillPadding);
    CGFloat saved = NSWidth(switcher.frame) - width;
    if (saved <= 0) return;
    [switcher setFrameSize:NSMakeSize(width, NSHeight(switcher.frame))];
    if (pinned) [pinned setFrameOrigin:NSMakePoint(NSMinX(pinned.frame) - saved, NSMinY(pinned.frame))];
}

// The switcher puts its dots under the name; with the name gone they sit in the middle of the pill.
void DPCenterDots(NSView *switcher) {
    NSView *dots = DPFindView(switcher, ^BOOL(NSView *view) { return DPIsKind(view, DPPillDots); });
    if (!DPHideProfileName.on || !dots || !DPIsKind(switcher.superview, DPDiaTabStripDock)) return;
    [dots setFrameOrigin:NSMakePoint(round((NSWidth(switcher.bounds) - NSWidth(dots.frame)) / 2), round((NSHeight(switcher.bounds) - NSHeight(dots.frame)) / 2))];
}
