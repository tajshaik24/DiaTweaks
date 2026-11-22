#import "Test/Test.h"
#import "SafeMode/SafeMode.h"

static const NSTimeInterval DPSettleSeconds = 1, DPSettleLimit = 5, DPPollSeconds = 0.1;

static void DPWhenSettled(NSTimeInterval waited, void (^then)(void)) {
    NSTimeInterval wait = waited ? DPPollSeconds : DPSettleSeconds;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(wait * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (DPAnimating() && waited + wait < DPSettleLimit) return DPWhenSettled(waited + wait, then);
        then();
    });
}

static void DPWriteReport(NSArray<NSDictionary *> *results, NSArray<NSString *> *phases, NSString *path) {
    DPTesting = NO;
    NSMutableArray<NSString *> *unavailable = [NSMutableArray new];
    for (NSUInteger i = 0; i < DPPatchCount; i++) if (DPPatches[i]->unavailable) [unavailable addObject:DPPatches[i]->key];
    NSDictionary *info = NSBundle.mainBundle.infoDictionary;
    NSDictionary *report = @{
        @"dia": [NSString stringWithFormat:@"%@ (%@)", info[@"CFBundleShortVersionString"], info[@"CFBundleVersion"]],
        @"layout": DPTabLayout(),
        @"phases": phases,
        @"switches": DPSwitchLog ?: @[],
        @"safeMode": @(DPSafeMode),
        @"unavailable": unavailable,
        @"scenarios": results,
    };
    [[NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:nil]
        writeToFile:path atomically:YES];
}

static void DPRunScenario(NSArray<NSArray<NSString *> *> *scenarios, NSUInteger index, NSString *phase, NSMutableArray<NSDictionary *> *results,
                          void (^done)(void)) {
    if (index == scenarios.count) return done();
    NSString *bits = scenarios[index][1];
    for (NSUInteger i = 0; i < DPPatchCount; i++) DPSetPatch(DPPatches[i], [bits characterAtIndex:i] == '1', NO);
    NSMutableDictionary<NSString *, NSString *> *(^check)(void) = ^NSMutableDictionary<NSString *, NSString *> *(void) {
        NSMutableDictionary<NSString *, NSString *> *failures = [NSMutableDictionary new];
        for (NSUInteger i = 0; i < DPPatchCount; i++) {
            DPPatch *patch = DPPatches[i];
            NSString *problem = patch->verify && !patch->unavailable ? patch->verify(patch) : nil;
            if (!problem && patch->on && patch->ready) problem = patch->ready(patch);
            if (!problem && !patch->on && !patch->unavailable && [bits characterAtIndex:i] == '1') problem = @"couldn't turn on";
            if (problem) failures[patch->key] = problem;
        }
        return failures;
    };
    // A check that fails is tried again a moment later, so an animation still running (such as auto-hidden tabs
    // sliding in under the pointer) isn't reported. One that still fails then is real.
    void (^record)(NSDictionary<NSString *, NSString *> *) = ^(NSDictionary<NSString *, NSString *> *failures) {
        NSMutableDictionary<NSString *, id> *states = [NSMutableDictionary new];
        for (NSUInteger i = 0; i < DPPatchCount; i++) states[DPPatches[i]->key] = @(DPPatches[i]->on);
        NSString *name = [NSString stringWithFormat:@"[%@] %@", phase, scenarios[index][0]];
        [results addObject:@{@"name": name, @"phase": phase, @"states": states, @"failures": failures}];
        DPRunScenario(scenarios, index + 1, phase, results, done);
    };
    DPWhenSettled(0, ^{
        NSDictionary<NSString *, NSString *> *first = check();
        if (!first.count) return record(first);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSMutableDictionary<NSString *, NSString *> *again = check();
            for (NSString *key in again.allKeys) if (!first[key]) [again removeObjectForKey:key];
            record(again);
        });
    });
}

// The scenarios as Dia is, then with the tabs in the other layout, then the tabs go back where they were.
// In the run test.sh starts with Auto-Hide Tabs on, each patch on its own is enough.
static void DPRunPhases(NSArray<NSArray<NSString *> *> *scenarios, NSString *path) {
    NSMutableArray<NSDictionary *> *results = [NSMutableArray new];
    NSMutableArray<NSString *> *phases = [NSMutableArray new];
    if (getenv("DIAPATCH_TEST_SWITCH_ONLY")) scenarios = @[];  // Just the switching, for working on it.
    if (DPAutoHideRun()) scenarios = DPAutoHideScenarios(scenarios);
    void (^fail)(void) = ^{
        [results addObject:@{@"name": @"switching layout", @"phase": @"", @"states": @{}, @"failures": @{
            @"test": [@"Dia didn't move the tabs when the test set them through its AppleScript: " stringByAppendingString:[DPSwitchLog componentsJoinedByString:@"; "] ?: @""]}}];
        DPWriteReport(results, phases, path);
    };
    if (!DPSwitchLog) DPSwitchLog = [NSMutableArray array];
    NSString *first = DPPhaseName();
    [phases addObject:first];
    NSString *firstProblem = DPCheckAutoHide();
    if (firstProblem) [results addObject:@{@"name": [NSString stringWithFormat:@"[%@] tabs", first], @"phase": first, @"states": @{}, @"failures": @{@"test": firstProblem}}];
    DPRunScenario(scenarios, 0, first, results, ^{
        DPSwitchLayout(^(BOOL moved) {
            if (!moved) return fail();
            NSString *second = DPPhaseName();
            [phases addObject:second];
            NSString *secondProblem = DPCheckAutoHide();
            if (secondProblem) [results addObject:@{@"name": [NSString stringWithFormat:@"[%@] tabs", second], @"phase": second, @"states": @{}, @"failures": @{@"test": secondProblem}}];
            DPRunScenario(scenarios, 0, second, results, ^{
                DPSwitchLayout(^(BOOL back) {
                    if (!back) return fail();
                    DPWriteReport(results, phases, path);
                });
            });
        });
    });
}

void DPRunTests(NSString *path) {
    DPTesting = YES;
    DPOnLaunch(^{
        __block int polls = 0;
        [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:YES block:^(NSTimer *timer) {
            if (!DPFindViews(DPDiaContentPane).count && ++polls < 120) return;
            [timer invalidate];
            if (DPSafeMode) return DPWriteReport(@[], @[], path);
            NSMutableArray<NSArray<NSString *> *> *scenarios = DPScenarios();
            int8_t saved[DPPatchCount ?: 1];
            for (NSUInteger i = 0; i < DPPatchCount; i++) saved[i] = DPSavedOn(DPPatches[i]);
            [scenarios insertObject:@[@"at launch", DPBits(saved)] atIndex:0];
            [scenarios addObject:@[@"saved settings", DPBits(saved)]];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                DPRunPhases(scenarios, path);
            });
        }];
    });
}
