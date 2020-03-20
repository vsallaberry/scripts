#!/bin/bash
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
# ONLY TESTED (and most probably working) on macosx.
# --
my0="$0"; test -L "${my0}" && my0="`readlink "${my0}"`"
mypath="`dirname "${my0}"`"; pushd "${mypath}" > /dev/null && { mypath="`pwd`"; popd > /dev/null; }

test -e /usr/local/etc/sh/vutil.sh && . /usr/local/etc/sh/vutil.sh \
    || . "${mypath}/../vutil/vutil.sh"

VERSION=0.1.0
dotests=
make=make
sys=
run=

unset args
declare -a args

show_help() {
    vlog 1 "Usage: `basename "$0"` [-hVIT] [-l <level>] [-s system] [-- [<make_arguments>]]"
    vlog 1 "  -h, --help              show help"
    vlog 1 "  -V, --version           show version"
    vlog 1 "  -l, --level <level>     set log level"
    vlog 1 "  -T, --test              perform unitary tests"
    vlog 1 "  -s, --system sys        build for <sys>: linux|freebsd|netbsd|openbsd,"
    vlog 1 "                          use BUILD_SYSNAME in build.h by default"
    vlog 1 "  -r, --run command&args  run command with 'system emulation'"
    exit $1
}
while vgetopt opt arg "$@"; do
    case "$opt" in
        -h|--help)      show_help 0;;
        -V|--version)   vlog 1 "`basename "${my0}"` ${VERSION}"; exit 0;;
        -l|--level)     test ${#arg[@]} -gt 0 || { vlog 1 "${VCOLOR_ko}error${VCOLOR_rst}: missing argument for option '${VCOLOR_opt}${opt}${VCOLOR_rst}'"; exit 3; }
                        vgetopt_shift;; # only parsing, 'vlog_setlevel "${arg[1]}" || exit 4' already done previously
        -T|--test)      dotests=yes;;
        -s|--system)    test ${#arg[@]} -gt 0 || { vlog 1 "${VCOLOR_ko}error${VCOLOR_rst}: missing argument for option '${VCOLOR_opt}${opt}${VCOLOR_rst}'"; exit 3; }
                        sys=${arg[1]}; vgetopt_shift;;
        -r|--run)       test ${#arg[@]} -gt 0 || { vlog 1 "${VCOLOR_ko}error${VCOLOR_rst}: missing argument for option '${VCOLOR_opt}${opt}${VCOLOR_rst}'"; exit 3; }
                        run="${arg[1]}";;
        -*)             vlog 1 "${VCOLOR_ko}error${VCOLOR_rst}: unknown option '${VCOLOR_opt}${opt}${VCOLOR_rst}'"; show_help 1;;
        '') case "${arg}" in
                *) vtab_add args "${arg}";;
            esac;;
    esac
done

if ! test -e "Makefile"; then
    vlog 1 "${VCOLOR_ko}error${VCOLOR_rst}: no Makefile found in current folder"; exit 3;
fi

if test -z "${sys}"; then
    sys=`sed -n -e 's/^[[:space:]]*#[[:space:]]*define[[:space:]][[:space:]]*BUILD_SYSNAME[[:space:]][[:space:]]*"\([^"]*\).*/\1/p' build.h`
    test -z "${sys}" && { vlog 1 "${VCOLOR_ko}error${VCOLOR_rst}: no target system defined"; exit 3; }
fi

sys_run() {
    return 0
}
case "${sys}" in
    linux)
        vtab_add args \
            "sys_INCS+=-D_cm_STR\\(x\\)=#x" \
            "sys_INCS+=-DCPU_PROC_FILE=_cm_STR\\(${mypath}/linux/root/proc/stat\\)"
        sys_run() {
            local i=0
            if ! test -e "${mypath}/linux/root/proc/stat"; then
                mkdir -p "${mypath}/linux/root/proc"
                cp -a "${mypath}/linux/root0/proc/stat" "${mypath}/linux/root/proc/stat"
            fi
            while true; do
                cat "${mypath}/linux/root$((i % 5))/proc/stat" > "${mypath}/linux/root/proc/stat"
                i=$((i+1))
                sleep 1
            done
        } ;;
    freebsd)
        vtab_add args "sys_INCS+=-D__FreeBSD_version";;
    netbsd)
        vtab_add args "sys_INCS+=-D__NetBSD__";;
    openbsd)
        vtab_add args "sys_INCS+=-DOpenBSD";;
esac

if test -n "${run}"; then
    syspid=
    exit_fun() {
        test -n "${syspid}" && { kill "${syspid}"; syspid=; }
    }
    trap exit_fun EXIT
    sys_run & syspid=$!
    ${run}
    exit_fun
    trap - EXIT
    wait
else
    # DIRTY BUT NEEDED to make sysdeps sources depends on crossmake headers
    for f in `find . -path "*/sysdeps/*-${sys}.*" -and \( -iname '*.c' -or -iname '*.cc' -or -iname '*.cpp' \)`; do
        file=${f}
        base=${file%/sysdeps/*-${sys}.*}
        while ! test -e "${base}/Makefile"; do
            base="${base}/.."
        done
        pushd "$base" > /dev/null && { base=`pwd`; popd > /dev/null; }
        pushd "`dirname "${file}"`" > /dev/null && { file="`pwd`/`basename "${file}"`"; popd > /dev/null; }
        file="${file#${base}/}"
        obj="${file%.*}.o"
        if ! grep -Eq "${obj}[[:space:]]*:[[:space:]]*${mypath}/${sys}/include" "${base}/.alldeps.d" 2> /dev/null; then
            echo "SYSDEP <$file> root $base"
            for dep in `find "${mypath}/${sys}/include" "${mypath}/common/include" -iname '*.h' -or -iname '*.hh' -or -iname '*.hpp'`; do
                echo "$obj NEED $dep"
                echo "${obj}: ${dep}" >> "${base}/.alldeps.d"
            done
        fi
    done
    # RUN MAKE
    "${make}" UNAME_SYS="${sys}" "LIBS_${sys#darwin}=" \
        sys_INCS="-isystem${mypath}/${sys}/include -isystem${mypath}/common/include" \
        "${args[@]}"
fi

