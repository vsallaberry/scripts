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
#ifndef CROSS_COMMON_CROSSMAKE_BSD_SYSCTL_H
#define CROSS_COMMON_CROSSMAKE_BSD_SYSCTL_H

#include <sys/types.h>
#include <sys/sysctl.h>

static const int (*real_sysctlnametomib)(const char *, int *, size_t *)
                            = sysctlnametomib;

static const int (*real_sysctl)(int *, u_int, void *, size_t *, void *, size_t)
                            = sysctl;

#define sysctlnametomib     crossmake_sysctlnametomib
#define sysctl              crossmake_sysctl

#define CROSSMAKE_CPTIME    INT_MIN
#define CROSSMAKE_CPTIMES   INT_MAX
#define CROSSMAKE_CPTIME2   (INT_MAX - 1)

#include <time.h>
void srand(unsigned);
time_t time(time_t *);
int strcmp(const char *, const char *);

/* Known SYSTEM MACROS
 * __NetBSD__
 * __FreeBSD_version
 * OpenBSD
 */

static inline int crossmake_sysctlnametomib(const char * name, int *mib, size_t * size) {
    if (!strcmp(name, "kern.cp_time")) {
        mib[0] = CTL_KERN;
        mib[1] = CROSSMAKE_CPTIME;
        *size = 2;
        return 0;
    }
#ifndef __NetBSD__
    if (!strcmp(name, "kern.cp_times")) {
        mib[0] = CTL_KERN;
        mib[1] = CROSSMAKE_CPTIMES;
        *size = 2;
        return 0;
    }
#endif
#ifdef OpenBSD
    if (!strcmp(name, "kern.cp_time2")) {
        mib[0] = CTL_KERN;
        mib[1] = CROSSMAKE_CPTIME2;
        mib[2] = 0;
        *size = 3;
        return 0;
    }
#endif
    return real_sysctlnametomib(name, mib, size);
}

static int crossmake_cpu_nb() {
    int mib[] = { CTL_HW, HW_NCPU };

    unsigned int    n_cpus;
    size_t          size = sizeof(n_cpus);

    if (real_sysctl(mib, sizeof(mib) / sizeof(*mib), &n_cpus, &size, NULL, 0) < 0) {
	    return 1;
    }
    return n_cpus;
}

static inline int crossmake_sysctl(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (namelen >= 2 && name != NULL && *name == CTL_KERN
    &&  (namelen == 2 && (name[1] == CROSSMAKE_CPTIME || name[1] == CROSSMAKE_CPTIMES)
         || (namelen == 3 && name[1] == CROSSMAKE_CPTIME2))) {

        static unsigned int     n_cpu       = 0;
        static long             value[16]   = { 0, };
        long *                  cp          = (long *) oldp;

        if (value[0] == 0) {
            srand(time(NULL));
            n_cpu = crossmake_cpu_nb();
        }

        for (int i_cpu = 0; i_cpu < n_cpu && i_cpu < sizeof(value) / sizeof(*value); ++i_cpu) {
            for (int i = 0; i < CPUSTATES; ++i) {
                cp[i + (i_cpu * CPUSTATES)] = value[name[1] == CROSSMAKE_CPTIME2 ? name[2] : i_cpu];
            }
            if (name[1] == CROSSMAKE_CPTIME || name[1] == CROSSMAKE_CPTIME2) {
                break;
            }
        }
        for (int i = 0; i < sizeof(value) / sizeof(*value); ++i) {
            value[i] += (rand() % 9);
        }
        return 0;
    }
    return real_sysctl(name, namelen, oldp, oldlenp, newp, newlen);
}

#endif
