#import "Patches/TabBarDock/Layout.h"

DP_PATCH(DPHideEmptyTabBarDock) {
    .key = @"hideEmptyTabBarDock",
    .order = 84,
    .title = @"Hide Profile Box Without Pinned Tabs",
    .detail = @"Hide the box with the profile name beside the window buttons when the profile has no pinned tabs, and move the tabs into its place.",
    .symbol = @"rectangle.dashed rectangle",
    .tint = @"systemYellowColor",
    .section = @"Horizontal Tabs",
    .classes = DPClasses(DPDiaTabStrip, DPDiaTabStripDock, DPDiaTabStripSwitcher, DPDiaTabStripContainer),
    .install = DPInstallTabBarDock,
    .apply = DPUpdateTabBars,
    .verify = DPVerifyTabBars,
};
