#import "Patches/TabBarDock/Layout.h"

DP_PATCH(DPHidePinnedTabsInTabBar) {
    .key = @"hidePinnedTabsInTabBar",
    .order = 84,
    .title = @"Hide Pinned Tabs in Tab Bar",
    .detail = @"Take the pinned tabs, and the box with the profile name that holds them, out of the tab bar, and move the tabs up beside the window buttons. They stay pinned, and show again with tabs in the sidebar.",
    .symbol = @"pin.slash pin",
    .tint = @"systemYellowColor",
    .section = @"Horizontal Tabs",
    .classes = DPClasses(DPDiaTabStrip, DPDiaTabStripDock, DPDiaTabStripSwitcher, DPDiaTabStripContainer),
    .install = DPInstallTabBarDock,
    .apply = DPUpdateTabBars,
    .verify = DPVerifyTabBars,
};
