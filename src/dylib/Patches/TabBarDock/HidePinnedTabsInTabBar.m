#import "Patches/TabBarDock/Layout.h"

DP_PATCH(DPHidePinnedTabsInTabBar) {
    .key = @"hidePinnedTabsInTabBar",
    .order = 84,
    .title = @"Hide Pinned Tabs in Tab Bar",
    .detail = @"Keep pinned tabs out of the box beside the window buttons, and move the tabs up to it. They stay pinned, and show again with tabs in the sidebar.",
    .symbol = @"pin.slash pin",
    .tint = @"systemYellowColor",
    .section = @"Horizontal Tabs",
    .classes = DPClasses(DPDiaTabStrip, DPDiaTabStripDock, DPDiaTabStripSwitcher, DPDiaTabStripContainer),
    .install = DPInstallTabBarDock,
    .apply = DPUpdateTabBars,
    .verify = DPVerifyTabBars,
};
