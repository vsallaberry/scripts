/*
# --
# Copyright (C) 2020 Vincent Sallaberry
# scripts/sh/crossmake/crossmake.sh <https://github.com/vsallaberry/scripts>
# building with foreign system.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
# --
*/
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
