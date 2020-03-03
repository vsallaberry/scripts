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
VUTIL_0="$0"

###################################################################
#vutil_version()
vutil_version() {
    echo "0.5.1 Copyright (C) 2020 Vincent Sallaberry / GNU GPL licence"
}
# test wrapper to force use of builtin / not needed
#test() {
#    [ "$@" ]
#}
###################################################################
# Shell Specific Stuff
###################################################################
if test -n "${KSH_VERSION}"; then
    VUTIL_shell=ksh
    VUTIL_shellversion="${KSH_VERSION}"
    VUTIL_underscore="${VUTIL_underscore#\*[0-9]*\*}"
    VUTIL_underscore="${VUTIL_underscore%%:*}"
    local i 2> /dev/null || local() { typeset "$@"; }
    declare > /dev/null 2>&1 || declare() { typeset "$@"; }
    vutil_sourcing() { vutil_sourcing_ksh "$@"; }
    VUTIL_read_n1="read -N 1"
    pushd() {
        vtab_add VUTIL_ksh_pushd "`pwd`"
        cd "$@"
    }
    popd() {
        local _prev
        vtab_pop VUTIL_ksh_pushd _prev
        cd "${_prev}"
    }
elif test -n "${ZSH_VERSION}"; then
    VUTIL_shell=zsh
    VUTIL_shellversion="${ZSH_VERSION}"
    vutil_sourcing() { vutil_sourcing_zsh "$@"; }
    VUTIL_read_n1_fun() { read -u 0 -k 1 "$@"; }
    VUTIL_read_n1=VUTIL_read_n1_fun
else
    test -n "${BASH_VERSION}" \
    && { VUTIL_shell=bash; VUTIL_shellversion="${BASH_VERSION}"; } \
    || { VUTIL_shell=unknown_sh; VUTIL_shellversion="unknown"; }
    vutil_sourcing() { vutil_sourcing_bash "$@"; }
    VUTIL_read_n1="read -n 1"
fi
###################################################################
# vutil functions
###################################################################
#vlog_setlevel <loglevel>
vlog_setlevel() {
    local arg="$1"
    local _test_arg="${arg#-}"
    local _file="${arg#*@}"
    if test "${_file}" \!= "${arg}" -a -n "${_file}"; then
        arg="${arg%%@*}"
        vlog_setout "${_file}" || return 1
    fi
    printf -- "${_test_arg}" | { ret=false; while ${VUTIL_read_n1} c; do case "$c" in [0-9]) ret=true;; *) ret=false; break;; esac; done; $ret; } \
    && { test ${VLOG_LEVEL} -ge 5 -o ${arg} -ge 5 && vlog 0 "vlog_setlevel: new level ${arg} @${VLOG_OUT}"; VLOG_LEVEL="${arg}"; } \
    || { vlog 0 "!! vlog_setlevel: ${VCOLOR_ko}error${VCOLOR_rst}: bad level '${VCOLOR_opt}${arg}${VCOLOR_rst}'"; return 1; }
}
#vlog_setout <file>
vlog_setout() {
    local _file="$1" _dir="`dirname "$1"`"
    test -w "${_file}" -o -w "${_dir}" \
    && VLOG_OUT="${_file}" && VUTIL_setcolors \
    || { vlog 0 "!! vlog_setout: ${VCOLOR_ko}error${VCOLOR_rst}: bad file '${VCOLOR_opt}${_file}${VCOLOR_rst}'"; return 1; }
}
#vlog <level> [-n] [<printf_args>]
vlog() {
    local level="$1" eol
    if test ${VLOG_LEVEL} -ge $level; then
        shift
        test "$1" = "-n" && { eol=''; shift; } || eol='\n'
        test $# -gt 0 && printf -- "$@" >> "${VLOG_OUT}"
        printf -- "$eol" >> "${VLOG_OUT}"
    fi
}
#vtab_add <array_name> <elt_1> [... [<elt_n>]]
#!! array index starts at 1 for zsh compatibility
vtab_add() {
    local _tabn="$1" _arg _i; shift
    eval "_i=\${#${_tabn}[@]}"
    for _arg in "$@"; do
        _i=$((_i + 1))
        eval "${_tabn}[${_i}]=\${_arg}"
    done
}
#vescape_spaces <var_name> : escape spaces with '\\ ' in <var_name>
vescape_spaces() {
    local _find_n="$1" _start _end _new _var _tok
    for _tok in "\\" \" ' ' "'"; do
        _start=
        eval "_end=\${${_find_n}}"
        while true; do case "${_end}" in
            *"${_tok}"*)
                _new=${_end}
                _end=${_new#*${_tok}}
                _new=${_new%%${_tok}*}
                test "${_tok}" = "'" && _start=${_start}${_new}"\"'\"" \
                || _start=${_start}${_new}\\${_tok} ;;
            *)  break ;;
        esac; done
        eval "${_find_n}=\${_start}\${_end}"
    done
    #vlog 6 "vescape_spaces: ${_start}${_end} start:${_start} end:${_end}"
}
#vtab_find <array_name> <elt> [<idx_name>] [start_idx]
#  * if idx_name is given, it is set to found index
#  * if start_idx is given, search will start on given index (usefull to find duplicates)
#    eg: idx=0; while vtab_find tab 4 idx $((idx+1)); do echo "->found #$idx '${tab[$idx]}'"; done
#!! array index starts at 1 for zsh compatibility
vtab_find() {
    local _tabn="$1" _n _i _find
    _find=$2

    local _idxn="$3" _startidx="$4" _elt; shift; test -n "${_idxn}" && shift; test -n "${_startidx}" && shift
    eval "_n=\${#${_tabn}[@]}"
    test -z "${_startidx}" && _startidx=1

    vescape_spaces _find
    for (( _i = ${_startidx} ; _i <= _n ; _i = _i + 1 )); do
        eval "_elt=\${${_tabn}[${_i}]}"
        if eval "case \${_elt} in ${_find}) true;; *) false;; esac"; then
            test -n "${_idxn}" && eval "${_idxn}=${_i}"
            return 0
        fi
    done
    return 1
}
#vtab_delat <array_name> <idx>
#!! array index starts at 1 for zsh compatibility
vtab_delat() {
    local _tabn="$1" _idx="$2" _n _j
    eval "_n=\${#${_tabn}[@]}"
    test ${_idx} -le "${_n}" -a ${_idx} -gt 0 || return 1
    for (( _j = _idx + 1 ; _j <= _n ; _j = _j + 1 )); do
        eval "${_tabn}[$((_j - 1))]=\${${_tabn}[${_j}]}"
    done
    test -n "${ZSH_VERSION}" && eval "${_tabn}[${_n}]=()" 2> /dev/null # zsh
    eval "unset \"${_tabn}[${_n}]\""
}
#vtab_pop <array_name> <value_varname>
#!! array index starts at 1 for zsh compatibility
vtab_pop() {
    local _tabn="$1" _valn="$2" _n
    eval "_n=\${#${_tabn}[@]}"
    eval "${_valn}=\${${_tabn}[${_n}]}"
    vtab_delat "${_tabn}" "${_n}"
}
#vtab_pop0 <array_name> <value_varname>
#!! array index starts at 1 for zsh compatibility
vtab_pop0() {
    local _tabn="$1" _valn="$2" _n
    eval "${_valn}=\${${_tabn}[1]}"
    vtab_delat "${_tabn}" "1"
}
#vtab_del <array_name> <elt_1> [... [<elt_n>]]
#  * delete all occurence of given patterns (elt_X)
#!! array index starts at 1 for zsh compatibility
vtab_del() {
    local _ret=1 _tabn="$1" _arg _i _j _n _elt; shift
    eval "_n=\${#${_tabn}[@]}"
    for (( _i = 1 ; _i <= _n ; _i = _i + 1 )); do
        eval "_elt=\${${_tabn}[${_i}]}"
        for _arg in "$@"; do
            vescape_spaces _arg
            if eval "case \${_elt} in ${_arg}) true;; *) false;; esac"; then
                vlog 5 "vtab_del: '${_tabn}': removing #${_i} (${_elt}) tabsz=`eval echo "\\\${#${_tabn}[@]}"`"
                vtab_delat "${_tabn}" "${_i}"
                _n=$((_n - 1))
                _i=$((_i - 1))
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
#  Option:   opt_varname != '', arg_varname is array of option args (indexed from 1),
#                               user call vgetopt_shift for each arg used
#  Argument: opt_varname = '',  arg_varnane is single argument
# example:
# while vgetopt opt arg "$@"; do
#        case "$opt" in
#            -h|--help)      show_help 0;;
#            -l|--level)     test ${#arg[@]} -gt 0 || { vlog 1 "missing argument for option '$opt'"; exit 3; }
#                            vlog_setlevel "${arg[1]}"; vgetopt_shift;;
#            -*)             vlog 1 "error: unknown option '$opt'"; show_help 1;;
#            '') case "${arg}" in
#                    *) vlog 1 "error: bad argument '${arg}'"; show_help 2;;
#                esac;;
#        esac
#    done
#
vgetopt() {
    local _optvar="$1" _argvar="$2"; shift; shift
    local _cur _opt _opts _arg _args _i

    if test -z "${VGETOPT_idx}"; then
        VGETOPT_idx=0
        VGETOPT_opts=
        VGETOPT_takeopts=yes
    fi
    test ${VGETOPT_idx} -lt $# && \
    shift ${VGETOPT_idx} || shift $#

    if test -n "${VGETOPT_opts}"; then
        _cur="-${VGETOPT_opts}"
    elif test $# -gt 0; then
        _cur="$1"
        VGETOPT_idx=$((VGETOPT_idx+1))
        if test "${_cur}" = "--"; then
            # TODO : clean this and handle end of arguments
            VGETOPT_takeopts=
            shift
            VGETOPT_idx=$((VGETOPT_idx+1))
            _cur="$1"
        fi
        shift
    else
        unset VGETOPT_idx
        return 1
    fi

    vlog 7 "vgetopt: new call, cur='${_cur}' idx=${VGETOPT_idx} #=$#"

    if test -z "${VGETOPT_takeopts}" || case "${_cur}" in
        -?*) _opts="${_cur#-}"                 # remove heading '-' from current argument
             _opt="${_opts}"; _opts="${_opts#?}"; test -n "${_opt}" -a -z "${_opt##-*}" && _opts= || _opt="${_opt%${_opts}}" # get opt (1 char or -...), :first char in args, shift args by 1 character
             test -n "${_opts}" && { _arg="${_opts}"; VGETOPT_shift=break; } || { _arg="$1"; VGETOPT_shift=shift; }    # prepare argument of opt, user call '$shift' if arg is used.
             _cur="-${_opt}"

             eval "unset ${_argvar}"
             if test -n "${_arg}"; then
                 eval "${_argvar}[1]='${_arg}'"; _i=2; test "${VGETOPT_shift}" = "shift" && shift || true
                 for _arg in "$@"; do eval "${_argvar}[${_i}]='${_arg}'"; _i=$((_i + 1)); done
             fi
             if test -z "${ZSH_VERSION}"; then
                eval "unset ${_argvar}[0]"
             fi
             test ${VLOG_LEVEL} -ge 6 \
             && eval "_args=\"\${${_argvar}[@]}\"" \
             && vlog 6 "vgetopt: OPT '${_cur}' opts='${_opts}' args='${_args}' shift='${VGETOPT_shift}' #=$#"
             false;;
    esac; then
            # argument management
            vlog 6 "vgetopt: ARG '${_cur}' #=$#"
            #_args=${_cur}
            eval "unset ${_argvar}"
            eval "${_argvar}='${_cur}'"
            _cur=
    fi

    eval "${_optvar}=\"${_cur}\""
    #eval "${_argvar}=\"${_args}\""
    VGETOPT_opts="${_opts}"
    return 0
}
# utilities for sh unitary tests
vtest_start() {
    _vtest_ntest=0 _vtest_nko=0 _vtest_nok=0
    unset _vtest_errors
    declare -a _vtest_errors
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
    local _label="$1"; shift
    local _err
    _err="${_label}: test $@"
    vlog 1 -n "${_label} "
    if test "$@"; then
        vtest_ok; return 0
    else
        vtest_fail
        vtab_add _vtest_errors "${_err}"
        test $VLOG_LEVEL -ge 10 && { vlog 1 "press enter..."; read; }
        return 1
    fi
}
vtest_report() {
    local _colorko _err
    if test ${#_vtest_errors[@]} -gt 0; then
        vlog 1 "==================================================================="
        for _err in "${_vtest_errors[@]}"; do vlog 1 "! ${_err}"; done
    fi
    test ${_vtest_nko} -gt 0 && _colorko="${VCOLOR_ko}" || _colorko=""
    vlog 1 "==================================================================="
    vlog 1 "%d tests, %d ${VCOLOR_ok}OK${VCOLOR_rst}, %d ${_colorko}KO${VCOLOR_rst}" ${_vtest_ntest} ${_vtest_nok} ${_vtest_nko}
    test ${_vtest_nko} -gt 0 \
        && vlog 1 "${VCOLOR_ko}FAILED !!!${VCOLOR_rst}" \
        || vlog 1 "${VCOLOR_ok}ALL OK${VCOLOR_rst}"
    vlog 1 "==================================================================="
    return ${_vtest_nko}
}
#vsystem_info() : info about system and shell
vsystem_info() {
    local bi biname
    vlog 1 "%-25s `vutil_version`" "VUTIL_VERSION"
    vlog 1 "%-25s `uname -a`" SYSTEM
    vlog 1 "%-25s ${VCOLOR_ok}${VUTIL_shell}${VCOLOR_rst} ${VUTIL_shellversion}" SHELL
    if test "${VUTIL_shell}" = "ksh"; then
        # with ksh, 'builtin' command checks whether arg is builtin (but fails with 'trap').
        set -- "test" "read" "printf" "cd" "true" "false" "pushd" "popd" "pwd" "which" \
               "kill" "wait" "echo" "trap || { ! which trap && trap; }" "sleep" "dirname" "basename" \
               "[ -n "test" ]" "[[ \"abcd e\" =~ a.*d[[:space:]]e\$ ]]"
    else
        # with other shells (bash,sh,zsh,..), 'builtin' command executes the argument if it is builtin
        set -- "test 1 -eq 1" \
               "read < /dev/null; printf '1\n' | builtin read" \
               "printf -- ''" \
               "cd ." \
               "true" \
               "false ; _test=\$( { builtin false; } 2>&1); test -z \"\${_test}\"" \
               "pushd . > /dev/null" \
               "popd > /dev/null" \
               "pwd > /dev/null" \
               "which \"$SHELL\" > /dev/null" \
               "kill -l > /dev/null" \
               "wait" \
               "echo > /dev/null" \
               "trap" \
               "sleep 0.1" \
               "dirname . > /dev/null" \
               "basename . > /dev/null" \
               "[ -n "test" ]" \
               "[[ \"abcd e\" =~ a.*d[[:space:]]e\$ ]]"
    fi
    for bi in "$@"; do
        biname="${bi%% *}"
        case "$bi" in
            "["*)   eval "{ ${bi} ; }  2> /dev/null";;
            *)      eval "{ builtin ${bi} ; }  2> /dev/null";;
        esac \
        && vlog 1 "%-25s ${VCOLOR_ok}found${VCOLOR_rst}" "builtin-${biname}" \
        || vlog 1 "%-25s ${VCOLOR_ko}not found${VCOLOR_rst}, using `which "${biname}"`" "builtin-${biname}"
    done
    unset read
}
#vyesno
vyesno() {
    local _c=
    if test $# -eq 0; then
        printf -- "continue ? [y/n] "
    else
        printf -- "%s " "$@"; printf -- "[y/n] ";
    fi
    ${VUTIL_read_n1} _c
    printf -- '\n'
    test "${_c}" = "y" -o "${_c}" = "Y"
}
#vreadlink [args] - gnu readlink emulation
vreadlink() {
    local file= arg= newfile= canonical=
    for arg in "$@"; do
        case "$arg" in
            -e|-f) canonical=yes;;
            -*) ;;
            *) file="${arg}"; break;;
        esac
    done
    if test -z "${canonical}"; then
        "${VUTIL_readlink}" "$@"
    else
        test -e "${file}" || return 1
        newfile="${file}"; while newfile=`"${VUTIL_readlink}" "${newfile}"`; do
            case "${newfile}" in /*) ;; *) newfile="`dirname "${file}"`/${newfile}";; esac
            test "${newfile}" = "${file}" && return 1 # check recursive link
            file="${newfile}"
        done
        case "${file}" in /*) ;; "") ;; *) file="`pwd`/${file}";; esac
        echo "${file}"
    fi
}
#vprint_ratio <cur_index> <n_indexes> <start_time_seconds_varname> <prev_ratio_varname>
vprint_ratio() {
    local _starttsp_n="$3" _oldratio_n="$4" _oldratio_v _starttsp_v
    eval "_oldratio_v=\${${_oldratio_n}}; _starttsp_v=\${${_starttsp_n}}; \
          test -z "\${_starttsp_v}" && { _starttsp_v=`date '+%s'`; ${_starttsp_n}=${_starttsp_v}; }"
    test -z "${_oldratio_v}" && _oldratio_v=-1

    local _i_file="$1" _n_files="$2" _ratio _newtsp _eta
    if test -n "${VCOLOR_esc}" -a ${_n_files} -gt 0; then
        _ratio=$(( ((_i_file * 100) / _n_files) ))
        if test ${_ratio} -gt ${_oldratio_v}; then
            _newtsp=`date '+%s'`
            _eta=$(( ((_newtsp - _starttsp_v) * (_n_files - _i_file - 1)) / (_i_file + 1) ))
            vlog 1 -n '\r%21s %-6s ETA %02d:%02d:%02d ' "${_i_file} / ${_n_files}" "[${_ratio}%]" $((_eta / 3600)) $(((_eta % 3600)/60)) $((_eta % 60))
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
VUTIL_setcolors() {
    if test -e "${VLOG_OUT}" && test -t 1 > "${VLOG_OUT}"; then
        VCOLOR_esc='\033['
        VCOLOR_end='m'
        VCOLOR_rst="${VCOLOR_esc}00${VCOLOR_end}"

        VCOLOR_def="${VCOLOR_esc}00;00${VCOLOR_end}"
        VCOLOR_ok="${VCOLOR_esc}00;32${VCOLOR_end}"
        VCOLOR_ko="${VCOLOR_esc}01;31${VCOLOR_end}"
        VCOLOR_kon="${VCOLOR_esc}00;31${VCOLOR_end}"
        VCOLOR_warn="${VCOLOR_esc}00;33${VCOLOR_end}"
        VCOLOR_info="${VCOLOR_esc}00;36${VCOLOR_end}"
        VCOLOR_cmderr="${VCOLOR_esc}00;30${VCOLOR_end}"
        VCOLOR_opt="${VCOLOR_esc}01;33${VCOLOR_end}"
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
}
# Silently init colors according to terminal type
VUTIL_setcolors
# Silently parse command line, looking for log-level option, silently handle it if found.
while vgetopt opt arg "$@"; do
    case "$opt" in -l|--level) test ${#arg[@]} -gt 0 && { vlog_setlevel "${arg[1]}" 2> /dev/null; vgetopt_shift; } || true;; esac
done

############### CRAP ############################################################
vlog 4 "$0: 0='$0' _='${VUTIL_underscore}' @='${VUTIL_arobas}'"
#vutil_sourcing() - tells wheter this script is executed or sourced
vutil_sourcing_bash() {
    local my0
    test -n "$1" && my0="$1" || my0="$0"
  if test -e "${my0}" -a "$my0" = "${BASH_SOURCE[0]}" -a -z "${VUTIL_underscore}"; then
        read -n 1 c < "${my0}" && case "$c" in [[:print:]]) true;; *) false;; esac \
        && { VUTIL_sourcing=0;  VUTIL_exit=return;  return ${VUTIL_sourcing}; } \
        || { VUTIL_sourcing=1;  VUTIL_exit=exit;    return ${VUTIL_sourcing}; }
  else
    test -e "${my0}" -a "$my0" = "${BASH_SOURCE[0]}" && read -n 1 c < "${my0}" && case "$c" in [[:ascii:]]) true;; *) false;; esac \
    && { VUTIL_sourcing=1;  VUTIL_exit=exit;    return ${VUTIL_sourcing}; } \
    || { VUTIL_sourcing=0;  VUTIL_exit=return;  return ${VUTIL_sourcing}; }
  fi
}
vutil_sourcing_ksh() {
    test -n "$1" && my0="$1" || my0="$0"
    if false && test -e "${my0}" -a "${my0}" = "${VUTIL_underscore}"; then
        read -N 1 c < "${my0}" && case "$c" in [[:print:]]) true;; *) false;; esac \
        && { VUTIL_sourcing=0;  VUTIL_exit=return;  return ${VUTIL_sourcing}; } \
        || { VUTIL_sourcing=1;  VUTIL_exit=exit;    return ${VUTIL_sourcing}; }
    else

    test -e "${my0}" -a "${my0}" != "${VUTIL_underscore}" && read -N 1 c < "${my0}" && case "$c" in [[:print:]]) true;; *) false;; esac \
    && { VUTIL_sourcing=1;  VUTIL_exit=exit;    return ${VUTIL_sourcing}; } \
    || { VUTIL_sourcing=0;  VUTIL_exit=return;  return ${VUTIL_sourcing}; }

    fi
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
    my0="${BASH_SOURCE[0]}"; test -z "$my0" && my0="$0"
    mydir="$(dirname "$my0")"; pushd "${mydir}" > /dev/null; mydir="`pwd`"; popd > /dev/null
    myname="$(basename "$my0")"; mypath="${mydir}/${myname}"
}
### END CRAP

#####################################################################################################
# TESTS
#####################################################################################################
if vutil_sourcing "$0" "$underscore"; then
    vlog 4 "$0: SOURCING (shell: ${BASH_VERSION:+bash ${BASH_VERSION}}${KSH_VERSION:+ksh ${KSH_VERSION}}${ZSH_VERSION:+zsh ${ZSH_VERSION}}, @='${VUTIL_arobas}')"
else
    vlog 4 "$0: NOT SOURCING (shell: ${BASH_VERSION:+bash ${BASH_VERSION}}${KSH_VERSION:+ksh ${KSH_VERSION}}${ZSH_VERSION:+zsh ${ZSH_VERSION}}, @='${VUTIL_arobas}')"
    dotests=
    tmp_subshell_log="/tmp/subshell-tests.log"

    show_help() {
        vlog 1 "Usage: `basename "$0"` [-hVIT] [-l <level>]"
        vlog 1 "  -h, --help              show help"
        vlog 1 "  -V, --version           show version"
        vlog 1 "  -l, --level <level>     set log level"
        vlog 1 "  -T, --test              perform unitary tests"
        vlog 1 "  -I, --info              system/shell information"
        exit $1
    }
    while vgetopt opt arg "$@"; do
        case "$opt" in
            -h|--help)      show_help 0;;
            -V|--version)   vlog 1 "`vutil_version`" 2>&1; exit 0;;
            -l|--level)     test ${#arg[@]} -gt 0 || { vlog 1 "${VCOLOR_ko}error${VCOLOR_rst}: missing argument for option '${VCOLOR_opt}${opt}${VCOLOR_rst}'"; exit 3; }
                            vlog_setlevel "${arg[1]}" || exit 4; vgetopt_shift;; # vlog_setlevel already done previously, redo it to print errors
            -T|--test)      dotests=yes;;
            -I|--info)      vsystem_info; exit $?;;
            -*)             vlog 1 "${VCOLOR_ko}error${VCOLOR_rst}: unknown option '${VCOLOR_opt}${opt}${VCOLOR_rst}'"; show_help 1;;
            '') case "${arg}" in
                    *) vlog 1 "${VCOLOR_ko}error${VCOLOR_rst}: bad argument '${VCOLOR_opt}${arg}${VCOLOR_rst}'"; show_help 2;;
                esac;;
        esac
    done

    test -z "${dotests}" && ${VUTIL_exit} 0

    vtest_start

    vlog 1 "\n** SYS INFO **"
    vsystem_info

    vlog 1 "\n** pushd TESTS"
    prev="`pwd`"
    for f in /usr /bin /usr/bin "${HOME}"; do
        pushd "$f" > /dev/null
        vtest_test "pushd $f" "`pwd`" = "${f}"
    done
    popd > /dev/null
    vtest_test "popd -> /usr/bin" "`pwd`" = "/usr/bin"
    pushd "${HOME}"
    vtest_test "pushd $HOME" "`pwd`" = "${HOME}"
    for f in /usr/bin /bin /usr "${prev}"; do
        popd > /dev/null
        vtest_test "popd -> $f" "`pwd`" = "${f}"
    done

    vlog 1 "\n** TAB TESTS **"

    unset tab; declare -a tab;
    ptab() {
        vlog 2 "tab #=${#tab[@]}"
        local e i=1
        for e in "${tab[@]}"; do
            vlog 2 "#$i '$e'"; i=$((i+1))
        done
        vlog 2
    }
    vtab_add tab 1
    vtab_add tab 2
    vtab_add tab 3
    vtab_add tab 4
    vtab_add tab 5 "6 six" 7 4 "8 eight"
    ptab

    vlog 2 "TAB FIND 6*:"
    vtab_find tab "6*" idx && vtest_ok "->found #$idx '${tab[$idx]}'" || vtest_fail "!! NOT FOUND"
    vlog 2 "TAB find 4:"
    idx=0; while vtab_find tab 4 idx $((idx+1)); do
        vlog 1 " ->found #$idx '${tab[$idx]}'"
    done
    vlog 2 "TAB FIND abc:"
    vtab_find tab abc && vtest_fail "!! -> found !" || vtest_ok "-> not found"
    vlog 2 "TAB FIND 8 eight:"
    vtab_find tab "8 eight" && vtest_ok "-> found !" || vtest_fail "!! -> not found"
    vlog 2 "TAB FIND '[0-9] *"
    vtab_find tab "[0-9] *" && vtest_ok "-> found !" || vtest_fail "!! -> not found"

    vlog 2 "TAB DEL 2:"
    sz=${#tab[@]}
    vtab_del tab "2"
    vtest_test "retval/arraysz" $? -eq 0 -a ${#tab[@]} -eq $((sz - 1))
    vtab_find tab 2
    vtest_test "2 deleted" $? -ne 0
    ptab

    vlog 2 "TAB DEL 1:"
    sz=${#tab[@]}
    vtab_del tab 1
    vtest_test "retval/arraysz" $? -eq 0 -a ${#tab[@]} -eq $((sz - 1))
    vtab_find tab 1
    vtest_test "1 deleted" $? -ne 0
    ptab

    vlog 2 "TAB DEL NOT FOUND:"
    sz=${#tab[@]}
    vtab_del tab "ELEMENT NOT FOUND"
    vtest_test "retval/arraysz" $? -ne 0 -a ${#tab[@]} -eq $sz
    ptab

    vlog 2 "TAB DEL 8:"
    sz=${#tab[@]}
    vtab_del tab "8*"
    vtest_test "retval/arraysz" $? -eq 0 -a ${#tab[@]} -eq $((sz - 1))
    sz=$((sz - 1))
    vtab_find tab "8*"
    vtest_test "8* deleted" $? -ne 0
    ptab
    vtab_delat tab 0
    vtest_test "delat 0: ret 1 & sz unchanged" $? -ne 0 -a ${#tab[@]} -eq $sz
    vtab_delat tab $((sz+1))
    vtest_test "delat sz_1 ret 1 & sz unchanged" $? -ne 0 -a ${#tab[@]} -eq $sz

    vlog 2 "TAB DEL ALL:"
    vtab_del tab "*"
    vtest_test "retval" $? -eq 0
    vtab_find tab "*"
    vtest_test "* deleted" $? -ne 0
    vtest_test "array empty" ${#tab[@]} -eq 0
    ptab
    vtab_delat tab 0
    vtest_test "delat 0: ret 1 & array empty" $? -ne 0 -a ${#tab[@]} -eq 0
    vtab_delat tab 1
    vtest_test "delat 1: ret 1 & array empty" $? -ne 0 -a ${#tab[@]} -eq 0

    #vtab_pop
    vtab_add tab "push1"
    vtab_add tab "push2"
    vtab_pop tab poped
    vtest_test "arraysz 1, poped=push2" $? -eq 0 -a ${#tab[@]} -eq 1 -a "${poped}" = "push2"
    vtab_pop tab poped
    vtest_test "arraysz 0, poped=push1" $? -eq 0 -a ${#tab[@]} -eq 0 -a "${poped}" = "push1"

    #vtab_pop0
    vtab_add tab "push1"
    vtab_add tab "push2"
    vtab_pop0 tab poped
    vtest_test "arraysz 1, poped0=push1" $? -eq 0 -a ${#tab[@]} -eq 1 -a "${poped}" = "push1"
    vtab_pop0 tab poped
    vtest_test "arraysz 0, poped0=push2" $? -eq 0 -a ${#tab[@]} -eq 0 -a "${poped}" = "push2"

    #spaces tests
    vtab_add tab "1 space 1 "
    vtab_add tab "2 space 2 "
    vtab_add tab "3 space 3 "
    vtab_add tab "0 \"space_dquote 0\" "
    vtab_add tab "0 \"space_backslash\\ 0\" "
    vtab_add tab "0 \"space_backslash_N\\\n 0\" "
    vtab_add tab "0 'space_squote 0' "
    vtab_add tab "4 space 4 "
    sz=${#tab[@]}
    vtab_del tab "3 space 3"
    vtest_test "ret val!=0 arraysz unchanged" $? -ne 0 -a ${#tab[@]} -eq $sz
    vtab_del tab "3 space 3 " "4 space 4 "
    vtest_test "ret val=0 arraysz-=2" $? -eq 0 -a ${#tab[@]} -eq $((sz - 2))
    sz=$((sz - 2))
    vtab_find tab "[34]*"
    vtest_test "find '[34]*' not found" $? -ne 0
    i=0; idx=0; while vtab_find tab "[12]*" idx $((idx+1)); do i=$((i+1)); done
    vtest_test "find '[12]*' 2 results" $i -eq 2

    #################################################################################
    # check add/pop/del with quotes or special characters
    #################################################################################
    #for s in "0 \"space_dquote 0\" " "0 \"space_backslash\\ 0\" " "0 \"space_backslash_N\\\n 0\" " "0 'space_squote 0' " ; do
    for s in "0 \"space_dquote 0\" " "0 'space_squote 0' " ; do
        vtab_find tab "${s}"
        vtest_test "find '${s}' 1 result" $? -eq 0
        vtab_del tab "${s}"
        vtest_test "del '${s}' ok arraysz-=1" $? -eq 0 -a ${#tab[@]} -eq $((sz-1)) && sz=$((sz-1))

        vtab_add tab "${s}"
        vtab_pop tab elt
        vtest_test "pop '${s}' ok arraysz-=1" $? -eq 0 -a ${#tab[@]} -eq $sz -a "${elt}" = "${s}"
        vtab_add tab "${s}"
        first=${tab[1]}
        vtab_pop0 tab elt
        vtest_test "pop0 '${s}' ok arraysz-=1" $? -eq 0 -a ${#tab[@]} -eq $sz -a "${elt}" = "${first}"
    done

    #################################################################################
    # check if the sourcing detection is ok
    #################################################################################
    for exe in "${SHELL}" ""; do
        if test -n "${exe}"; then ret=`"${exe}" "$0"`; else ret=`"$0"`; fi
        vtest_test "$exe $0> expected:'', ret:'${ret}'" $? -eq 0 -a -z "${ret}"

        if test -n "${exe}"; then ret=`"${exe}" "$0" -V`; else ret=`"$0" -V`; fi
        vtest_test "$exe $0 -V> expected:0,'`vutil_version`', got:$?,'${ret}'" $? -eq 0 -a "${ret}" = "`vutil_version`"

        if test -n "$exe"; then
            ret=`${SHELL} -c "VUTIL_sourcing=12345; . $0 ; echo ok; test \"\\\${VUTIL_sourcing}\" = \"0\""`
        else
            ret=`( VUTIL_sourcing=12345; . $0 ; echo ok; test "\${VUTIL_sourcing}" = "0" )`
        fi
        vtest_test "${exe:+${exe} -c }\". $0\" expected:0,'ok' got:$?,'${ret}'" $? -eq 0 -a "${ret}" = "ok"

        if test -n "$exe"; then
            ret=`${SHELL} -c "VUTIL_sourcing=12345; . $0 -V; echo ok; test \"\\\${VUTIL_sourcing}\" = \"0\""`
        else
            ret=`( VUTIL_sourcing=12345; . $0 -V; echo ok; test "\${VUTIL_sourcing}" = "0" )`
        fi
        vtest_test "${exe:+${exe} -c }\". $0 -V\" expected:0,'ok' got:$?,'${ret}'" $? -eq 0 -a "${ret}" = "ok"

    done

    #################################################################################
    # test script sourcing this one, and which is using vgetopt
    #################################################################################
    tmpscript="`mktemp "vutil_test_XXXXXX"`"
    test -n "${tmpscript}" || tmpscript="vutil_test_tmp"
    tmpscript="`pwd`/${tmpscript}"

    cat << EOFTMP1 > "${tmpscript}"
#!${SHELL}
. "${VUTIL_0}"
#vlog_setlevel 10
while vgetopt opt arg "\$@"; do
    case "\${opt}" in
        -V) echo "vutil_test 0.0";;
        -P) printf "vutil_test args"; for a in "\${arg[@]}"; do
                printf -- " <\${a}>"; vgetopt_shift
            done; echo;;
        -*) echo "wrong opt '\${opt}'";;
        *)  printf -- "%s" "wrong arg '" "\${arg}" "'\n";;
    esac
done
EOFTMP1
    chmod +x "${tmpscript}"

    expected="vutil_test 0.0"
    ret="`"${tmpscript}" -V`"
    vtest_test "tmpscript version '$ret =? ${expected}'" "${ret}" = "${expected}"
    for args in "A argWithSpace" "arg1 arg2 arg3 space arg4"; do
        expected="vutil_test args"
        for e in $args; do
            expected="${expected} <${e}>"
        done
        ret="`"${tmpscript}" -P ${args}`"
        vtest_test "tmpscript print args '${ret} =? ${expected}'" "${ret}" = "${expected}"
        ret="`"${tmpscript}" -P${args}`"
        vtest_test "tmpscript print args2 '${ret} =? ${expected}'" "${ret}" = "${expected}"
    done

    if test $? -ne 0 -a $VLOG_LEVEL -gt 5; then
        echo "--------------------"
        cat "${tmpscript}"
        rm -f "${tmpscript}"
        echo "press enter"
        read
    else
        rm -f "${tmpscript}"
    fi

    #################################################################################
    # run tests with available shells
    #################################################################################
    if test -z "${VUTIL_SHLVL_OLD}"; then
        SHELL_bak="${SHELL}"
        export VUTIL_SHLVL_OLD="${SHLVL}"
        for sh in `which -a sh bash ksh zsh /{usr,opt}/local/bin/{bash,zsh,sh,ksh} | sort | uniq`; do
            test -x "${sh}" || continue
            export SHELL="${sh}"
            "$sh" "$0" "$@"
            vtest_test "$sh tests" $? -eq 0
            vlog 1 "-----------------------------------------------------------"
            if test -e "/tmp/subshell-tests.log"; then
                vtab_add subshell_report "${SHELL}: `grep -E '^[0-9][0-9]* tests, [0-9][0-9] ' "${tmp_subshell_log}"`"
                rm -f "${tmp_subshell_log}"
            fi
        done
        export SHELL="${SHELL_bak}"
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

    test ${#subshell_report[@]} -gt 0 && vlog 1 "sub-shells summary:"
    for sub in "${subshell_report[@]}"; do
        vlog 1 "  ${sub}"
    done

    vtest_report

    if test -n "${VUTIL_SHLVL_OLD}"; then
        vtest_report > "${tmp_subshell_log}" 2>&1
    fi
fi
