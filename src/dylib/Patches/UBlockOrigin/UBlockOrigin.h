#import "StdPatch/StdPatch.h"

extern DPPatch DPUBlockOrigin;

// Dia's Chromium turns away Manifest V2 extensions such as uBlock Origin. This reopens that check in memory.
// Returns nil once the five checks are open, or why they couldn't be found on this Dia.
NSString *DPOpenMV2Gates(void);

NSString *DPUBlockFolder(void);
BOOL DPUBlockDownloaded(void);
void DPDownloadUBlock(void (^done)(NSString *problem));
