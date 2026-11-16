#import "Patches/UBlockOrigin/UBlockOrigin.h"
#import <CommonCrypto/CommonDigest.h>

// The uBlock Origin release this installs, checked against its digest before it's used.
static NSString *const kVersion = @"1.76.0";
static NSString *const kSHA256 = @"e76a1912426caa7b8679ad11dd140d1529c23db22ddbe892b6f901e9b7763456";
// Gives the unpacked extension a fixed ID (fhlpapgmjejklmhcgeafaeilmmhdcack), so its settings survive a reinstall.
static NSString *const kKey =
    @"MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA2/FjCXA/1Iggq3f5NWAsmu05dDM7JToqKPeoxDIMQcUFvIXPi4Ni0atQOVoybNtwVOvZ06qEW/TeDFr1qCkbmrBHXXmPJM7X5bEZnwaQfv3KWi+"
    @"sFlmd7+TiCR1MBmlR5/9YOlJY3XCHFgWu1V1hwcZZ4+CW+VGCKel2QAe04W8sJRCe5vDxLy11sPuBAxKFPZ0jkPYZGLwXlm+w/w9CUIwO7GbLsIqiraSEFCwjjtT5cKiGNG3tQY433GKLuRLJ+sF93JcgKX8hkw"
    @"s9zGLqRiIEceQQEwTyabwSyEE/a56GpmyEcyvwyU/NXXUFrtvzXD7xF1KC3N+5ZRDvps4kAwIDAQAB";

NSString *DPUBlockFolder(void) { return DPAppSupport(@"DiaPatches/ublock-origin"); }

static NSString *DPVersionFile(void) { return [DPUBlockFolder() stringByAppendingPathComponent:@".diatweaks-version"]; }

BOOL DPUBlockDownloaded(void) {
    return [[NSString stringWithContentsOfFile:DPVersionFile() encoding:NSUTF8StringEncoding error:nil] isEqualToString:kVersion];
}

static NSString *DPHex(NSData *data) {
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
    NSMutableString *hex = [NSMutableString string];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) [hex appendFormat:@"%02x", digest[i]];
    return hex;
}

static NSString *DPUnpack(NSData *zip) {
    NSFileManager *files = NSFileManager.defaultManager;
    NSString *work = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    NSString *archive = [work stringByAppendingPathComponent:@"ublock.zip"], *unzipped = [work stringByAppendingPathComponent:@"x"];
    [files createDirectoryAtPath:unzipped withIntermediateDirectories:YES attributes:nil error:nil];
    if (![zip writeToFile:archive atomically:NO]) return @"The download couldn't be saved.";
    NSTask *ditto = [NSTask launchedTaskWithExecutableURL:[NSURL fileURLWithPath:@"/usr/bin/ditto"] arguments:@[ @"-x", @"-k", archive, unzipped ] error:nil terminationHandler:nil];
    [ditto waitUntilExit];
    NSString *extension = [unzipped stringByAppendingPathComponent:@"uBlock0.chromium"];
    NSString *manifestPath = [extension stringByAppendingPathComponent:@"manifest.json"];
    NSMutableDictionary *manifest = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:manifestPath] ?: NSData.data options:NSJSONReadingMutableContainers error:nil];
    if (ditto.terminationStatus || ![manifest isKindOfClass:NSDictionary.class]) return @"The download couldn't be unpacked.";
    manifest[@"key"] = kKey;
    if (![[NSJSONSerialization dataWithJSONObject:manifest options:NSJSONWritingPrettyPrinted error:nil] writeToFile:manifestPath atomically:YES]
        || ![kVersion writeToFile:[extension stringByAppendingPathComponent:@".diatweaks-version"] atomically:YES encoding:NSUTF8StringEncoding error:nil])
        return @"uBlock Origin couldn't be set up.";
    [files createDirectoryAtPath:DPUBlockFolder().stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
    [files removeItemAtPath:DPUBlockFolder() error:nil];
    BOOL moved = [files moveItemAtPath:extension toPath:DPUBlockFolder() error:nil];
    [files removeItemAtPath:work error:nil];
    return moved ? nil : @"uBlock Origin couldn't be moved into place.";
}

void DPDownloadUBlock(void (^done)(NSString *problem)) {
    NSString *address = [NSString stringWithFormat:@"https://github.com/gorhill/uBlock/releases/download/%@/uBlock0_%@.chromium.zip", kVersion, kVersion];
    [[NSURLSession.sharedSession dataTaskWithURL:[NSURL URLWithString:address] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSString *problem = nil;
        if (!data || error || ((NSHTTPURLResponse *)response).statusCode != 200) problem = @"uBlock Origin couldn't be downloaded.";
        else if (![DPHex(data) isEqualToString:kSHA256]) problem = @"The uBlock Origin download didn't match the expected release.";
        else problem = DPUnpack(data);
        dispatch_async(dispatch_get_main_queue(), ^{ done(problem); });
    }] resume];
}
