#import "StdPatch/StdPatch.h"

void DPRunTests(NSString *reportPath);
NSMutableArray<NSArray<NSString *> *> *DPScenarios(void);
NSString *DPBits(const int8_t *state);

NSString *DPPhaseName(void);
BOOL DPAutoHideRun(void);
void DPSwitchLayout(void (^done)(BOOL moved));
NSArray<NSArray<NSString *> *> *DPAutoHideScenarios(NSArray<NSArray<NSString *> *> *all);
extern NSMutableArray<NSString *> *DPSwitchLog;
NSString *DPCheckAutoHide(void);
void DPPrepareWindow(void (^done)(void));
