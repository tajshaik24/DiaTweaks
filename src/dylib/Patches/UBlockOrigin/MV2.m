#import "Patches/UBlockOrigin/UBlockOrigin.h"
#import <libkern/OSCacheControl.h>
#import <mach-o/dyld.h>
#import <mach-o/getsect.h>
#import <mach/mach.h>

// Chromium decides an extension is "affected by the MV2 deprecation" in five inlined copies of
// manifest_v2_util::IsExtensionAffected, each shaped like:
//     ldr  wA, [xB, #0x50]      ; extension->manifest_version()
//     cmp  wA, #2
//     b.gt <not affected>
//     ... ldr xC, [xB, #0x228]  ; extension->manifest_ — then the type and location checks,
//     ... location == kComponent (5) || location == kExternalComponent (10)
// Turning each b.gt into b makes every extension count as unaffected, as in Helium's source patch.
// A sixth match (the MV2 default content security policy) has no location check, so it's left alone.
static const NSUInteger DPGateCount = 5;

static BOOL DPChecksLocation(const uint32_t *code) {
    BOOL component = NO, external = NO;
    for (int k = 0; k < 20; k++) {
        uint32_t ins = code[k];
        int imm = -1;
        if ((ins & 0xFFC0001F) == 0x7100001F) imm = (ins >> 10) & 0xFFF;  // cmp wN, #imm
        else if ((ins & 0xFFE00C10) == 0x7A400800) imm = (ins >> 16) & 31;  // ccmp wN, #imm, #nzcv, cond
        component |= imm == 5;
        external |= imm == 10;
    }
    return component && external;
}

static NSMutableArray<NSValue *> *DPFindGates(const uint32_t *text, size_t count) {
    NSMutableArray<NSValue *> *gates = [NSMutableArray array];
    for (size_t i = 0; i + 32 < count; i++) {
        uint32_t load = text[i];
        if ((load & 0xFFFFFC00) != 0xB9405000) continue;  // ldr wA, [xB, #0x50]
        uint32_t a = load & 31, b = (load >> 5) & 31;
        if (text[i + 1] != (0x7100081F | a << 5) || (text[i + 2] & 0xFF00001F) != 0x5400000C) continue;  // cmp wA, #2 ; b.gt
        BOOL manifest = NO;
        for (int k = 3; k < 11; k++) manifest |= (text[i + k] & 0xFFFFFFE0) == (0xF9400000 | 0x45 << 10 | b << 5);  // ldr xC, [xB, #0x228]
        if (manifest && DPChecksLocation(text + i + 3)) [gates addObject:[NSValue valueWithPointer:text + i + 2]];
    }
    return gates;
}

static BOOL DPOpenGate(uint32_t *branch) {
    int32_t offset = (int32_t)(((*branch >> 5) & 0x7FFFF) << 13) >> 13;
    vm_address_t page = (vm_address_t)branch & ~(vm_address_t)(vm_page_size - 1);
    if (vm_protect(mach_task_self(), page, vm_page_size, NO, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY)) return NO;
    *branch = 0x14000000 | ((uint32_t)offset & 0x3FFFFFF);  // b, to the same place
    kern_return_t back = vm_protect(mach_task_self(), page, vm_page_size, NO, VM_PROT_READ | VM_PROT_EXECUTE);
    sys_icache_invalidate(branch, 4);
    return back == KERN_SUCCESS;
}

NSString *DPOpenMV2Gates(void) {
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        if (!strstr(_dyld_get_image_name(i), "/ArcCore.framework/")) continue;
        unsigned long size = 0;
        uint32_t *text = (uint32_t *)getsectiondata((const struct mach_header_64 *)_dyld_get_image_header(i), "__TEXT", "__text", &size);
        if (!text) return @"Dia's code wasn't found.";
        NSArray<NSValue *> *gates = DPFindGates(text, size / 4);
        if (gates.count != DPGateCount)
            return [NSString stringWithFormat:@"This Dia checks extensions differently (%lu checks found, not %lu).", (unsigned long)gates.count, (unsigned long)DPGateCount];
        for (NSValue *gate in gates)
            if (!DPOpenGate(gate.pointerValue)) return @"Dia's code couldn't be changed.";
        return nil;
    }
    return @"Dia's code wasn't found.";
}
