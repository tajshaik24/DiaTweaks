#import "Patches/TabBarDock/Layout.h"

DP_PATCH(DPHideProfileName) {
    .key = @"hideProfileName",
    .order = 84,
    .title = @"Hide Profile Name in Tab Bar",
    .detail = @"Show only the dots for your profiles in the box beside the window buttons, without the profile's name, and move the tabs up to it.",
    .symbol = @"person.crop.circle.badge.minus person.crop.circle",
    .tint = @"systemYellowColor",
    .section = @"Horizontal Tabs",
    .classes = DPClasses(DPDiaTabStrip, DPDiaTabStripDock, DPDiaTabStripSwitcher, DPDiaTabStripContainer),
    .install = DPInstallTabBarDock,
    .apply = DPUpdateTabBars,
    .verify = DPVerifyTabBars,
};
