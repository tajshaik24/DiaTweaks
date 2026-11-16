#import "Patches/TabBarDock/Layout.h"

DP_PATCH(DPHideProfileName) {
    .key = @"hideProfileName",
    .order = 84,
    .title = @"Hide Profile Name",
    .detail = @"Show only the profile dots in the box beside the window buttons, without the name. If that leaves the box with no pinned tabs, it goes too and the tabs move up beside the window buttons.",
    .symbol = @"person.crop.circle.badge.minus person.crop.circle",
    .tint = @"systemYellowColor",
    .section = @"Horizontal Tabs",
    .classes = DPClasses(DPDiaTabStrip, DPDiaTabStripDock, DPDiaTabStripSwitcher, DPDiaTabStripContainer),
    .install = DPInstallTabBarDock,
    .apply = DPUpdateTabBars,
    .verify = DPVerifyTabBars,
};
