#import "StdPatch/StdPatch.h"

// With tabs at the top, the box beside the window buttons holds the profile switcher and that profile's pinned tabs.
extern DPPatch DPHideEmptyTabBarDock, DPHideProfileName, DPHidePinnedTabsInTabBar;

void DPUpdateTabBar(NSView *root);
void DPUpdateTabBars(DPPatch *patch);
NSString *DPVerifyTabBars(DPPatch *patch);
void DPInstallTabBarDock(void);
