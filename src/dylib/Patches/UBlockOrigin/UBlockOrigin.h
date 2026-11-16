#import "StdPatch/StdPatch.h"

extern DPPatch DPUBlockOrigin;

// Dia's Chromium turns away Manifest V2 extensions such as uBlock Origin. This reopens that check in memory.
// Returns nil once the five checks are open, or why they couldn't be found on this Dia.
NSString *DPOpenMV2Gates(void);

NSString *DPUBlockFolder(void);
NSString *DPUBlockStaging(void);
BOOL DPUBlockDownloaded(void);  // The release this DiaTweaks pins is in place.
BOOL DPUBlockInstalled(void);   // Some release is in place.
void DPPromoteStagedUBlock(void);
void DPFetchUBlock(NSString *destination, void (^done)(NSString *problem));
void DPDownloadUBlock(void (^done)(NSString *problem));  // Into place, `done` on the main thread.
void DPWatchUBlockStart(void);
BOOL DPUBlockRunning(void);  // Handed to Chromium at this launch.
void DPAskToRelaunch(BOOL on);
