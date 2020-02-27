#ifndef CROSS_OPENBSD_KVM_H
#define CROSS_OPENBSD_KVM_H

#include <nlist.h>
#include <stdio.h>

typedef struct kvm_s kvm_t;

static kvm_t *     kvm_openfiles(const char * execfile, const char * corefile, char* swapfile, int flags, char * errstr) {
    (void)execfile; (void)corefile; (void)swapfile; (void)flags; (void)errstr;
    return NULL;
}

static int         kvm_close(kvm_t * kvm) {
    (void)kvm;
    return -1;
}
static int         kvm_nlist(kvm_t * kvm, struct nlist * nl) {
    (void)kvm; (void) nl;
    return -1;
}
static ssize_t     kvm_read(kvm_t * kvm, unsigned long addr, void * buf, size_t nbytes) {
    (void) kvm; (void) addr; (void) buf; (void) nbytes;
    return -1;
}

#endif /* !CROSS_OPENBSD_KVM_H */
