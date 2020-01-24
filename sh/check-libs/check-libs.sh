#!/bin/bash
# --
# Copyright (C) 2020 Vincent Sallaberry
# scripts/sh/prompt.sh <https://github.com/vsallaberry/scripts>
# ps1_open v5.0.4 SH ~generic prompt.
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
##
### check_libs created by Vincent Sallaberry, for MacOS only.
### has been writeen to check wheter an isolated development prefix (eg:/usr/local/wine)
### was autonomous, and had required architectures.
##
#### BUGS
## ?
##
### TODO
## 1. Remove single Thread code : (comments '# Single_Thread_code')
## 2. FIXME: FIXME_libs_deps
##
###
VERSION=0.8.0
loglevel=2
prefix_def=/usr/local/wine
find_prefix="/{bin,lib,libexec,bin64,lib64,libexec64}"
find_all=
check_univ=yes
check_a_has_dylib=yes
check_dylib_has_a=
wine_excludes=yes
ignoredepon_libs=
ignoredepon_for_wine="|@rpath/libwine.1.dylib"
ignoredepon_libs_def='${prefix}/*|/usr/lib/libSystem.B.dylib|/System/Library/Frameworks/*${ignoredepon_for_wine}'
ignoredepon_for_wine_def=${ignoredepon_for_wine}
ignorearch_for=
ignorearch_for_wine='|${prefix}/lib*/wine/*|${prefix}/bin/widl|${prefix}/bin/wine|${prefix}/bin/wine-preloader|${prefix}/bin/winebuild|${prefix}/bin/winedump|${prefix}/bin/winegcc|${prefix}/bin/wineserver|${prefix}/bin/wmc|${prefix}/bin/wrc'
ignorearch_for_def='${prefix}/lib64/*|${prefix}/bin64/*${ignorearch_for_wine}'
ignorearch_for_wine_def=${ignorearch_for_wine}
ignore_dyn_and_static=
ignore_dyn_and_static_def='*.txt${ignore_dyn_and_static_for_wine}'
ignore_dyn_and_static_for_wine='|${prefix}/lib*/wine/*.a'
ignore_dyn_and_static_for_wine_def=${ignore_dyn_and_static_for_wine}

otool=/Library/Developer/CommandLineTools/usr/bin/otool
test -x "$otool" || otool=`which otool`
lipo=/Library/Developer/CommandLineTools/usr/bin/lipo
test -x "$lipo" || lipo=`which lipo`

#greadlink=/opt/local/bin/greadlink
readlink=/usr/bin/readlink
test -x "$readlink" || readlink=`which readlink`

greadlink=__use_builtin__
n_threads=`sysctl hw.ncpu | awk '{ print $2 }'`
test $((n_threads)) -lt 1 && n_threads=1
#n_threads=1

if test -t 2; then
    progress=yes
    color_esc='\033['
    color_end='m'
    color_rst="${color_esc}00${color_end}"

    color_def="${color_esc}00;00${color_end}"
    color_ok="${color_esc}00;32${color_end}"
    color_ko="${color_esc}00;31${color_end}"
    color_bigko="${color_esc}01;31${color_end}"
    color_warn="${color_esc}00;33${color_end}"
    color_info="${color_esc}00;36${color_end}"
    color_cmderr="${color_esc}00;30${color_end}"
    color_opt="${color_esc}00;32${color_end}"
else
    progress=
    color_rst=
    color_def=
    color_ok=
    color_ko=
    color_bigko=
    color_warn=
    color_info=
    color_cmderr=
    color_opt=
fi
color_badlink=${color_bigko}
color_badarch=${color_bigko}
color_nolib=${color_bigko}
color_a_dylib=${color_warn}
color_extlib=${color_warn}
color_which=${color_info}

#log <level> [-n] <printf_args>
log() {
    local level=$1 eol
    if test $loglevel -ge $level; then
        shift
        test "$1" = "-n" && { eol=''; shift; } || eol='\n'
        test $# -gt 0 && printf "$@" > /dev/stderr
        printf "$eol" > /dev/stderr
    fi
}
show_help() {
    prefix="${prefix:-${prefix_def}}"
    log 1 "Usage: `basename "$0"` [-hfuywsV] [-d|-a pattern] [-l level] [prefix]"
    log 1
    log 1 "This script, running on MacOS only, analyzes libs and binaries of a given prefix"
    log 1 "* checks links validity"
    log 1 "* checks universal architectures"
    log 1 "* checks for external dependencies"
    log 1
    log 1 "  -f                 toggle force scanning all in <prefix> rather than <prefix>${find_prefix} (current:${find_all})"
    log 1 "  -u                 toggle check universal binaries (current:${check_univ})"
    log 1 "  -d pattern         ignore dependencies on given libs (bash case pattern)"
    log 1 "                       current:${ignoredepon_libs:-`eval "echo \"${ignoredepon_libs_def}\""`}"
    log 1 "  -a pattern         ignore universal checks on pattern (bash case pattern)"
    log 1 "                       current:${ignorearch_for:-`eval "echo \"${ignorearch_for_def}\""`}"
    log 1 "  -y                 toggle check on dylibs without .a (current:${check_dylib_has_a})"
    log 1 "  -s                 toggle check on .a without .dylib (current:${check_a_has_dylib})"
    log 1 "  -w                 toggle wine exclusions (current:`test -n "${ignoredepon_for_wine}" && echo yes`)"
    log 1 "  -h, --help         show help"
    log 1 "  -l, --level level  set log level (current:${loglevel})"
    log 1 "  -V, --version      show version"
    log 1 "  <prefix>           scan given prefix (current:${prefix})"
    log 1
    exit $1
}
while test $# -gt 0; do
    case "$1" in
        -*) args=${1#-}                 # remove heading '-' from current argument
            while test -n "$args"; do   # loop on each option in current argument
                opt=${args}; args=${args#?}; test -n "$opt" -a -z "${opt##-*}" && args= || opt=${opt%$args} # get opt (1 char or -...), :first char in args, shift args by 1 character
                test -n "$args" && { arg=${args}; shift=break; } || { arg=$2; shift=shift; }    # prepare argument of opt, user call '$shift' if arg is used.
                log 5 "opt:'$opt' args:'$args' arg:'$arg' shift:'$shift' #=$#"
                case "${opt}" in
                    h|-help) show_help 0;;
                    f) test -n "${find_all}" && find_all= || find_all=yes;;
                    u) test -n "${check_univ}" && check_univ= || check_univ=yes;;
                    y) test -n "${check_dylib_has_a}" && check_dylib_has_a= || check_dylib_has_a=yes;;
                    s) test -n "${check_a_has_dylib}" && check_a_has_dylib= || check_a_has_dylib=yes;;
                    d) test -z "${arg}" && { log 1 "${color_ko}error${color_rst}: missing argument for option -${opt}"; exit 2; }
                       ignoredepon_libs=$arg; $shift;;
                    a) test -z "${arg}" && { log 1 "${color_ko}error${color_rst}: missing argument for option -${opt}"; exit 3; }
                       ignorearch_for=${arg}; $shift;;
                    w) test -n "${ignorearch_for_wine}" && { ignorearch_for_wine=; ignoredepon_for_wine=; ignore_dyn_and_static_for_wine=; } \
                                                        || { ignorearch_for_wine=${ignorearch_for_wine_def}; ignoredepon_for_wine=${ignoredepon_for_wine_def}
                                                             ignore_dyn_and_static_for_wine=${ignore_dyn_and_static_for_wine_def}; };;
                    l|-level) test -z "${arg}" || ! test "$arg" -ge 0 2>/dev/null && { log 1 "${color_ko}error${color_rst}: invalid argument '$arg' for option -${opt}"; exit 4; }
                        loglevel=${arg}; $shift;;
                    V|-version) log 1 "`basename "$0"` $VERSION [Copyright (C) 2020 Vincent Sallaberry]"; exit 0;;
                    *) log 1 "${color_ko}error${color_rst}: unknown option '-${opt}'\n"; show_help 1;;
                esac; done ;;
        *) test -n "$prefix" && { log 1 "${color_ko}error${color_rst}: only one prefix should be given"; exit 5; }
           test -d "$1" && prefix=$1 || { log 1 "${color_ko}error${color_rst}: prefix '$1' must be a valid directory."; exit 6; };;
    esac
    shift
done

test -z "${prefix}" && prefix="${prefix_def}"
pushd "${prefix}" >/dev/null 2>&1; prefix="`pwd`"; popd >/dev/null 2>&1
test -n "${find_all}" && find_prefix="${prefix}" || find_prefix="`eval echo "${prefix}${find_prefix}"`"
ignorearch_for=${ignorearch_for:-`eval "echo \"${ignorearch_for_def}\""`}
ignoredepon_libs=${ignoredepon_libs:-`eval "echo \"${ignoredepon_libs_def}\""`}
ignore_dyn_and_static=${ignore_dyn_and_static:-`eval "echo \"${ignore_dyn_and_static_def}\""`}

log 5 "PREFIX\t\t\t${prefix}\nIGNOREARCH\t\t${ignorearch_for}\nIGNOREDEP\t\t${ignoredepon_libs}\nIGNOREDYNSTATIC\t\t${ignore_dyn_and_static}"

if ! which -s "${greadlink}"; then
    greadlink() {
        local file= arg= newfile= canonical=
        for arg in "$@"; do
            case "$arg" in
                -e|-f) canonical=yes;;
                -*) ;;
                *) file=${arg}; break;;
            esac
        done
        if test -z "${canonical}"; then
            "$readlink" "$@"
        else
            test -e "${file}" || return 1
            newfile=${file}; while newfile=`"$readlink" "${newfile}"`; do
                case "${newfile}" in /*) ;; *) newfile="`dirname "${file}"`/${newfile}";; esac
                test "${newfile}" = "${file}" && return 1 # check recursive link
                file=${newfile}
            done
            case "${file}" in /*) ;; "") ;; *) file="`pwd`/${file}";; esac
            echo "${file}"
        fi
    }
fi

i_pattern=0; unset find_patterns; declare -a find_patterns
add_find_patterns() { for p in "$@"; do find_patterns[$i_pattern]="${p}"; i_pattern=$((i_pattern+1)); done; }
#add_find_patterns "-and" "!" "-path" "${prefix}/lib*/wine/*"

varname() {
    echo "${@%% *}" | sed -e 's|[[:space:].,;~/+-\)\(]|_|g'
}

libs_deps=
bins=

CHK_INTERNAL='#///CHK_INTERNAL//#'
n_files=0; unset files; declare -a files

log 2 "+ Scanning '${prefix}'..."
printf "${color_cmderr}" /dev/stderr

find ${find_prefix} \! -type d                                        \
    -and \( -name '*.dylib' -o -name '*.a' -o -name '*.so'              \
            -o -name '*.dll' -o -perm '+u=x' \)     \
| {
    # build list of files
    while { f=; read f || test -n "${f}"; }; do
        if test -L "${f}"; then
            if target=`greadlink -f "$f" 2>/dev/null` && test -e "${target}"; then
                # add symbolic link to list because it points to different folder than prefix
                case "${target}" in "${prefix}"/*) ;; *) files[$n_files]="$f"; n_files=$((n_files+1));; esac
            else
                log 1 "${color_rst}!! ${color_badlink}invalid link${color_rst} '${color_which}$f${color_rst}' (-> ${target})${color_cmderr}"
            fi
        else
            files[$n_files]="${f}"; n_files=$((n_files+1))
        fi
    done
    printf "${color_rst}" > /dev/stderr

    log 2 "\n+ Building list of binaries, libraries and dependencies..."

    # give number of files to pipe child
    echo "${n_files}"

    # Process files
    processfiles() {
        local i_file=$1 end=$2 f

        for(( 1 ; i_file < end ; i_file=i_file+1 )); do
            f=${files[$i_file]}

            printf "${f} ${CHK_INTERNAL}\n"
            #printf "${CHK_INTERNAL}\n" # Single_Thread_code

            case "$f" in *.la)  ;;
                         *.a)
                             echo "${f} ${f}:";;
                             #echo "${f}:";; # Single_Thread_code
                         *)
                             "${otool}" -L "${f}" 2>/dev/null | while { l=; read l desc; } || test -n "$l"; do echo "$f $l"; done #sed -ne "s|^[[:space:]]*\(.\)|${f} \1|p";;
                             ##"${otool}" -L "${f}" 2>/dev/null | /usr/bin/sed -ne "s|^[[:space:]]*\([^[:space:]][^[:space:]]*\).*|${f} \1|p";;
                             ##"${otool}" -L "${f}" 2>/dev/null | /usr/bin/awk "{ print \"${f} \" \$1 }";;
                             #####{ "${otool}" -L "${f}" 2>/dev/null && echo; } | while read l desc; do echo "$f $l"; done #sed -ne "s|^[[:space:]]*\(.\)|${f} \1|p";;
                             #"${otool}" -L "${f}" 2>/dev/null # Single_Thread_code
            esac

        done
    }

    killchilds() { test -n "$childs" && log 2 "\n+ terminating childs $childs" && kill $childs && wait && childs=; }
    childs=
    trap killchilds EXIT

    test $n_files -lt $n_threads && n_threads=$n_files
    test "$n_files" -gt 0 \
    && for(( tid=0 ; tid < n_threads ; tid=tid+1 )); do

        start=$(( (tid * n_files) / n_threads ))
        test $tid -eq $((n_threads-1)) \
            && end=$((n_files)) \
            || end=$(( ((tid+1) * n_files) / n_threads ))

        log 3 "+ Starting thread #$tid range [$start:$((end-1))]"
        processfiles $start $end & childs="${childs} $!"

    done
    echo # necessary to make the 'while read ...; do' loop process all input

} | {
    read n_files
    # build
    #   bins        : the list of binaries/libs to be checked for universal
    #   libs_deps   : the list of external libs whose dependencies must be printed
    print_ratio() {
        local i_file=$1 n_files=$2 ratio newtsp
        if test -n "$progress" -a ${n_files} -gt 0; then
            ratio=$(( ((i_file * 100) / n_files) ))
            if test $ratio -gt $oldratio; then
                newtsp=`date '+%s'`
                eta=$(( ((newtsp-tsp) * (n_files-i_file-1)) / (i_file+1) ))
                log 2 -n '\r%21s %-6s ETA %02d:%02d:%02d ' "$i_file / $n_files" "[${ratio}%]" $((eta / 3600)) $(((eta%3600)/60)) $((eta % 60))
                oldratio=$ratio
            fi
        fi
    }

    i_file=0; oldratio=-1; tsp=`date '+%s'`; print_ratio 0 $n_files

    while read f l desc; do
    #f=; while read l desc; do # Single_Thread_code
        case "${l}" in
            ${CHK_INTERNAL})
                i_file=$((i_file+1))
                print_ratio ${i_file} ${n_files}
                continue;;
            "${f}")
                continue;;
            *:)
                l=${l%:}; f=$l
                #log 4 "\nOTOOL FILE $f LIB '$l'"
                test -n "$desc" && log 1 "!! ${color_warn}warning${color_rst}: wrong otool output for ${color_which}$f${color_rst}"
                ;;
        esac

        #add lib/bin to list of binaries to be checked for architecture
        bins+=" $l"; #`greadlink -f "$l"`";

        # Add library only if not excluded
        eval "case \"$l\" in *.la|*.a|${ignoredepon_libs}) false;; *.dylib|*.so|*.dll) true;; *) false;; esac" \
            && { libs_deps+=" $l"; eval "lib_`varname "$l"`+=\" $f\""; }
    done

    wait
    trap - EXIT

    oldratio=-1; print_ratio $n_files $n_files; log 2

    # Check universal architectures of given libraries
    log 2 "\n+ Checking libraries and binaries formats..."

    for f in `echo ${bins} | tr ' ' '\n' | sort | uniq`; do
        eval "case \"$f\" in                                                                                \
                ${ignore_dyn_and_static}) true;;                                                            \
                *.a)            miss=".dylib";  test -z \"$check_a_has_dylib\" -o -e \"${f%.a}.dylib\";;    \
                *.dylib|*.so)   miss=".a";      test -z \"$check_dylib_has_a\" -o -e \"${f%.*}.a\";;    \
                *)              true;;                                                                      \
        esac" || { log 1 "!! ${color_a_dylib}${miss} missing${color_rst} for ${color_which}$f${color_rst}"; }
        if ! test -e "${f}"; then
            log 1 "!! ${color_nolib}lib not found${color_rst}: ${color_which}'$f'${color_rst}"
        elif test -n "$check_univ" && eval "case \"${f}\" in ${ignorearch_for}) false;; *) true;; esac"; then
            "$lipo" "$f" -verify_arch i386 x86_64 >/dev/null 2>&1 \
            || { log 1 "!! ${color_badarch}missing arch${color_rst} in ${color_which}'$f'${color_rst} $("$lipo" -info "$f" 2>/dev/null | tr '\n' ' ')"; \
               } # FIXME_libs_deps+=" ${f}"; }
        fi
    done
    # Check external dependencies
    log 2 "\n+ Checking external dependencies..."
    for l in `echo "${libs_deps}" | tr ' ' '\n' | sort | uniq`; do
        test -e "$l" && color=${color_warn} || color=${color_ko}
        eval "log 1 \"${color}${l}${color_rst} [\${lib_`varname "$l"`} ]\""
        log 2
    done
}


#tests for greadlink
if false; then
greadlink /usr/local/wine_NOTFOUND/lib/libwine.dylib && echo "!! fail"
pushd /usr/local/wine >/dev/null 2>&1
greadlink lib/libwine.dylib || echo "!! fail"
greadlink lib/libwine.1.dylib || echo "!! fail"
greadlink lib/libwine.1.0.dylib && echo "!! fail"
popd >/dev/null 2>&1

greadlink -f /usr/local/wine_NOTFOUND/lib/libwine.dylib
greadlink -f /usr/local/wine/lib/libwine.dylib
pushd /usr/local/wine >/dev/null 2>&1
greadlink -f lib/libwine.dylib
greadlink -f lib/libwine.1.dylib
greadlink -f lib/libwine.1.0.dylib
popd >/dev/null 2>&1
fi

