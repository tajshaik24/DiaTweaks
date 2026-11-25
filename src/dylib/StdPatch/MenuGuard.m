#import "StdPatch.h"
#import <os/log.h>

static NSString *DPMenuName(NSMenu *menu) {
    return menu ? [NSString stringWithFormat:@"%@ (%ld items)", menu.title.length ? menu.title : @"untitled", (long)menu.numberOfItems] : @"none";
}

// AppKit aborts Dia when an item that's still in a menu is inserted anywhere. Dia moves some items between menus by
// position, and the items tweaks add shift those positions, so Dia can detach the wrong item and then trip this at
// launch. Detach the item first instead, and log it so the menu that did it can be found.
static void DPGuard_insertItem(NSMenu *self, SEL _cmd, NSMenuItem *item, NSInteger index) {
    NSMenu *owner = item.menu;
    if (owner) {
        NSInteger at = [owner indexOfItem:item];
        os_log_error(OS_LOG_DEFAULT, "DiaPatches: moving menu item \"%{public}@\" (tag %ld) from %{public}@ to %{public}@ at %ld; it was never removed from its old menu",
                     item.title, (long)item.tag, DPMenuName(owner), DPMenuName(self), (long)index);
        if (at >= 0) {
            [owner removeItemAtIndex:at];
            if (owner == self && at < index) index--;
        }
        index = MAX(0, MIN(index, self.numberOfItems));
    }
    DPCallOriginal(DPGuard_insertItem, self, item, index);
}

void DPInstallMenuGuard(void) {
    // addItem: goes through insertItem:atIndex:, so this covers both.
    DPHookClass(NSMenu.class, @selector(insertItem:atIndex:), (IMP)DPGuard_insertItem);
}
