#import "StdPatch/Hook.m"
#import "StdPatch/MenuGuard.m"

static int failures;

static void expect(BOOL ok, NSString *what) {
    if (ok) return;
    failures++;
    printf("FAIL %s\n", what.UTF8String);
}

// A pass-through hook like Turn Off AI's and Group Tabs', installed after the guard, as in Dia.
static void DPTweak_insertItem(NSMenu *self, SEL _cmd, NSMenuItem *item, NSInteger index) {
    DPCallOriginal(DPTweak_insertItem, self, item, index);
}

static NSArray<NSString *> *DPTitles(NSMenu *menu) { return [menu.itemArray valueForKey:@"title"]; }

static BOOL DPAdds(void (^add)(void)) {
    @try {
        add();
        return YES;
    } @catch (NSException *e) {
        printf("     threw %s: %s\n", e.name.UTF8String, e.reason.UTF8String);
        return NO;
    }
}

int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        NSMenu *a = [[NSMenu alloc] initWithTitle:@"A"], *b = [[NSMenu alloc] initWithTitle:@"B"];
        NSMenuItem *moved = [[NSMenuItem alloc] initWithTitle:@"Moved" action:nil keyEquivalent:@""];
        [a addItemWithTitle:@"One" action:nil keyEquivalent:@""];
        [a addItem:moved];
        [a addItemWithTitle:@"Two" action:nil keyEquivalent:@""];

        expect(!DPAdds(^{ [b addItem:moved]; }), @"AppKit itself rejects an item that's still in another menu (otherwise this test proves nothing)");

        DPInstallMenuGuard();
        DPHookClass(NSMenu.class, @selector(insertItem:atIndex:), (IMP)DPTweak_insertItem);

        expect(DPAdds(^{ [b addItem:moved]; }), @"addItem: of an item still in another menu doesn't throw");
        expect(moved.menu == b, @"the item ends up in the menu it was added to");
        expect([DPTitles(a) isEqual:(@[ @"One", @"Two" ])], @"the item leaves its old menu");
        expect([DPTitles(b) isEqual:(@[ @"Moved" ])], @"the new menu holds just the item");

        NSMenuItem *back = [b itemAtIndex:0];
        expect(DPAdds(^{ [a insertItem:back atIndex:1]; }), @"insertItem:atIndex: of an item still in another menu doesn't throw");
        expect([DPTitles(a) isEqual:(@[ @"One", @"Moved", @"Two" ])], @"insertItem: puts it at the asked index");
        expect(b.numberOfItems == 0, @"and takes it out of the other menu");

        expect(DPAdds(^{ [a insertItem:back atIndex:3]; }), @"re-inserting an item into its own menu doesn't throw");
        expect([DPTitles(a) isEqual:(@[ @"One", @"Two", @"Moved" ])], @"re-inserting later in the same menu counts the removed slot");
        expect(DPAdds(^{ [a insertItem:back atIndex:0]; }), @"re-inserting earlier in the same menu doesn't throw");
        expect([DPTitles(a) isEqual:(@[ @"Moved", @"One", @"Two" ])], @"re-inserting earlier lands at the asked index");

        NSMenuItem *fresh = [[NSMenuItem alloc] initWithTitle:@"Fresh" action:nil keyEquivalent:@""];
        [b addItem:fresh];
        expect([DPTitles(b) isEqual:(@[ @"Fresh" ])], @"a fresh item still adds normally");
    }
    printf(failures ? "menu-guard: %d failures\n" : "menu-guard: ok\n", failures);
    return failures ? 1 : 0;
}
