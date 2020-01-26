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
# * FIXME: vgetopt not working
# * FIXME: vtab_del/vtab_find: not working when giving a pattern with spaces
# * TODO: vreadlink and vprint_ratio not tested
#
##
vutil_version() {
    echo "0.1.0"
}
#vlog_setlevel <loglevel>
vlog_setlevel() {
    local arg=$1; arg=${arg#-}
    printf -- "$arg" | { ret=false; while read -n1 c; do case "$c" in [0-9]) ret=true;; *) ret=false; break;; esac; done; $ret; } \
    && VLOG_LEVEL=$1 \
    || { vlog 0 "!! vlog_setlevel: bad level '$1'"; return 1; }
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
        test $# -gt 0 && printf "$@" > "${VLOG_OUT}"
        printf "$eol" > "${VLOG_OUT}"
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
#vtab_find <array_name> <elt> [<idx_name>] [start_idx]
#  * if idx_name is given, it is set to found index
#  * if start_idx is given, search will start on given index (usefull to find duplicates)
#    eg: idx=-1; while vtab_find tab 4 idx $((idx+1)); do echo "->found #$idx '${tab[$idx]}'"; done
vtab_find() {
    local _tabn=$1 _n _i _find=$2 _idxn=$3 _startidx=$4 _elt; shift; shift; shift
    eval "_n=\${#${_tabn}[@]}"
    test -z "${_startidx}" && _startidx=0
    for(( _i = ${_startidx} ; _i < _n ; _i = _i + 1 )); do
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
    local _tabn=$1 _arg _i _j _n _elt; shift
    eval "_n=\${#${_tabn}[@]}"
    for(( _i = 0 ; _i < _n ; _i = _i + 1 )); do
        eval "_elt=\"\${${_tabn}[${_i}]}\""
        for _arg in "$@"; do
            if eval "case \"${_elt}\" in ${_arg}) true;; *) false;; esac"; then
                vlog 5 "vtab_del: '${_tabn}': removing #${_i} (${_elt}) tabsz=`eval echo "\\\${#${_tabn}[@]}"`"
                for (( _j = _i + 1 ; _j < _n ; _j = _j + 1 )); do
                    eval "${_tabn}[$((_j - 1))]=\"\${${_tabn}[${_j}]}\""
                done
                _n=$((_n - 1))
                _i=$((_i - 1))
                eval "unset ${_tabn}[${_n}]"
                break
            fi
        done
    done
}
#vgetopt_shift
vgetopt_shift() {
    VGETOPT_IDX=$((VGETOPT_IDX+1))
}
#vgetopt <opt_varname> <arg_varname> [<arguments>]
vgetopt() {
    local _optvar=$1 _argvar=$2; shift; shift
    if test -z "${VGETOPT_IDX}"; then
        VGETOPT_IDX=0
        unset VGETOPT_ARGS VGETOPT_OPTARGS
        declare -a VGETOPT_ARGS
        declare -a VGETOPT_OPTARGS
        while test $# -gt 0; do
            case "$1" in
                -*) args=${1#-}                 # remove heading '-' from current argument
                    while test -n "$args"; do   # loop on each option in current argument
                        opt=${args}; args=${args#?}; test -n "$opt" -a -z "${opt##-*}" && args= || opt=${opt%$args} # get opt (1 char or -...), :first char in args, shift args by 1 character
                        test -n "$args" && { arg=${args}; shift=break; } || { arg=$2; shift=shift; }    # prepare argument of opt, user call '$shift' if arg is used.
                        vlog 5 "opt:'$opt' args:'$args' arg:'$arg' shift:'$shift' #=$#"
                        #case "${opt}" in
                            # Short or long option management
                            vtab_add VGETOPT_ARGS "-${opt}"
                            vtab_add VGETOPT_OPTARGS "${arg}"
                        #esac
                    done ;;
                *)
                    # argument management
                    vtab_add VGETOPT_ARGS "$1"
                    vtab_add VGETOPT_OPTARGS ""
                    ;;
            esac
            shift
        done
    fi
    if test $VGETOPT_IDX -lt ${#VGETOPT_ARGS[@]}; then
        eval "${_optvar}=\"${VGETOPT_ARGS[${VGETOPT_IDX}]}\""
        eval "${_argvar}=\"${VGETOPT_OPTARGS[${VGETOPT_IDX}]}\""
        VGETOPT_IDX=$((VGETOPT_IDX+1))
        return 0
    else
        unset VGETOPT_IDX VGETOPT_ARGS VGETOPT_OPTARGS
        return 1
    fi
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
#vprint_ratio <cur_index> <n_indexes> <start_time_seconds_varname> <prev_ratio_varname>
vprint_ratio() {
    local _starttsp_n=$3 _oldratio_n=$4 _oldratio_v _starttsp_v
    eval "_oldratio_v=\${${_oldratio_n}}; _starttsp_v=\${${_starttsp_n}}; \
          test -z "\${_starttsp_v}" && { _starttsp_v=`date '+%s'`; ${_starttsp_n}=${_starttsp_v}; }"
    test -z "${_oldratio_v}" && _oldratio_v=-1

    local _i_file=$1 _n_files=$2 _ratio _newtsp _eta
    if test -n "${vcolor_esc}" -a ${_n_files} -gt 0; then
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
#COLORS GLOBALS
if test -t 2; then
    vcolor_esc='\033['
    vcolor_end='m'
    vcolor_rst="${color_esc}00${color_end}"

    vcolor_def="${color_esc}00;00${color_end}"
    vcolor_ok="${color_esc}00;32${color_end}"
    vcolor_ko="${color_esc}00;31${color_end}"
    vcolor_bigko="${color_esc}01;31${color_end}"
    vcolor_warn="${color_esc}00;33${color_end}"
    vcolor_info="${color_esc}00;36${color_end}"
    vcolor_cmderr="${color_esc}00;30${color_end}"
    vcolor_opt="${color_esc}00;32${color_end}"
else
    vcolor_rst=
    vcolor_def=
    vcolor_ok=
    vcolor_ko=
    vcolor_bigko=
    vcolor_warn=
    vcolor_info=
    vcolor_cmderr=
    vcolor_opt=
fi

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

