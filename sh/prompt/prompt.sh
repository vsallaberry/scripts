#!/bin/sh
# --
# Copyright (C) 2017-2019 Vincent Sallaberry
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
# Written on OpenBSD 5.5 ksh, from version 0 to this one,
# with the goals of having a decent dynamic colored _FAST_ SH prompt and term title on
# my openbsd in which the security features and the VM make it slower than others,
# and of sharing the same prompt init script on my different machines and shells.
#
# For ksh, bash, zsh, or sh supporting $(command) and \033 in
# PS1 variable and supporting either the PS1 escape \[escape\]from bash,
# or the "%{%}" from zsh or the \a\r...\aEscape\a Hack from ksh.
# Error status, number of jobs and git branch are only displayed if not null.
# Additionnaly to displaying the prompt, the terminal title is updated according to
# context (pwd,user,...), if supported.
#
# Some OPTIONAL input variables can be defined before sourcing this script:
#   ps1ShType <type>   : bash | zsh | kshhack | sh | kshhack2.
#                        Auto detect by default but can be overriden whatever the shell.
#                        If you have troubles with cursor in ksh, while COLUMN variable
#                        is correct, try values kshhack, kshhack2, bash.
#                        If your sh handles PS1 command substitution $(cmd), try
#                        kshhack*,bash, with ps1Colors=0 or =8.
#
#   ps1Colors=<nb>     : force enable/disable color usage - <nb> colors.
#                           <nb> must be >=8 to enable colors
#
#   ps1Color<item><scope>=<color>
#                      : color of <item> for <scope>, excluding item 'Title'.
#
#   ps1<item>On        : 0: force disable <item> (excluding 'Dash'). 1: force enable.
#                        For ps1DateOn: 1: add 24h time, 2: add week day and 24h time.
#                        For ps1PwdOn : 1: enable Pwd without truncation,
#                                       2: keep first and last (<First>...<Last>),
#                                       3: keep 2 firsts and 2 lasts.
#
#   ps1PrintVersion 1  : print prompt version, then use '$ unset ps1PrintVersion'
#
# <item>    :  Date | Err | Job | User | Host | Pwd | Git | Shell | Dash | Title
#
# <color>   : "<style>;<color_code>". Eg: "01;31" for bold red.
#
# <scope>   : '' | Wheel | Root | User
#             scope of current setting, can be '':
#               * '' (empty)     : the value is default for all undefined scopes.
#                                  A value for a specfic scope will have priority.
#               * Root,Wheel,User: value for Root, member of wheel, or other users.
#
# At the end of the scripts, all variables including inputs are unset.
#
ps1Version="5.0.4"
ps1Items="Date Err Job User Host Pwd Git Shell Dash Title"

# Interactive shell only
if [ -z "$PS1" ]; then
   return
fi

# Clean some variables
unset PROMPT_COMMAND

# Choose print for display, fallback on printf (slower)
if builtin print 2>&1 >/dev/null 2>&1; then
    ps1Print=print
    ps1PrintLF=
else
    if builtin printf '' 2>&1 >/dev/null 2>&1; then
        ps1Print=printf
    else
        ps1Print="$(which printf)"
    fi
    ps1PrintLF='\n'
fi
# Configure other commands
ps1GitBin=$(which git 2> /dev/null)
ps1WcBin=$(which wc 2> /dev/null)

# Try to guess Shell capabilities (\[ \], \A, \w)
# ps1ShType can be overriden before calling this script.
if test -n "${KSH_VERSION}" ; then
    ps1Shell=ksh
    if $(set -o sh -o emacs-usemeta -o csh-history 2>&1 >/dev/null 2>&1); then
        # Open-BSD55 improved ksh
        ps1ShType=${ps1ShType:-bash}
    elif [ "${KSH_VERSION}" = "@(#)PD KSH v5.2.14.2 99/07/13.2" ]; then
        # pdksh with strange esc sequences, seen on freebsd and _after_ ps1_open 4.3 on osx 10.11.6 ksh93
        ps1ShType=${ps1ShType:-kshhack2}
    else
        # other ksh with working '\a\r...\a<escaped1>\a ... \a<escaped2>\a'
        ps1ShType=${ps1ShType:-kshhack}
    fi
elif test -n "${BASH_VERSION}"; then
    ps1ShType=${ps1ShType:-bash}
    ps1Shell=bash
elif test -n "${ZSH_VERSION}"; then
    ps1ShType=${ps1ShType:-zsh}
    ps1Shell=zsh
elif test -n "${CSH_VERSION}" || test -n "${TCSH_VERSION}"; then
    echo "csh not supported"
    ps1ShType=${ps1ShType:-csh}
    ps1Shell=bash
else
    ps1ShType=${ps1ShType:-sh}
    ps1Shell="$(basename ${SHELL})?"
fi
# Apply ShType specific settings
ps1DateOnDef=2
if [ "${ps1ShType}" = "bash" ]; then
    ps1Date="\\A"; [ "${ps1DateOn:-$ps1DateOnDef}" = "2" ] && ps1Date="\\D{%a} ${ps1Date}"
    ps1Pwd="${ps1Pwd-\\w}"
    ps1Host="${ps1Host-\\h}"
    COLOR_SHESC_BEG="\\["
    COLOR_SHESC_END="\\]"
    COLOR_SHESC_INIT=
elif [ "${ps1ShType}" = "zsh" ]; then
    setopt PROMPT_SUBST
    #[ "${ps1Print##*/}" = "printf" ] && ps1ZshEsc="%" || ps1ZshEsc=
    ps1Date="${ps1ZshEsc}%T"; [ "${ps1DateOn:-$ps1DateOnDef}" = "2" ] && ps1Date="${ps1ZshEsc}%D{${ps1ZshEsc}%a} ${ps1Date}"
    ps1Pwd="${ps1Pwd-${ps1ZshEsc}%~}"
    ps1Host="${ps1Host-${ps1ZshEsc}%m}"
    COLOR_SHESC_BEG="${ps1ZshEsc}%{"
    COLOR_SHESC_END="${ps1ZshEsc}%}"
    COLOR_SHESC_INIT=
    unset ps1ZshEsc
elif [ "${ps1ShType%2}" = "kshhack" ]; then
    ps1Date=; [ "${ps1DateOn:-$ps1DateOnDef}" = "2" ] && ps1Date="%a "
    ps1Date="\$($(which date) '+${ps1Date}%H:%M')"
    ps1Pwd="${ps1Pwd-\$PWD}"
    ps1Host="${ps1Host-$(hostname -s)}"
    # Use a non-printable character used as color escape sequence.
    # \a(\007) is mentionned in ksh man, but the bell is annoying. try \026.
    COLOR_SHESC_BEG="\026"
    COLOR_SHESC_END="\026"
    COLOR_SHESC_INIT="${COLOR_SHESC_BEG}\r"
else
    # Try to guess, but use ps1{Pwd,Date,Err,Jobs}On to disable/enable
    # and/or ps1ShType: bash/kshhack* to override.
    # On unknown shells, display only 'User@Host (shell) $' by default.
    ps1Pwd="${ps1Pwd:-\\w}"
    ps1Date="${ps1Date:-\\A}"
    ps1Jobs="${ps1Jobs:-\\j}"
    ps1Err="${ps1Err:-\\?}"
    ps1PwdOn=${ps1PwdOn:-0}
    ps1DateOn=${ps1DateOn:-0}
    ps1JobOn=${ps1JobOn:-0}
    ps1ErrOn=${ps1ErrOn:-0}
    ps1GitOn=${ps1GitOn:-0}
    ps1Host="$(hostname -s)"
    ps1Colors=${ps1Colors:-0}
    COLOR_SHESC_BEG=
    COLOR_SHESC_END=
    COLOR_SHESC_INIT=
fi
# Default features
ps1DateOn="${ps1DateOn:-$ps1DateOnDef}"; unset ps1DateOnDef
ps1ErrOn="${ps1ErrOn:-1}"
ps1JobOn="${ps1JobOn:-1}"
ps1UserOn="${ps1UserOn:-1}"
ps1HostOn="${ps1HostOn:-1}"
ps1PwdOn="${ps1PwdOn:-2}"
ps1GitOn="${ps1GitOn:-1}"
ps1ShellOn="${ps1ShellOn:-1}"
ps1DashOn="${ps1DashOn:-1}"

# Define Colors escape sequences
COLOR_PRINTER="${ps1Print}"
COLOR_ESC_BEG="\033["
COLOR_ESC_END="m"
COLOR_STYLE_NONE="00;"
COLOR_STYLE_BOLD="01;"
COLOR_STYLE_DARK="02;"
COLOR_STYLE_ITAL="03;"
COLOR_STYLE_LINE="04;"
COLOR_CODE_DEF="00"
COLOR_CODE_BLACK="30"
COLOR_CODE_RED="31"
COLOR_CODE_GREEN="32"
COLOR_CODE_YELLOW="33"
COLOR_CODE_BLUE="34"
COLOR_CODE_PURPLE="35"
COLOR_CODE_CYAN="36"
COLOR_CODE_WHITE="37"
COLOR_CODE_BGGRAY="40"
COLOR_CODE_BGRED="41"
COLOR_CODE_BGGREEN="42"
COLOR_CODE_BGYELLOW="43"
COLOR_CODE_BGBLUE="44"
COLOR_CODE_BGPURPLE="45"
COLOR_CODE_BGCYAN="46"
COLOR_CODE_BGWHITE="47"

# Usage: COLOR_ESC [<color_style>;[<color_code>]] ('COLOR_ESC 31', 'COLOR_ESC 01;32')
COLOR_ESC() {
    ${COLOR_PRINTER} "${COLOR_ESC_BEG}${1:-${COLOR_CODE_DEF}}${COLOR_ESC_END}"
}
# Usage: COLOR_SHESC [<color_style>;[<color_code>]] ('COLOR_SHESC 31', 'COLOR_SHESC 01;34')
COLOR_SHESC() {
    ${COLOR_PRINTER} "${COLOR_SHESC_BEG}$(COLOR_ESC $@)${COLOR_SHESC_END}"
}

# Specific Prompt for root/wheel
ps1User=$(whoami)
if [ "${ps1User}" = "root" ] || [ "$(id -u)" = "0" ]; then
    ps1Dash='#'
    ps1Scope=Root
else
    ps1Dash='$'
    groups 2>/dev/null | grep -Eq "(^| )(admin|wheel)( |$)" 2>/dev/null \
        && ps1Scope=Wheel || ps1Scope=User
fi

# Check Terminal Color capability
# test -t 1: check if stdout is a terminal
if test -t 1; then
    # if ps1Colors is already set to >= 8, colors are forced
    # Otherwise, get number of colors with tput and check >= 8
    test -n "${ps1Colors}" || ps1Colors=$(tput colors 2> /dev/null)
    if test $? -ne 0 -o -z "${ps1Colors}" -o ${ps1Colors} -lt 8; then
        unset ps1Colors
    fi
    if [ "$ps1ShType" = "kshhack2" ] && [ -x "`which tput`" ]; then
        unset COLUMNS
        export COLUMNS=$(tput cols columns | head -n1)
    fi
fi

# Allow Shell to update term window title on supported terminals.
if [ -z "${ps1TitleOn}" ]; then
    case "$TERM" in
        xterm*|rxvt*)   ps1TitleOn=1 ;;
        *)
            case "$TERM_PROGRAM" in
                "Apple_Terminal"|"iTerm.app")   ps1TitleOn=1 ;;
                *)                              ps1TitleOn=0 ;;
            esac
            ;;
    esac
fi
if [ "${ps1TitleOn}" != "0" ]; then
    # "\033]0;<title>\007" : xterm title escape sequence
    # Produce title '\$ <shortPwd> - <terminal> [<shell>: <user>@<shortHostname> <fullPwd>]
    # Use $... for substitution at shell startup and \$ for dynamic shell expansion
    # Only \${PWD is dynamic here.
    ps1TitStr="\033]0;${ps1Dash} \${PWD##?*/} - ${TERM} "
    ps1TitStr="${ps1TitStr}[${ps1Shell}: ${ps1User}@$(hostname -s) \${PWD}]\007"
    if [ "${ps1ShType}" != "kshhack2" ]; then
        ps1TitStr="${COLOR_SHESC_BEG}${ps1TitStr}${COLOR_SHESC_END}"
    else
        # Problems on FreeBsd pdksh lead to not add ending escape sequence but only \r
        # Workaround only, right fix certainly possible.
        ps1TitStr="${COLOR_SHESC_BEG}${ps1TitStr}" # ${COLOR_SHESC_END}
    fi
    alias termtitle="printf '\033]0;%s\007'"
else
    alias termtitle='true'
    ps1TitStr=
    if [ "${ps1ShType}" = "kshhack2" ]; then
        ps1TitStr="${COLOR_SHESC_BEG}${ps1TitStr}"
    fi
fi
[ "${ps1ShType%2}" = "kshhack" ] && ps1TitStr="${ps1TitStr}\r"

# Define Parts colors
# Only possible with shell like bash/ksh providing print/printf compatible with
# escape sequence: Use \[...\], %{%} or kshhack to ignore char counting of a part of ps1
ps1_unset_colors() {
    for ps1Suf in '' User Root Wheel; do
        for ps1Item in Reset Date Err Job User Host Pwd Git Shell Dash; do # for f in $ps1Items not working with zsh
            unset ps1Color${ps1Item}${ps1Suf}
        done
    done
    unset ps1Suf ps1Item
}
if [ -z "${ps1Colors}" ]; then
    ps1_unset_colors
else
    ps1ColorReset=
    # Handle User specific colors
    if [ "$ps1Scope" = "Root" ]; then
        ps1ColorDate=${ps1ColorDateRoot:-${ps1ColorDate:-${COLOR_STYLE_NONE}${COLOR_CODE_CYAN}}}
        ps1ColorErr=${ps1ColorErrRoot:-${ps1ColorErr}}
        ps1ColorJob=${ps1ColorJobRoot:-${ps1ColorJob}}
        ps1ColorUser=${ps1ColorUserRoot:-${ps1ColorUser:-${COLOR_STYLE_BOLD}${COLOR_CODE_RED}}}
        ps1ColorHost=${ps1ColorHostRoot:-${ps1ColorHost}}
        ps1ColorPwd=${ps1ColorPwdRoot:-${ps1ColorPwd}}
        ps1ColorGit=${ps1ColorGitRoot:-${ps1ColorGit}}
        ps1ColorShell=${ps1ColorShellRoot:-${ps1ColorShell}}
        ps1ColorDash=${ps1ColorDashRoot:-${ps1ColorDash}}
    elif [ "${ps1Scope}" = "Wheel" ]; then
        ps1ColorDate=${ps1ColorDateWheel:-${ps1ColorDate}}
        ps1ColorErr=${ps1ColorErrWheel:-${ps1ColorErr}}
        ps1ColorJob=${ps1ColorJobWheel:-${ps1ColorJob}}
        ps1ColorUser=${ps1ColorUserWheel:-${ps1ColorUser:-${COLOR_STYLE_LINE}${COLOR_CODE_CYAN}}}
        ps1ColorHost=${ps1ColorHostWheel:-${ps1ColorHost}}
        ps1ColorPwd=${ps1ColorPwdWheel:-${ps1ColorPwd}}
        ps1ColorGit=${ps1ColorGitWheel:-${ps1ColorGit}}
        ps1ColorShell=${ps1ColorShellWheel:-${ps1ColorShell}}
        ps1ColorDash=${ps1ColorDashWheel:-${ps1ColorDash}}
    else
        ps1ColorDate=${ps1ColorDateUser:-${ps1ColorDate}}
        ps1ColorErr=${ps1ColorErrUser:-${ps1ColorErr}}
        ps1ColorJob=${ps1ColorJobUser:-${ps1ColorJob}}
        ps1ColorUser=${ps1ColorUserUser:-${ps1ColorUser}}
        ps1ColorHost=${ps1ColorHostUser:-${ps1ColorHost}}
        ps1ColorPwd=${ps1ColorPwdUser:-${ps1ColorPwd}}
        ps1ColorGit=${ps1ColorGitUser:-${ps1ColorGit}}
        ps1ColorShell=${ps1ColorShellUser:-${ps1ColorShell}}
        ps1ColorDash=${ps1ColorDashUser:-${ps1ColorDash}}
    fi
    # Assign Default values to thoses which are still undefined, and add escape color sequence.
    ps1ColorDate=$(COLOR_SHESC ${ps1ColorDate:-${COLOR_STYLE_NONE}${COLOR_CODE_PURPLE}})
    ps1ColorErr=$(COLOR_SHESC ${ps1ColorErr:-${COLOR_STYLE_BOLD}${COLOR_CODE_RED}})
    ps1ColorJob=$(COLOR_SHESC ${ps1ColorJob:-${COLOR_STYLE_NONE}${COLOR_CODE_YELLOW}})
    ps1ColorUser=$(COLOR_SHESC ${ps1ColorUser:-${COLOR_STYLE_NONE}${COLOR_CODE_CYAN}})
    ps1ColorHost=$(COLOR_SHESC ${ps1ColorHost:-${COLOR_STYLE_NONE}${COLOR_CODE_BLUE}})
    ps1ColorPwd=$(COLOR_SHESC ${ps1ColorPwd:-${COLOR_STYLE_NONE}${COLOR_CODE_GREEN}})
    ps1ColorGit=$(COLOR_SHESC ${ps1ColorGit:-${COLOR_STYLE_NONE}${COLOR_CODE_YELLOW}})
    ps1ColorShell=$(COLOR_SHESC ${ps1ColorShell:-${COLOR_STYLE_DARK}${COLOR_CODE_WHITE}})
    ps1ColorDash=$(COLOR_SHESC ${ps1ColorDash:-${ps1ColorReset}})
    # Must be last
    ps1ColorReset=$(COLOR_SHESC)
fi

######################################################
# >>> end of configuration. START Building PS1.
######################################################
if [ "${ps1ShType}" = "sh" ]; then
    PS1=
    [ "${ps1ErrOn}" != "0" ] && PS1="${PS1}${ps1Err} "
    [ "${ps1DateOn}" != "0" ] && PS1="${PS1}${ps1Date} "
    [ "${ps1JobOn}" != "0" ] && PS1="${PS1}${ps1Jobs} "
    [ "${ps1HostOn}" != "0" ] && ps1UserSpace= || ps1UserSpace=' '
    [ "${ps1UserOn}" != "0" ] && PS1="${PS1}${ps1User}${ps1UserSpace}"
    [ -z "${ps1UserSpace}" ] && PS1="${PS1}@${ps1Host} "
    [ "${ps1PwdOn}" != "0" ] && PS1="${PS1}${ps1Pwd} "
    [ "${ps1ShellOn}" != "0" ] && PS1="${PS1}(${ps1Shell}) "
    PS1="${PS1}${ps1Dash} "
    unalias __ps1_update_termtitle 2> /dev/null
    #unset __ps1_update_termtitle 2> /dev/null
    unalias __ps1_cd_fun 2> /dev/null
    alias cd 2>/dev/null | grep -q '__ps1' && unalias cd
    if [ "${ps1TitleOn}" != "0" ]; then
        # doing this alias allows inlining ps1Print and ps1TitStr variables
        alias __ps1_update_termtitle="${ps1Print} \"${ps1TitStr}\""
        __ps1_cd_fun() {
            # some sh do not have 'builtin'. Way to handle that: unalias; cd; alias cd=...
            # but this causes some problems, so do dirty things
            if [ -z "${ps1_nobuiltin}" ]; then
		builtin cd "$@" # parameters not managed: cd -L/ cd -P...
	    else
                # seen a sh which does not update dynamicaly fun&aliases tables
		unalias cd
		ps1_tmp="$(mktemp cdXXXXXX)";
		[ -n "$1" ] && echo "cd \"$@\"" > "${ps1_tmp}" || echo "cd" > "${ps1_tmp}"
		source "${ps1_tmp}"; rm -f "${ps1_tmp}"; unset ps1_tmp
		alias cd="__ps1_cd_fun"
	    fi
            __ps1_update_termtitle
        }
	if builtin cd "${PWD}" 2>&1 >/dev/null 2>&1; then
	    unset ps1_nobuiltin
            __ps1_update_termtitle
	else
	    ps1_nobuiltin=1
            #__ps1_cd_fun "${PWD}"
            __ps1_update_termtitle
	fi
	alias cd="__ps1_cd_fun"
    fi
else
# Start ps1Cmd. ps1Res must be first.
[ "${ps1ErrOn}" != "0" ] && ps1Cmd="ps1Res=\"\$?\";" || ps1Cmd=
ps1Cmd="${ps1Cmd}ps1Str=;"
# Get Number of jobs. must be among firsts on 'KSH Version AJM 93u+ 2012-08-01' osx 10.11.6, don't ask why.
[ "${ps1JobOn}" != "0" ] && ps1Cmd="${ps1Cmd} ps1Job=\$(jobs 2> /dev/null | ${ps1WcBin} -l);"
# Previous command result if not 0, avoid ! as special on some ksh
[ "${ps1ErrOn}" != "0" ] && ps1Cmd="${ps1Cmd} [ \"\${ps1Res}\" = \"0\" ] || ps1Str=\"${ps1ColorErr}\${ps1Res}${ps1ColorReset} \";"
# Date
[ "${ps1DateOn}" != "0" ] && ps1Cmd="${ps1Cmd} ps1Str=\"\${ps1Str}${ps1ColorDate}${ps1Date}${ps1ColorReset} \";"
# Number of Jobs if not 0
[ "${ps1JobOn}" != "0" ] && ps1Cmd="${ps1Cmd} [ \${ps1Job} -ne 0 ] && ps1Str=\"\${ps1Str}${ps1ColorJob}&\${ps1Job##* }${ps1ColorReset} \";"
# User
[ "${ps1HostOn}" != "0" ] && ps1UserSpace= || ps1UserSpace=' '
[ "${ps1UserOn}" != "0" ] && ps1Cmd="${ps1Cmd} ps1Str=\"\${ps1Str}${ps1ColorUser}${ps1User}${ps1ColorReset}${ps1UserSpace}\";"
# Host
[ -z "${ps1UserSpace}" ] && ps1Cmd="${ps1Cmd} ps1Str=\"\${ps1Str}${ps1ColorReset}@${ps1ColorHost}${ps1Host}${ps1ColorReset} \";"
# Directory
if [ "${ps1PwdOn}" != "0" ]; then
    if [ "${ps1PwdOn}" = "1" ]; then
        ps1Cmd="${ps1Cmd} ps1Str=\"\${ps1Str}${ps1ColorPwd}${ps1Pwd}${ps1ColorReset} \";"
    else
        # replace home by ~, not sure if this is link-proof.
        ps1Cmd="${ps1Cmd} tild='~'; mpwd=\"\$PWD\"; rem=\"\${mpwd#$HOME}\"; [ \"\$rem\" = \"\$mpwd\" ] && tild=\"\" || mpwd=\"\$rem\";"
        # Get last component of pwd: ${PWD##*/}, get first component of pwd: ${PWD%/${PWD#?*/}}
        # Get 2 last components of pwd: ${PWD#${PWD%/*/*}/}, get 2 first components of pwd: ${PWD%/${PWD#?*/?*/}}
        [ "${ps1PwdOn}" = "2" ] \
          && ps1Cmd="${ps1Cmd} first=\"\${mpwd%\${mpwd#?*/}}\"; last=\"\${mpwd##*/}\"; [ -z \"\${first}\" ] || " \
          || ps1Cmd="${ps1Cmd} first=\"\${mpwd%\${mpwd#?*/?*/}}\"; last=\"\${mpwd#\${mpwd%/*/*}/}\"; [ \"\${mpwd#?*/?*/?*/?*/}\" = \"\${mpwd}\" ] || "
        ps1Cmd="${ps1Cmd}[ \"\${first}\${last}\" = \"\$mpwd\" ] || mpwd=\"\${first}.../\${last}\";" # ##*/
        ps1Cmd="${ps1Cmd} ps1Str=\"\${ps1Str}${ps1ColorPwd}\${tild}\${mpwd}${ps1ColorReset} \";"
    fi
fi
# GIT branch if any
if [ "${ps1GitOn}" != "0" ] && [ -x "${ps1GitBin}" ]; then
    ps1Cmd="${ps1Cmd} ps1Git=\$(${ps1GitBin} branch 2>/dev/null | grep -E \"^\*\")"
    ps1Cmd="${ps1Cmd}   && ps1Str=\"\${ps1Str}${ps1ColorGit}[\${ps1Git##* }]${ps1ColorReset} \";"
fi
# Shell
[ "${ps1ShellOn}" != "0" ] && ps1Cmd="${ps1Cmd} ps1Str=\"\${ps1Str}${ps1ColorShell}(${ps1Shell})${ps1ColorReset} \";"
# Version
ps1Cmd="${ps1Cmd} [ -n \"\$ps1PrintVersion\" ] && ps1Str=\"[ps1_open v${ps1Version}"
ps1Cmd="${ps1Cmd} sh:${ps1Shell} shtype:${ps1ShType} print:${ps1Print} colors:${ps1Colors}"
ps1Cmd="${ps1Cmd} title:${ps1TitleOn} pwd:${ps1PwdOn} date:${ps1DateOn} columns:\${COLUMNS}]\n\${ps1Str}\";"
# Build the main ps1 command with <Result Date Jobs User Dir Git \$ > and the 'display-nothing' terminal title update
ps1Cmd="${ps1Cmd} ${ps1Print} \"${COLOR_SHESC_INIT}${ps1TitStr}\${ps1Str}${ps1ColorDash}${ps1Dash}${ps1ColorReset} \";"
# Set Prompt.
export PS1="\$(${ps1Cmd})"
fi # ! if ps1ShType = sh
# Cleanup.
ps1_unset_colors
for ps1Item in Date Err Job User Host Pwd Git Shell Dash Title; do unset ps1${ps1Item}On; done # for f in $ps1Items not working with zsh
unset ps1_unset_colors ps1Item ps1Items ps1Version ps1ShType
unset ps1Cmd ps1TitStr ps1Shell ps1Host ps1UserSpace ps1Err ps1Date ps1Jobs ps1Pwd ps1WcBin ps1PrintLF ps1GitBin
# ps1Colors ps1User ps1Scope ps1Dash ps1Print cleaned at the end of the script

##########################################################################################################
## OLD ONES ##############################################################################################
##########################################################################################################

# open prompt v1 (slow, not convenient to use colors)
if [ -n "${ps1OldOpenBsdV1}" ]; then
    [ -n "$ps1Colors" ] && ps1HeadCmd="\[\$(${ps1Print} \"\033[32m\")\]\$(" || ps1HeadCmd="\$("
    ps1HeadCmd="${ps1HeadCmd}ps1Res=\${?##0}; [ -n \"\${ps1Res}\" ] && printf \"\${ps1Res} \""
    ps1HeadCmd="${ps1HeadCmd};ps1Job=\$(jobs | wc -l);[ \${ps1Job} -gt 0 ] && ${ps1Print} \"&\${ps1Job##* } \")"
    ps1TitCmd="\[\$(${ps1Print} \"\033]0;${ps1Dash} \${PWD##?*/} - ${TERM} "
    ps1TitCmd="${ps1TitCmd}[$(basename $SHELL): ${ps1User}@$(hostname -s) \${PWD}]\007\")\]"
    [ -n "$ps1Colors" ] && ps1EndCmd="\[\$(${ps1Print} \"\033[00m\")\]" || ps1EndCmd=
    # Set Prompt. Use \[...\] to ignore char counting of a part of ps1
    export PS1="${ps1HeadCmd}${ps1TitCmd}${ps1User} \w${ps1EndCmd}${ps1Dash} "
    unset ps1User ps1Pwd ps1HeadCmd ps1TitCmd ps1Dash ps1Colors ps1EndCmd ps1Print

elif [ -n "${ps1OldOpenBsdV201}" ]; then

    # Only possible with shell like ksh providing print/printf compatible with escape sequence \[
    unset ps1ColorErr ps1ColorJob ps1ColorUser ps1ColorPwd ps1ColorDate ps1ColorReset
    if [ -n "${ps1Colors}" ]; then
        ps1ColorErr="\[\033[00;31m\]"
        ps1ColorJob="\[\033[00;33m\]"
        ps1ColorPwd="\[\033[00;32m\]"
        [ "$ps1User" != "root" ] && ps1ColorUser="\[\033[00;36m\]" || ps1ColorUser="\[\033[01;31m\]"
        ps1ColorDate="\[\033[00;35m\]"
        ps1ColorReset="\[\033[00m\]"
    fi
    case "$TERM" in
        xterm*|xte*)
            ps1TitCmd="\[\033]0;${ps1Dash} \${PWD##?*/} - ${TERM} "
            ps1TitCmd="${ps1TitCmd}[$(basename ${SHELL}): ${ps1User}@$(hostname -s) \${PWD}]\007\]"
            ;;
        *)
            ps1TitCmd=
            ;;
    esac
    ps1Cmd="ps1Res=\"\$?\"; ps1Str=; [ \"\${ps1Res}\" != \"0\" ] && ps1Str=\"${ps1ColorErr}\${ps1Res} \""
    ps1Cmd="${ps1Cmd};ps1Job=\$(jobs | wc -l)"
    ps1Cmd="${ps1Cmd};[ \${ps1Job} -gt 0 ] && ps1Str=\"\${ps1Str}${ps1ColorJob}&\${ps1Job##* } \""
    ps1Cmd="${ps1Cmd}; ${ps1Print} \"${ps1ColorDate}\\A \${ps1Str}${ps1ColorUser}${ps1User} ${ps1ColorPwd}\${PWD}"
    ps1Cmd="${ps1Cmd}${ps1ColorReset}${ps1Dash} ${ps1TitCmd}\""
    # Set Prompt. Use \[...\] to ignore char counting of a part of ps1
    export PS1="\$(${ps1Cmd})"
    unset ps1User ps1Pwd ps1Cmd ps1TitCmd ps1Dash ps1Colors ps1Print
    unset ps1ColorErr ps1ColorJob ps1ColorUser ps1ColorPwd ps1ColorDate ps1ColorReset

# tiger prompt v1 (too many forks, might be slow and not clean with variables)
elif [ -n "${ps1OldTigerV1}" ]; then
    mWORK=$(COLOR_SHESC ${COLOR_CODE_YELLOW})
    mCLOCK=$(COLOR_SHESC ${COLOR_CODE_PURPLE})

    if [ "$UID" = "0" ] || [ "$USER" = "root" ]; then
        mPROMPT=$(COLOR_SHESC ${COLOR_CODE_RED})
        mUSR=$(COLOR_SHESC ${COLOR_CODE_RED} ${COLOR_STYLE_BOLD})
        mHOST=$(COLOR_SHESC ${COLOR_CODE_GREEN} ${COLOR_STYLE_BOLD})
        mCLOCK=$(COLOR_SHESC ${COLOR_CODE_CYAN})
    elif groups 2>/dev/null | grep -E "(^| )(admin|wheel)( |$)" >/dev/null 2>&1; then
        mHOST=$(COLOR_SHESC ${COLOR_CODE_GREEN} ${COLOR_STYLE_BOLD})
        mPROMPT=$(COLOR_SHESC ${COLOR_CODE_RED})
        mUSR=$(COLOR_SHESC ${COLOR_CODE_CYAN} ${COLOR_STYLE_BOLD})
        mCLOCK=$(COLOR_SHESC ${COLOR_CODE_CYAN})
    else
        mHOST=$(COLOR_SHESC ${COLOR_CODE_GREEN})
        mPROMPT=$(COLOR_SHESC)
        mUSR=$(COLOR_SHESC ${COLOR_CODE_CYAN})
    fi

    #export PS1="$mUSR\u$NORM@$mHOST\h$NORM: $mWORK\w$mPROMPT\\$ $NORM"
    #myPWD='echo -n ${PWD/#$HOME/\~} | sed -e "s|(~?/[^/]*/).*(/.{12,})|\1...\2|"'
    myRES='res=$?; [ $res -ne 0 ] && echo "(${res}) "'
    myJOBS='nb_jobs=$(jobs -p | wc -l 2> /dev/null); [ $nb_jobs -ne 0 ] && echo "[&${nb_jobs##* }] "'
    myPWD='echo ${PWD/#$HOME/\~} | /usr/bin/sed -e "s/^\/Users\/\([^/]*\)/~\1/" | /usr/bin/sed -e "s/\(.\{12\}[^/]*\/\).*.\(\/[^/]*.\{24\}\)/\1\...\2/"'
    # hostname: \h
    myHOST='[ "${HOSTNAME%%.*}" = "tiger23" ] || echo "$HOSTNAME"'
    myGIT='/usr/bin/git branch 2>/dev/null | /usr/bin/grep -E "^\*" | /usr/bin/sed -Ee "s/^\* (.*)/ (\1)/"'
    export PS1="$(COLOR_SHESC ${COLOR_CODE_RED})"'$(eval "$myRES")'"$(COLOR_SHESC ${COLOR_CODE_YELLOW})"'$(eval "$myJOBS")'"$(COLOR_SHESC)${mCLOCK}\A$(COLOR_SHESC) ${mUSR}\u$(COLOR_SHESC)@$(COLOR_SHESC ${COLOR_CODE_GREEN})"'$(eval "$myHOST")'"$(COLOR_SHESC) $(COLOR_SHESC ${COLOR_CODE_YELLOW})"'$(eval "$myPWD")'"$(COLOR_SHESC ${COLOR_CODE_GREEN})"'$(eval "$myGIT")'"$(COLOR_SHESC)\$ "
fi

#test -n "${tcsh}" && \
#    if ($?prompt) then; \
#        set ps1Dash='#'; \
#        alias cwdcmd    'printf "\033]0; `[ $user = root ] && echo "#" || echo "$"` `pwd | sed -e "s|..*||"` - ${term} [`basename ${shell}`: `whoami`@`hostname -s` `pwd`]\007"'; \
#        alias precmd    'printf "\033\[32m"'; \
#        alias postcmd   'printf "\033\[00m"'; \
#        set prompt='?%? &%j %n@%M:%~ %# '; \
#        cwdcmd; \
#        unset ps1Dash; \
#    endif; return 0

##########################################################################################################
##########################################################################################################
##########################################################################################################

unset ps1User ps1Scope ps1Dash ps1Colors ps1Print

