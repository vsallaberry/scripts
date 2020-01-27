#!/bin/bash
# --
# Copyright (C) 2020 Vincent Sallaberry
# scripts/sh/vutil/vutil.sh <https://github.com/vsallaberry/scripts>
# sh utilities.
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
# TODO
# ====
# * TODO: vgetopt : clean '--' handling
# * TODO: vreadlink and vprint_ratio not tested
#
##
VUTIL_underscore="$_"
VUTIL_arobas="$@"
###################################################################
#vutil_version()
vutil_version() {
    echo "0.2.0"
}
###################################################################
# Shell Specific Stuff
###################################################################
if test -n "${KSH_VERSION}"; then
    local i 2> /dev/null || local() { typeset "$@"; }
    vutil_sourcing() { vutil_sourcing_ksh "$@"; }
    VUTIL_read_n1="read -N 1"
elif test -n "${ZSH_VERSION}"; then
    vutil_sourcing() { vutil_sourcing_zsh "$@"; }
    VUTIL_read_n1_fun() { read -u 0 -k 1 "$@"; }
    VUTIL_read_n1=VUTIL_read_n1_fun
else
    vutil_sourcing() { vutil_sourcing_bash "$@"; }
    VUTIL_read_n1="read -n 1"
fi
###################################################################
# vutil functions
###################################################################
# test wrapper to force use of builtin
test() {
    [ "$@" ]
}
#vlog_setlevel <loglevel>
vlog_setlevel() {
    local arg=$1; arg=${arg#-}
    printf -- "$arg" | { ret=false; while ${VUTIL_read_n1} c; do case "$c" in [0-9]) ret=true;; *) ret=false; break;; esac; done; $ret; } \
    && { test ${VLOG_LEVEL} -ge 5 -o ${arg} -ge 5 && vlog 0 "vlog_setlevel: new level ${arg}"; VLOG_LEVEL=${arg}; } \
    || { vlog 0 "!! vlog_setlevel: bad level '${arg}'"; return 1; }
}
#vlog_setout <file>
vlog_setout() {
    test -e "$1" && VLOG_OUT=$1 || { vlog 0 "!! vlog_setout: bad file '$1'"; return 1; }
}
#vlog <level> [-n] [<printf_args>]
vlog() {
    local level=$1 eol
    if test ${VLOG_LEVEL} -ge $level; then
        shift
        test "$1" = "-n" && { eol=''; shift; } || eol='\n'
        test $# -gt 0 && printf -- "$@" >> "${VLOG_OUT}"
        printf -- "$eol" >> "${VLOG_OUT}"
    fi
}
#vtab_add <array_name> <elt_1> [... [<elt_n>]]
vtab_add() {
    local _tabn=$1 _arg _i; shift
    eval "_i=\${#${_tabn}[@]}"
    for _arg in "$@"; do
        eval "${_tabn}[${_i}]=\"${_arg}\""; _i=$((_i + 1))
    done
}
#vescape_spaces <var_name> : escape spaces with '\\ ' in <var_name>
vescape_spaces() {
    local _find_n=$1 _start= _end _new
    eval "_end=\${${_find_n}}"
    while true; do case "${_end}" in
        *" "*)
            _new=${_end}
            _end=${_new#* }
            _new=${_new%% *}
            _start="${_start}${_new}\\ " ;;
        *)  break ;;
    esac; done
    eval "${_find_n}=\"${_start}${_end}\""
    vlog 6 "vescape_spaces: ${_start}${_end} start:${_start} end:${_end}"
}
#vtab_find <array_name> <elt> [<idx_name>] [start_idx]
#  * if idx_name is given, it is set to found index
#  * if start_idx is given, search will start on given index (usefull to find duplicates)
#    eg: idx=-1; while vtab_find tab 4 idx $((idx+1)); do echo "->found #$idx '${tab[$idx]}'"; done
vtab_find() {
    local _tabn=$1 _n _i _find=$2 _idxn=$3 _startidx=$4 _elt; shift; shift; shift
    eval "_n=\${#${_tabn}[@]}"
    test -z "${_startidx}" && _startidx=0

    vescape_spaces _find
    for (( _i = ${_startidx} ; _i < _n ; _i = _i + 1 )); do
        eval "_elt=\"\${${_tabn}[${_i}]}\""
        if eval "case \"${_elt}\" in ${_find}) true;; *) false;; esac"; then
            test -n "${_idxn}" && eval "${_idxn}=${_i}"
            return 0
        fi
    done
    return 1
}
#vtab_del <array_name> <elt_1> [... [<elt_n>]]
#  * delete all occurence of given patterns (elt_X)
vtab_del() {
    local _ret=1 _tabn=$1 _arg _i _j _n _elt; shift
    eval "_n=\${#${_tabn}[@]}"
    for (( _i = 0 ; _i < _n ; _i = _i + 1 )); do
        eval "_elt=\"\${${_tabn}[${_i}]}\""
        for _arg in "$@"; do
            vescape_spaces _arg
            if eval "case \"${_elt}\" in ${_arg}) true;; *) false;; esac"; then
                vlog 5 "vtab_del: '${_tabn}': removing #${_i} (${_elt}) tabsz=`eval echo "\\\${#${_tabn}[@]}"`"
                for (( _j = _i + 1 ; _j < _n ; _j = _j + 1 )); do
                    eval "${_tabn}[$((_j - 1))]=\"\${${_tabn}[${_j}]}\""
                done
                _n=$((_n - 1))
                _i=$((_i - 1))
                eval "unset ${_tabn}[${_n}]"
                _ret=0
                break
            fi
        done
    done
    return $_ret
}
#vgetopt_shift: called by user when it uses one option argument
vgetopt_shift() {
    vlog 6 "vgetopt: VGETOPT_shift=${VGETOPT_shift}"
    test "${VGETOPT_shift}" = "shift" && VGETOPT_idx=$((VGETOPT_idx+1)) || VGETOPT_opts=
    VGETOPT_shift='shift'
}
#vgetopt <opt_varname> <arg_varname> [<arguments>]
# example:
# while vgetopt opt arg "$@"; do
#        case "$opt" in
#            -h|--help)      show_help 0;;
#            -l|--level)     test -n "$arg" || { vlog 1 "missing argument for option '$opt'"; exit 3; }
#                            vlog_setlevel "$arg"; vgetopt_shift;;
#            -*)             vlog 1 "error: unknown option '$opt'"; show_help 1;;
#            '') case "${arg}" in
#                    *) vlog 1 "error: bad argument '${arg}'"; show_help 2;;
#                esac;;
#        esac
#    done
#
vgetopt() {
    local _optvar=$1 _argvar=$2; shift; shift
    local _cur _opt _opts _arg _args _i

    if test -z "${VGETOPT_idx}"; then
        VGETOPT_idx=0
        VGETOPT_opts=
        VGETOPT_takeopts=yes
    fi
    shift ${VGETOPT_idx}

    if test -n "${VGETOPT_opts}"; then
        _cur="-${VGETOPT_opts}"
    elif test $# -gt 0; then
        _cur=$1
        VGETOPT_idx=$((VGETOPT_idx+1))
        if test "${_cur}" = "--"; then
            # TODO : clean this and handle end of arguments
            VGETOPT_takeopts=
            shift
            VGETOPT_idx=$((VGETOPT_idx+1))
            _cur=$1
        fi
        shift
    else
        unset VGETOPT_idx
        return 1
    fi

    vlog 7 "vgetopt: new call, cur='${_cur}' idx=${VGETOPT_idx} #=$#"

    if test -z "${VGETOPT_takeopts}" || case "${_cur}" in
        -?*) _opts=${_cur#-}                 # remove heading '-' from current argument
             _opt=${_opts}; _opts=${_opts#?}; test -n "${_opt}" -a -z "${_opt##-*}" && _opts= || _opt=${_opt%${_opts}} # get opt (1 char or -...), :first char in args, shift args by 1 character
             test -n "${_opts}" && { _arg=${_opts}; VGETOPT_shift=break; } || { _arg=$1; VGETOPT_shift=shift; }    # prepare argument of opt, user call '$shift' if arg is used.
             _cur="-${_opt}"
             _args[0]=${_arg}; _i=1; for _arg in "$@"; do _args[${_i}]="${_arg}"; _i=$((_i + 1)); done
             vlog 6 "vgetopt: OPT '${_cur}' opts='${_opts}' args='${_args[@]}' shift='${VGETOPT_shift}' #=$#"
             false;;
    esac; then
            # argument management
            vlog 6 "vgetopt: ARG '${_cur}' #=$#"
            _args=${_cur}
            _cur=
    fi

    eval "${_optvar}=\"${_cur}\""
    eval "${_argvar}=\"${_args}\""
    VGETOPT_opts=${_opts}
    return 0
}
# utilities for sh unitary tests
vtest_start() {
    _vtest_ntest=0 _vtest_nko=0 _vtest_nok=0
}
vtest_ok() {
    _vtest_ntest=$((_vtest_ntest + 1))
    _vtest_nok=$((_vtest_nok + 1))
    vlog 1 -n "[${VCOLOR_ok}OK${VCOLOR_rst}] "; vlog 1 "$@"
}
vtest_fail() {
    _vtest_ntest=$((_vtest_ntest + 1))
    _vtest_nko=$((_vtest_nko + 1))
    vlog 1 -n "[${VCOLOR_ko}FAIL${VCOLOR_rst}] "; vlog 1 "$@"
}
vtest_test() {
    local _label=$1; shift
    vlog 1 -n "${_label} "
    test "$@" && vtest_ok || vtest_fail
}
vtest_report() {
    vlog 1 "%d tests, %d ${VCOLOR_ok}OK${VCOLOR_rst}, %d ${VCOLOR_ko}KO${VCOLOR_rst}" ${_vtest_ntest} ${_vtest_nok} ${_vtest_nko}
    test ${_vtest_nko} -gt 0 \
        && { vlog 1 "${VCOLOR_ko}FAILED !!!${VCOLOR_rst}"; return ${_vtest_nko}; } \
        || { vlog 1 "${VCOLOR_ok}ALL OK${VCOLOR_rst}"; return 0; }
}
#vreadlink [args] - gnu readlink emulation
vreadlink() {
    local file= arg= newfile= canonical=
    for arg in "$@"; do
        case "$arg" in
            -e|-f) canonical=yes;;
            -*) ;;
            *) file=${arg}; break;;
        esac
    done
    if test -z "${canonical}"; then
        "${VUTIL_readlink}" "$@"
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
#vprint_ratio <cur_index> <n_indexes> <start_time_seconds_varname> <prev_ratio_varname>
vprint_ratio() {
    local _starttsp_n=$3 _oldratio_n=$4 _oldratio_v _starttsp_v
    eval "_oldratio_v=\${${_oldratio_n}}; _starttsp_v=\${${_starttsp_n}}; \
          test -z "\${_starttsp_v}" && { _starttsp_v=`date '+%s'`; ${_starttsp_n}=${_starttsp_v}; }"
    test -z "${_oldratio_v}" && _oldratio_v=-1

    local _i_file=$1 _n_files=$2 _ratio _newtsp _eta
    if test -n "${VCOLOR_esc}" -a ${_n_files} -gt 0; then
        _ratio=$(( ((_i_file * 100) / _n_files) ))
        if test ${_ratio} -gt ${_oldratio_v}; then
            _newtsp=`date '+%s'`
            _eta=$(( ((_newtsp - _starttsp_v) * (_n_files - _i_file - 1)) / (_i_file + 1) ))
            vlog 2 -n '\r%21s %-6s ETA %02d:%02d:%02d ' "${_i_file} / ${_n_files}" "[${_ratio}%]" $((_eta / 3600)) $(((_eta % 3600)/60)) $((_eta % 60))
            eval "${_oldratio_n}=${_ratio}"
        fi
    fi
}
#INTERNAL GLOBALS
VLOG_OUT=/dev/stderr
VLOG_LEVEL=1
VUTIL_readlink=/usr/bin/readlink
test -x "${VUTIL_readlink}" || { VUTIL_readlink=`which readlink`; vlog 1 "vutil: which readlink -> '${VUTIL_readlink}'"; }
#COLORS GLOBALS
if test -t 2; then
    VCOLOR_esc='\033['
    VCOLOR_end='m'
    VCOLOR_rst="${VCOLOR_esc}00${VCOLOR_end}"

    VCOLOR_def="${VCOLOR_esc}00;00${VCOLOR_end}"
    VCOLOR_ok="${VCOLOR_esc}00;32${VCOLOR_end}"
    VCOLOR_ko="${VCOLOR_esc}00;31${VCOLOR_end}"
    VCOLOR_bigko="${VCOLOR_esc}01;31${VCOLOR_end}"
    VCOLOR_warn="${VCOLOR_esc}00;33${VCOLOR_end}"
    VCOLOR_info="${VCOLOR_esc}00;36${VCOLOR_end}"
    VCOLOR_cmderr="${VCOLOR_esc}00;30${VCOLOR_end}"
    VCOLOR_opt="${VCOLOR_esc}00;32${VCOLOR_end}"
else
    VCOLOR_rst=
    VCOLOR_def=
    VCOLOR_ok=
    VCOLOR_ko=
    VCOLOR_bigko=
    VCOLOR_warn=
    VCOLOR_info=
    VCOLOR_cmderr=
    VCOLOR_opt=
fi
############### CRAP ############################################################
vlog 1 "$0: 0='$0' _='${VUTIL_underscore}' @='${VUTIL_arobas}'"
#vutil_sourcing() - tells wheter this script is executed or sourced
vutil_sourcing_bash() {
    local my0
    test -n "$1" && my0=$1 || my0=$0
    test -e "${my0}" && read -n 1 c < "${my0}" && case "$c" in [[:ascii:]]) true;; *) false;; esac \
    && { VUTIL_sourcing=1;  VUTIL_exit=exit;    return ${VUTIL_sourcing}; } \
    || { VUTIL_sourcing=0;  VUTIL_exit=return;  return ${VUTIL_sourcing}; }
}
vutil_sourcing_ksh() {
    test -n "$1" && my0=$1 || my0=$0
    test -e "${my0}" && read -N 1 c < "${my0}" && case "$c" in [[:print:]]) true;; *) false;; esac \
    && { VUTIL_sourcing=1;  VUTIL_exit=exit;    return ${VUTIL_sourcing}; } \
    || { VUTIL_sourcing=0;  VUTIL_exit=return;  return ${VUTIL_sourcing}; }
}
vutil_sourcing_zsh() {
    test    \( -z "${VUTIL_underscore}" -o \! -x "${VUTIL_underscore}" \) \
         -a \( -z "${VUTIL_underscore}" -o "${VUTIL_underscore}" \!= "${VUTIL_arobas}" \) \
    && { VUTIL_sourcing=1;  VUTIL_exit=exit;    return ${VUTIL_sourcing}; } \
    || { VUTIL_sourcing=0;  VUTIL_exit=return;  return ${VUTIL_sourcing}; }
}
#vutil_myname()
vutil_myname() {
    local my0 mydir myname mypath
    my0="${BASH_SOURCE[0]}"; test -z "$my0" && my0=$0
    mydir="$(dirname "$my0")"; pushd "${mydir}" > /dev/null; mydir="`pwd`"; popd > /dev/null
    myname="$(basename "$my0")"; mypath="${mydir}/${myname}"
}
### END CRAP

#####################################################################################################
# TESTS
#####################################################################################################
if vutil_sourcing "$0" "$underscore"; then
    vlog 1 "$0: SOURCING (shell: ${BASH_VERSION:+bash ${BASH_VERSION}}${KSH_VERSION:+ksh ${KSH_VERSION}}${ZSH_VERSION:+zsh ${ZSH_VERSION}})"
else
    vlog 1 "$0: NOT SOURCING (shell: ${BASH_VERSION:+bash ${BASH_VERSION}}${KSH_VERSION:+ksh ${KSH_VERSION}}${ZSH_VERSION:+zsh ${ZSH_VERSION}})"
    dotests=

    show_help() {
        echo "Usage `basename "$0"` [-hVT] [-l <level>]"
        echo "  -h, --help              show help"
        echo "  -V, --version           show version"
        echo "  -l, --level <level>     set log level"
        echo "  -T, --test              perform unitary tests"
        exit $1
    }
    while vgetopt opt arg "$@"; do
        case "$opt" in
            -h|--help)      show_help 0;;
            -V|--version)   vutil_version; exit 0;;
            -l|--level)     test -n "$arg" || { vlog 1 "missing argument for option '$opt'"; exit 3; }
                            vlog_setlevel "$arg"; vgetopt_shift;;
            -T|--test)      dotests=yes;;
            -*)             vlog 1 "error: unknown option '$opt'"; show_help 1;;
            '') case "${arg}" in
                    *) vlog 1 "error: bad argument '${arg}'"; show_help 2;;
                esac;;
        esac
    done

    test -z "${dotests}" && ${VUTIL_exit} 0

    vtest_start

    vlog 1 "** 1 LOG"
    vlog 2 "** 2 LOG"
    vlog 3 "** 3 LOG"
    vlog 4 "** 4 LOG"


    vlog 1 "\n** TAB TESTS **"

    unset tab; declare -a tab;
    ptab() {
        vlog 1 "tab #=${#tab[@]}"
        local e i=0
        for e in "${tab[@]}"; do
            vlog 1 "#$i '$e'"; i=$((i+1))
        done
        vlog 1
    }
    vtab_add tab 1
    vtab_add tab 2
    vtab_add tab 3
    vtab_add tab 4
    vtab_add tab 5 "6 six" 7 4 "8 eight"
    ptab

    vlog 1 "TAB FIND 6*:"
    vtab_find tab "6*" idx && vtest_ok "->found #$idx '${tab[$idx]}'" || vtest_fail "!! NOT FOUND"
    vlog 1 "TAB find 4:"
    idx=-1; while vtab_find tab 4 idx $((idx+1)); do
        vlog 1 " ->found #$idx '${tab[$idx]}'"
    done
    vlog 1 "TAB FIND abc:"
    vtab_find tab abc && vtest_fail "!! -> found !" || vtest_ok "-> not found"
    vlog 1 "TAB FIND 8 eight:"
    vtab_find tab "8 eight" && vtest_ok "-> found !" || vtest_fail "!! -> not found"
    vlog 1 "TAB FIND '[0-9] *"
    vtab_find tab "[0-9] *" && vtest_ok "-> found !" || vtest_fail "!! -> not found"

    vlog 1 "TAB DEL 2:"
    vtab_del tab "2"
    vtest_test "retval" $? -eq 0
    ptab

    vlog 1 "TAB DEL 1:"
    vtab_del tab 1
    vtest_test "retval" $? -eq 0
    ptab

    vlog 1 "TAB DEL NOT FOUND:"
    vtab_del tab "ELEMENT NOT FOUND"
    vtest_test "retval" $? -ne 0
    ptab


    vlog 1 "TAB DEL 8:"
    vtab_del tab "8*"
    vtest_test "retval" $? -eq 0
    ptab

    vlog 1 "TAB DEL ALL:"
    vtab_del tab "*"
    vtest_test "retval" $? -eq 0
    vtest_test "array empty" ${#tab[@]} -eq 0
    ptab

    #tests for vreadlink
    if false; then
    vreadlink /usr/local/wine_NOTFOUND/lib/libwine.dylib && echo "!! fail"
    pushd /usr/local/wine >/dev/null 2>&1
    vreadlink lib/libwine.dylib || echo "!! fail"
    vreadlink lib/libwine.1.dylib || echo "!! fail"
    vreadlink lib/libwine.1.0.dylib && echo "!! fail"
    popd >/dev/null 2>&1

    vreadlink -f /usr/local/wine_NOTFOUND/lib/libwine.dylib
    vreadlink -f /usr/local/wine/lib/libwine.dylib
    pushd /usr/local/wine >/dev/null 2>&1
    vreadlink -f lib/libwine.dylib
    vreadlink -f lib/libwine.1.dylib
    vreadlink -f lib/libwine.1.0.dylib
    popd >/dev/null 2>&1
    fi

    vtest_report
fi
