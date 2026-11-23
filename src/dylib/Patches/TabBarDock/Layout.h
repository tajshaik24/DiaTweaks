#import "StdPatch/StdPatch.h"

// With tabs at the top, the box beside the window buttons holds the profile switcher and that profile's pinned tabs.
extern DPPatch DPHideProfileName, DPHidePinnedTabsInTabBar;

void DPUpdateTabBar(NSView *root);
void DPUpdateTabBars(DPPatch *patch);
NSString *DPVerifyTabBars(DPPatch *patch);
void DPInstallTabBarDock(void);

// The box's contents, in Contents.m.
NSView *DPPinnedTabsIn(NSView *dock);
void DPHidePinnedTabs(NSView *dock);
BOOL DPPinnedTabsHiddenByUs(NSView *dock);
BOOL DPPinnedTabsShow(NSView *dock);
BOOL DPProfileNameShows(NSView *dock);
BOOL DPProfileNameHidden(NSView *dock);
// Whether the dock shows a profile name at all: with one space Dia shows no switcher pill.
BOOL DPHasProfileName(NSView *dock);
void DPNarrowSwitcher(NSView *dock);
void DPCenterDots(NSView *switcher);
