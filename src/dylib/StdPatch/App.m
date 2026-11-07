#import "StdPatch/StdPatch.h"

void DPOnLaunch(void (^block)(void)) {
    [NSNotificationCenter.defaultCenter addObserverForName:NSApplicationDidFinishLaunchingNotification object:nil queue:nil
                                                usingBlock:^(NSNotification *_) { block(); }];
}

static NSMutableArray<void (^)(void)> *DPQuitBlocks;

static void DPRunQuitBlocks(void) {
    static BOOL ran;
    if (ran) return;
    ran = YES;
    for (void (^block)(void) in DPQuitBlocks) block();
}

// Dia quits through its own shutdown, which never posts NSApplicationWillTerminateNotification, so a quit is caught as
// the process exits. A crash or SIGTERM doesn't get there.
void DPOnQuit(void (^block)(void)) {
    if (!DPQuitBlocks) {
        DPQuitBlocks = [NSMutableArray new];
        atexit(DPRunQuitBlocks);
        [NSNotificationCenter.defaultCenter addObserverForName:NSApplicationWillTerminateNotification object:nil queue:nil
                                                    usingBlock:^(NSNotification *_) { DPRunQuitBlocks(); }];
    }
    [DPQuitBlocks addObject:block];
}

// Menu items hold their target weakly; representedObject keeps it alive.
@interface DPMenuAction : NSObject
@property (nonatomic, copy) void (^action)(void);
@end

@implementation DPMenuAction
- (void)run:(id)sender { self.action(); }
@end

static NSMenu *DPMenuTitled(NSString *title) {
    NSMenu *bar = NSApp.mainMenu;
    return (title ? [bar itemWithTitle:title] : bar.itemArray.firstObject).submenu;
}

static void DPSetAction(NSMenuItem *item, void (^action)(void)) {
    DPMenuAction *target = [DPMenuAction new];
    target.action = action;
    item.representedObject = target;
    item.target = target;
    item.action = @selector(run:);
}

NSMenuItem *DPMenuItem(NSString *title, void (^action)(void)) {
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:nil keyEquivalent:@""];
    DPSetAction(item, action);
    return item;
}

NSMenuItem *DPAddMenuItem(NSString *menu, NSString *title, void (^action)(void)) {
    NSMenuItem *item = DPMenuItem(title, action);
    [DPMenuTitled(menu) addItem:item];
    return item;
}

void DPOnMenuItem(NSString *menu, NSString *titlePrefix, void (^action)(void)) {
    for (NSMenuItem *item in DPMenuTitled(menu).itemArray)
        if ([item.title hasPrefix:titlePrefix]) DPSetAction(item, action);
}
