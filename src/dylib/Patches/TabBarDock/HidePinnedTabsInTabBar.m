#import "Patches/TabBarDock/Layout.h"

DP_PATCH(DPHidePinnedTabsInTabBar) {
    .key = @"hidePinnedTabsInTabBar",
    .order = 84,
    .title = @"Hide Pinned Tabs",
    .detail = @"Take pinned tabs out of the tab bar. If that leaves the box beside the window buttons empty, it goes too and the tabs move up beside the window buttons. They stay pinned, and show with tabs in the sidebar.",
    .symbol = @"pin.slash pin",
    .tint = @"systemYellowColor",
    .section = @"Horizontal Tabs",
    .classes = DPClasses(DPDiaTabStrip, DPDiaTabStripDock, DPDiaTabStripSwitcher, DPDiaTabStripContainer),
    .install = DPInstallTabBarDock,
    .apply = DPUpdateTabBars,
    .verify = DPVerifyTabBars,
};
