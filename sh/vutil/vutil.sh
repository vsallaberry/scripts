#!/bin/sh
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
# --------------------------------------------------------------------
# sh utilities, bash or zsh recommanded, shell (type bourne) must
# have at least arrays (a[1]=1, ${a[@]} ${#a[@]}), subsitutions
# (${var%..}, ${var%%..}, ${var#..}, ${var##..})
# --------------------------------------------------------------------
# TODO
# ====
# * TODO: vgetopt : clean '--' handling
# * TODO: vreadlink and vprint_ratio not tested
#
##
VUTIL_underscore="$_"
VUTIL_underscore_old="$_"
VUTIL_arobas="$@"
VUTIL_0="$0"

###################################################################
#vutil_version()
vutil_version() {
    echo "0.5.5 Copyright (C) 2020 Vincent Sallaberry / GNU GPL licence"
}
# test wrapper to force use of builtin / not needed
#test() {
#    [ "$@" ]
#}
###################################################################
# Shell Specific Stuff
###################################################################
VUTIL_read_n1=false
if test -n "${KSH_VERSION}"; then
    VUTIL_shell=ksh
    VUTIL_shellversion="${KSH_VERSION}"
    VUTIL_underscore="${VUTIL_underscore#\*[0-9]*\*}"
    VUTIL_underscore="${VUTIL_underscore%%:*}"
    local i 2> /dev/null || local() { for __arg in "$@"; do case "${__arg}" in -*) ;; *=*) eval "${__arg%%=*}=\${__arg#*=}";; esac; done; }
    declare > /dev/null 2>&1 || declare() { for __arg in "$@"; do case "${__arg}" in -*) ;; *=*) eval "${__arg%%=*}=\${__arg#*=}";; esac; done; }
    vutil_sourcing_custom() { vutil_sourcing_ksh "$@"; }
elif test -n "${ZSH_VERSION}"; then
    VUTIL_shell=zsh
    VUTIL_shellversion="${ZSH_VERSION}"
    vutil_sourcing_custom() { vutil_sourcing_zsh "$@"; }
    VUTIL_read_n1_fun() { read -u 0 -k 1 "$@"; }
    VUTIL_read_n1=VUTIL_read_n1_fun
elif test -n "${BASH_VERSION}"; then
    VUTIL_shell=bash; VUTIL_shellversion="${BASH_VERSION}"
    vutil_sourcing_custom() { vutil_sourcing_bash "$@"; }
    VUTIL_read_n1="read -n 1"
else
    VUTIL_shell=unknown_sh; VUTIL_shellversion="${SH_VERSION:-unknown}"
    vutil_sourcing_custom() { vutil_sourcing_ksh "$@"; }
    VUTIL_underscore="${VUTIL_underscore#\*[0-9]*\*}"
    VUTIL_underscore="${VUTIL_underscore%%:*}"
fi
# local wrapper if not existing
( _fun() { local i 2> /dev/null; }; _fun; ) \
|| local() { for __arg in "$@"; do case "${__arg}" in -*) ;; *=*) eval "${__arg%%=*}=\${__arg#*=}";; esac; done; }
# declare wrapper if not existing
( declare -a array; ) > /dev/null 2>&1 \
|| declare() { for __arg in "$@"; do case "${__arg}" in -*) ;; *=*) eval "${__arg%%=*}=\${__arg#*=}";; esac; done; }
# read -n 1 wrapper if not supported
c=; if ! echo "ab" | ${VUTIL_read_n1} c 2> /dev/null || test "$c" != "a"; then
    VUTIL_read_n1="__read_n1"
    __read_n1() {
        _tty_sav=`stty -g 2> /dev/null`
        stty raw 2> /dev/null
        ___c_=`dd if=/dev/stdin of=/dev/stdout count=1 bs=1 2> /dev/null`
        stty "${_tty_sav}" 2> /dev/null
        eval "$1=\${___c_}"
    }
fi
# pushd / popd wrapper if not supported
if pushd . >/dev/null 2>&1 && popd >/dev/null 2>&1; then
    true
else
    pushd() {
       vtab_add VUTIL_ksh_pushd "`pwd`"
        cd "$@"
    }
    popd() {
        local _prev
        vtab_pop VUTIL_ksh_pushd _prev
        cd "${_prev}"
    }
fi
# printf wrapper to speedup display # TODO NOT FINISHED
VUTIL_has_colors=yes
( builtin print ) > /dev/null 2>&1 && test "`print -n v`" = "v" && _vutil_has_print=yes || _vutil_has_print=
if ( builtin echo ) > /dev/null 2>&1; then
    test "`echo -n v`" = "v" && _vutil_has_echo=yes || _vutil_has_echo=
    test "`echo -n -e v`" = "v" && _vutil_has_echo_e= || _vutil_has_echo_e= # echo -e don't print colors
fi
if { true || ( builtin printf ) > /dev/null 2>&1 || ( builtin printf -- '' ) > /dev/null 2>&1 \
|| test -z "${_vutil_has_print}${_vutil_has_echo}"; }; then
    VUTIL_printf=printf
    VUTIL_printf_args1="--"
    VUTIL_printf_args2=
    VUTIL_printf_args3="\n"
else
    if test -n "${_vutil_has_print}"; then
        VUTIL_printf=print
    else
        VUTIL_printf=echo
        test -n "${_vutil_has_echo_e}" && VUTIL_args2="-e" || { VUTIL_args2=; VUTIL_has_colors=; }
    fi
    VUTIL_printf_args1="-n"
    VUTIL_printf_args3=""
fi
unset _vutil_has_print
unset _vutil_has_echo
unset _vutil_has_echo_e
###################################################################
# vutil functions
###################################################################
#vlog_setlevel <loglevel>
vlog_setlevel() {
    local arg="$1"
    local _file="${arg#*@}"
    if test "${_file}" \!= "${arg}" -a -n "${_file}"; then
        arg="${arg%%@*}"
        vlog_setout "${_file}" || return 1
    fi
    local _test_arg="${arg#-}"
    { ret=false; while test -n "${_test_arg}"; do _rem=${_test_arg#?}; _c=${_test_arg%${_rem}}; _test_arg=${_rem}
      case "${_c}" in [0-9]) ret=true;; *) ret=false; break;; esac; done; $ret; } \
    && { test ${VLOG_LEVEL} -ge 5 -o ${arg} -ge 5 && vlog 0 "vlog_setlevel: new level ${arg} @${VLOG_OUT}"; VLOG_LEVEL="${arg}"; } \
    || { vlog 0 "!! vlog_setlevel: ${VCOLOR_ko}error${VCOLOR_rst}: bad level '${VCOLOR_opt}${arg}${VCOLOR_rst}'"; return 1; }
}
#vlog_setout <file>
vlog_setout() {
    local _file="$1"
    case "${_file}" in /*) ;; *) _file="`pwd`/${_file}";; esac
    local _dir="`dirname "${_file}"`"
    test -w "${_file}" -o -w "${_dir}" \
    && VLOG_OUT="${_file}" && VUTIL_setcolors \
    || { vlog 0 "!! vlog_setout: ${VCOLOR_ko}error${VCOLOR_rst}: bad file '${VCOLOR_opt}${_file}${VCOLOR_rst}'"; return 1; }
}
#vlog <level> [-n] [<printf_args>]
vlog() {
    local _level="$1" _eol
    if test ${VLOG_LEVEL} -ge ${_level}; then
        shift
        test "$1" = "-n" && { _eol=''; shift; } || _eol='\n'
        test $# -gt 0 && ${VUTIL_printf} ${VUTIL_printf_args1} ${VUTIL_printf_args2} "$@" >> "${VLOG_OUT}"
        test -n "${_eol}" && ${VUTIL_printf} ${VUTIL_printf_args3} >> "${VLOG_OUT}"
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
    _i=${_startidx}
    while test ${_i} -le ${_n}; do
        eval "_elt=\${${_tabn}[${_i}]}"
        if eval "case \${_elt} in ${_find}) true;; *) false;; esac"; then
            test -n "${_idxn}" && eval "${_idxn}=${_i}"
            return 0
        fi
        _i=$((_i + 1))
    done
    return 1
}
#vtab_delat <array_name> <idx>
#!! array index starts at 1 for zsh compatibility
vtab_delat() {
    local _tabn="$1" _idx="$2" _n _j
    eval "_n=\${#${_tabn}[@]}"
    test ${_idx} -le "${_n}" -a ${_idx} -gt 0 || return 1
    _j=$((_idx + 1))
    while test ${_j} -le ${_n}; do
        eval "${_tabn}[$((_j - 1))]=\${${_tabn}[${_j}]}"
        _j=$((_j + 1))
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
    _i=1
    while test ${_i} -le ${_n}; do
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
        _i=$((_i + 1))
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
    local bi biname _builtin
    vlog 1 "%-25s `vutil_version`" "VUTIL_VERSION"
    vlog 1 "%-25s `uname -a`" SYSTEM
    vlog 1 "%-25s ${VCOLOR_ok}${VUTIL_shell}${VCOLOR_rst} ${VUTIL_shellversion}" SHELL
    if ( builtin builtin > /dev/null 2>&1 && { builtin false > /dev/null 2>&1 || builtin test > /dev/null 2>&1; }; ); then
        # with ksh, 'builtin' command checks whether arg is builtin (but fails with 'trap').
        set -- "builtin" "test" "read" "printf" "print" "cd" "true" "false" "pushd" "popd" "pwd" "which" \
               "kill" "wait" "echo" "trap || { ! which trap && trap; }" "sleep" "dirname" "basename" \
               "[ -n "test" ]" "[[ \"abcd e\" =~ a.*d[[:space:]]e\$ ]]"
    else
        # with other shells (bash,sh,zsh,..), 'builtin' command executes the argument if it is builtin
        set -- "builtin" \
               "test 1 -eq 1" \
               "read < /dev/null; printf '1\n' | builtin read" \
               "printf -- ''" \
               "print" \
               "cd ." \
               "true" \
               "false ; _test=\$( { builtin false; } 2>&1); test -z \"\${_test}\"" \
               "pushd . > /dev/null" \
               "popd > /dev/null; pushd . > /dev/null 2>&1; popd > /dev/null" \
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
    _builtin=builtin
    for bi in "$@"; do
        biname="${bi%% *}"
        case "$bi" in
            "["*)   ( eval "${bi}" ; )  2> /dev/null;;
            *)      ( eval "${_builtin} ${bi}"; )  2> /dev/null || {
                        test "${biname}" = builtin && _builtin="PATH=; "; false; };;
        esac \
        && vlog 1 "%-25s ${VCOLOR_ok}found${VCOLOR_rst}" "builtin-${biname}" \
        || vlog 1 "%-25s ${VCOLOR_ko}not found${VCOLOR_rst}, using `which "${biname}" 2> /dev/null || true`" "builtin-${biname}"
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
    local _file
    test -n "$1" && _file=$1 || _file=${VLOG_OUT}
    if test -n "${VUTIL_has_colors}" -a -e "${_file}" && test -t 1 >> "${_file}"; then
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
vlog 4 "${VUTIL_0}: 0='${VUTIL_0}' _='${VUTIL_underscore}' @='${VUTIL_arobas}' old_='${VUTIL_underscore_old}' SHLVL=$SHLVL old_SHLVL=$VUTIL_SHLVL_OLD SHELL=$SHELL old_SHELL=$VUTIL_SHELL_OLD PID=$$ PPID=$PPID"
#vutil_sourcing() - tells wheter this script is executed or sourced
vutil_sourcing_bash() {
    local _c _src=0 _my0=$1 _my_=$2 _text_char=[[:print:]] #//"[\x00-\x7f]"
    if test -e "${_my0}" -a "${_my0}" = "${BASH_SOURCE[0]}" -a -z "${_my_}"; then
        read -n 1 _c < "${_my0}" && case "${_c}" in ${_text_char}) true;; *) false;; esac \
        && _src=1 || _src=0
    else
        test -e "${_my0}" -a "${_my0}" = "${BASH_SOURCE[0]}" && read -n 1 _c < "${_my0}" && case "${_c}" in ${_text_char}) true;; *) false;; esac \
        && _src=0 || _src=1
    fi
    return ${_src}
}
vutil_sourcing_ksh() {
    test "$VLOG_LEVEL" -ge 10 && set -x
    local _src=0 _my0=$1 _my_=$2 _my_old=$4 _c _text_char

    case '\xcf' in [[:print:]]|*) pr_pat='[#\x00\x7f]';; *) pr_pat='[[:print:]#]';; esac
    test -e "${_my0}" || { _my0=${_my0#-}; which "${_my0}" >/dev/null 2>&1 && _my0=`which "${_my0}"`; }

    if test -x "${_my_}"; then
        _c="\xcf"; _c="`dd if="${_my_}" of=/dev/stdout count=1 bs=1 2> /dev/null`"
        if eval "case \${_c} in ${pr_pat}) true;; *) false;; esac"; then
            test \! -e "${_my0}" -a "${_my0}" != "${_my_}" && _src=1
            #test -e "${_my_}" && { test "${_my_}" != "${_my_old}" -a "${_my_}" = "${_my_old#\*[0-9]*\*}"  && _src=1; }

            test -e "${_my0}" && _c=`dd if="${_my0}" of=/dev/stdout count=1 bs=1 2> /dev/null` \
                && eval "case \${_c} in ${pr_pat}) true;; *) false;; esac" && test -z "${VUTIL_SHLVL_OLD}" && _src=1
        else
            test -e "${_my0}" && _c=`dd if="${_my0}" of=/dev/stdout count=1 bs=1 2> /dev/null` \
                && { eval "case \${_c} in ${pr_pat}) false;; *) true;; esac" && _src=1; }

            test -z "${VUTIL_SHLVL_OLD}" && _src=0
        fi
    fi

    test -n "${SHLVL}" -a -n "${VUTIL_SHLVL_OLD}" && { test ${VUTIL_SHLVL_OLD} = $((SHLVL)) && _src=1; } # || _src=0; }
    #test -z "${VUTIL_SHLVL_OLD}" && _src=0

    return ${_src}
}
vutil_sourcing_zsh() {
    local _my0=$1 _my_=$2 _my_arobas=$3
    test    \( -z "${_my_}" -o \! -x "${_my_}" \) \
         -a \( -z "${_my_}" -o "${_my_}" \!= "${_my_arobas}" \) \
    && return 0 || return 1
}
#vutil_sourcing
vutil_sourcing() {
    local _my0 _my_ _my_arobas _my_old _src
    test -n "$1" && _my0="$1" || _my0="${VUTIL_0}"
    test -n "$2" && _my_="$2" || _my_="${VUTIL_underscore}"
    test -n "$3" && _my_arobas="$3" || _my_arobas="${VUTIL_arobas}"
    test -n "$4" && _my_old="$4" || _my_old="${VUTIL_underscore_old}"

    test "$VLOG_LEVEL" -ge 10 && set -x

    _src=0
    #test -n "${SHLVL}" -a "${VUTIL_SHLVL_OLD}" != "${SHLVL}" && _src=0

    ### SPECIFIC BEGIN
    vutil_sourcing_custom "${_my0}" "${_my_}" "${_my_arobas}" "${_my_old}" && _src=0 || _src=1
    ### SPECIFIC END

    #if test -z "$BASH_VERSION" -a -z "$ZSH_VERSION"; then
    #    test -n "${SHLVL}" -a -n "${VUTIL_SHLVL_OLD}" && { test ${VUTIL_SHLVL_OLD} = $((SHLVL)) && _src=1; } # || _src=0; }
    #    test -z "${VUTIL_SHLVL_OLD}" && _src=0
    #fi

    export VUTIL_SHLVL_OLD="${SHLVL:-1}"
    export VUTIL_SHELL_OLD="${SHELL}"

    test "$VLOG_LEVEL" -ge 10 && set +x

    test ${_src} -eq 0 \
    && { VUTIL_sourcing=1;  VUTIL_exit=exit;    return ${VUTIL_sourcing}; } \
    || { VUTIL_sourcing=0;  VUTIL_exit=return;  return ${VUTIL_sourcing}; }
}
#vutil_myname()
vutil_myname() {
    local my0 mydir myname mypath
    my0="${BASH_SOURCE[0]}"; test -z "$my0" && my0="${VUTIL_0}"
    mydir="$(dirname "$my0")"; pushd "${mydir}" > /dev/null; mydir="`pwd`"; popd > /dev/null
    myname="$(basename "$my0")"; mypath="${mydir}/${myname}"
}
### END CRAP

#####################################################################################################
# TESTS
#####################################################################################################
if vutil_sourcing "${VUTIL_0}" "${VUTIL_underscore}" "${VUTIL_arobas}" "${VUTIL_underscore_old}"; then
    vlog 4 "${VUTIL_0}: SOURCING (shell: ${BASH_VERSION:+bash ${BASH_VERSION}}${KSH_VERSION:+ksh ${KSH_VERSION}}${ZSH_VERSION:+zsh ${ZSH_VERSION}}, @='${VUTIL_arobas}')"
else
    vlog 4 "${VUTIL_0}: NOT SOURCING (shell: ${BASH_VERSION:+bash ${BASH_VERSION}}${KSH_VERSION:+ksh ${KSH_VERSION}}${ZSH_VERSION:+zsh ${ZSH_VERSION}}, @='${VUTIL_arobas}')"
    dotests=

    show_help() {
        vlog 1 "Usage: `basename "${VUTIL_0}"` [-hVIT] [-l <level>]"
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

    # exit if tests not requested
    test -z "${dotests}" && ${VUTIL_exit} 0

    # Prevent test recursion if not expected explicitly by tests
    test -n "${dotests}" && test -n "${VUTIL_TESTS_NO_TEST_RECURSION}" && { vlog 0 "ERROR, TESTS recursion unexpected"; exit 1; }
    export VUTIL_TESTS_NO_TEST_RECURSION=yes

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
    pushd "${HOME}" > /dev/null
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
    test $VLOG_LEVEL -ge 10 && debug=" -l10" || debug=
    for exe in "${SHELL}" ""; do
        if test -n "${exe}"; then ret=`"${exe}" "${VUTIL_0}" ${debug}`; else ret=`"${VUTIL_0}"${debug}`; fi
        vtest_test "$exe ${VUTIL_0}> expected:'', ret:'${ret}'" $? -eq 0 -a -z "${ret}"

        if test -n "${exe}"; then ret=`"${exe}" "${VUTIL_0}" ${debug} -V`; else ret=`"${VUTIL_0}"${debug} -V`; fi
        vtest_test "$exe ${VUTIL_0} -V> expected:0,'`vutil_version`', got:$?,'${ret}'" $? -eq 0 -a "${ret}" = "`vutil_version`"

        if test -n "$exe"; then
            ret=`${SHELL} -c "VUTIL_sourcing=12345; . ${VUTIL_0} ${debug}; echo ok; test \"\\\${VUTIL_sourcing}\" = \"0\""`
        else
            ret=`( VUTIL_sourcing=12345; . ${VUTIL_0} ${debug}; echo ok; test "\${VUTIL_sourcing}" = "0" )`
        fi
        vtest_test "${exe:+${exe} -c }\". ${VUTIL_0}\" expected:0,'ok' got:$?,'${ret}'" $? -eq 0 -a "${ret}" = "ok"

        if test -n "$exe"; then
            ret=`${SHELL} -c "VUTIL_sourcing=12345; . ${VUTIL_0} ${debug} -V; echo ok; test \"\\\${VUTIL_sourcing}\" = \"0\""`
        else
            ret=`( VUTIL_sourcing=12345; . ${VUTIL_0} ${debug} -V; echo ok; test "\${VUTIL_sourcing}" = "0" )`
        fi
        vtest_test "${exe:+${exe} -c }\". ${VUTIL_0} -V\" expected:0,'ok' got:$?,'${ret}'" $? -eq 0 -a "${ret}" = "ok"

    done

    #################################################################################
    # test script sourcing this one, and which is using vgetopt
    #################################################################################
    tmpscript="`mktemp "vutil_test_XXXXXX"`"
    test -n "${tmpscript}" || tmpscript="vutil_test_tmp"
    tmpscript="`pwd`/${tmpscript}"
    # reset VUTIL_SHLVL_OLD to simulate clean environment before calling test script
    vutil_shlvl_backup=${VUTIL_SHLVL_OLD}
    unset VUTIL_SHLVL_OLD

    cat << EOFTMP1 > "${tmpscript}"
#!${SHELL}
. "${VUTIL_0}" ${debug}
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

    export VUTIL_SHLVL_OLD=${vutil_shlvl_backup}

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
    if test -z "${VUTIL_TEST_MAIN_SCRIPT}"; then
        unset VUTIL_TESTS_NO_TEST_RECURSION
        SHELL_bak="${SHELL}"
        export VUTIL_TEST_MAIN_SCRIPT="${SHLVL}"
        export VUTIL_tmp_subshell_log="`mktemp "/tmp/vutil_subshell.log.XXXXXX"`"
        for sh in `which -a sh bash ksh zsh /{usr,opt}/local/bin/{bash,zsh,sh,ksh} | sort | uniq`; do
            test -x "${sh}" || continue
            rm -f "${VUTIL_tmp_subshell_log}"
            export SHELL="${sh}"

            "$sh" "${VUTIL_0}" "$@"
            vtest_test "$sh tests" $? -eq 0
            vlog 1 "-----------------------------------------------------------"

            if test -e "${VUTIL_tmp_subshell_log}"; then
                vtab_add subshell_report "${SHELL}: `grep -E '^[0-9][0-9]* tests, [0-9][0-9] ' "${VUTIL_tmp_subshell_log}"`"
                rm -f "${VUTIL_tmp_subshell_log}"
            fi
        done
        rm -f "${VUTIL_tmp_subshell_log}"
        export SHELL="${SHELL_bak}"
        export VUTIL_TESTS_NO_TEST_RECURSION=yes
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

    if test -n "${VUTIL_TEST_MAIN_SCRIPT}"; then
        vlog_level_bak=${VLOG_LEVEL}
        vlog_out_bak=${VLOG_OUT}
        vlog_setlevel 2@/dev/stderr > /dev/null 2>&1

        vtest_report > "${VUTIL_tmp_subshell_log}" 2>&1

        vlog_setlevel "${vlog_level_bak}@${vlog_out_bak}" > /dev/null 2>&1
    fi
    ${VUTIL_exit} ${_vtest_nko}
fi
