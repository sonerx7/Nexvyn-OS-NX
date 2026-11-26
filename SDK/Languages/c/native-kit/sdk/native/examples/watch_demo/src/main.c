#include <nexvyn/nxn_vm.h>
#include <stdio.h>

#define PAGE NXN_VM_PROTECT_GRANULE

static void direct_store(uint8_t* target) {
    // Fix the faulting instruction's registers, including across LTO and compiler versions.
    register uint8_t* address __asm__("x9") = target;
    register unsigned value __asm__("w10") = 0x42;
    __asm__ volatile("strb %w[value], [%[address]]"
                     : : [address] "r"(address), [value] "r"(value) : "memory");
}

int main(void) {
    nxn_vm_region* vm = NULL;
    nxn_vm_info info = NXN_STRUCT_INIT(nxn_vm_info);
    const char* status = "FAIL";
    uint64_t dirty[2];
    size_t count = 0;
    const uint8_t payload = 0x7b;
    int permissions_enforced = 0;

    puts("WATCH note=resume clobbers x17; JIT stores that may fault must avoid x17");
    fflush(stdout);
    nxn_result rc = nxn_vm_reserve(NXN_VM_COMMIT_GRANULE, NXN_VM_NEED_PROTECT, &vm);
    if (rc == NXN_OK) rc = nxn_vm_get(vm, &info);
    if (rc == NXN_OK) rc = nxn_vm_commit(vm, 0, info.commit_granule);
    if (rc == NXN_OK) rc = nxn_vm_watch(vm, 0, 2 * PAGE);
    printf("WATCH arm_rc=%d\n", rc);
    fflush(stdout);
    if (rc == NXN_ERR_UNSUPPORTED) status = "UNSUPPORTED";
    if (rc != NXN_OK) goto done;

    uint8_t* base = info.base;
    direct_store(base);
    rc = nxn_vm_watch_collect(vm, dirty, 2, &count);
    if (rc != NXN_OK || base[0] != 0x42 || count > 1 || (count && dirty[0] != 0)) goto done;
    permissions_enforced = count == 1;
    printf("WATCH direct_dirty=%zu\n", count);
    if (!permissions_enforced) puts("WATCH note=protection not enforced");

    rc = nxn_vm_write(vm, PAGE + 3, &payload, sizeof payload);
    if (rc != NXN_OK || base[PAGE + 3] != payload) goto done;
    rc = nxn_vm_watch_collect(vm, dirty, 2, &count);
    if (rc != NXN_OK || count != 1 || dirty[0] != PAGE) goto done;
    printf("WATCH copy_dirty_offset=%llu\n", (unsigned long long)dirty[0]);
    rc = nxn_vm_watch_collect(vm, dirty, 2, &count);
    if (rc != NXN_OK || count != 0) goto done;
    status = permissions_enforced ? "PASS" : "LIMITED";

done:
    nxn_vm_release(vm);
    printf("WATCH END status=%s\n", status);
    fflush(stdout);
    return status[0] == 'F';
}
