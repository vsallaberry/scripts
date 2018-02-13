#!/bin/sh
# Copyright (C) 2018 Vincent Sallaberry
# vtable.sh <https://github.com/vsallaberry/scripts/sh/vtable>
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
#
############################################################################################
# Display different values in a colored table. Initially written to display
# summary about different build log files, on different machines.
#
mydir=$(dirname $0); curdir="`pwd`"; cd "${mydir}"; mydir="`pwd`"; cd "${curdir}"
mypath="${mydir}/$(basename $0)"

logdir=$curdir
if ! ls $curdir/*.log >/dev/null 2>&1; then
    for d in "$curdir/logs" "$mydir/logs"; do
        test -d "$d" -o -d "`readlink $d 2>/dev/null`" \
            && ls "$d"/*.log >/dev/null 2>&1 && logdir="$d" && break ;
    done
fi
vtablespec="$mydir/vtable_spec.sh"
fetch=yes
colors=auto
verbosetable=
shorttable=

color_esc='\033['
color_end='m'
color_rst="${color_esc}00${color_end}"

# each "${color_...}${color_rst}" must be 13 chars
color_def="${color_esc}00;00${color_end}"
color_hstat="${color_esc}00;35${color_end}"
color_ok="${color_esc}00;32${color_end}"
color_ko="${color_esc}01;31${color_end}"
color_host="${color_esc}00;33${color_end}"
color_proj="${color_esc}00;36${color_end}"
color_ts="${color_esc}02;37${color_end}"
color_delta="${color_esc}00;34${color_end}"

# Include specific part if existing, and, if the option '-D,--default' is not given.
for p in $@; do case $p in -D|--default) vtablespec=; break ;; esac; done
if test -e "$vtablespec"; then
   . "$vtablespec"
else
    names="vtable_fake tmp_prog prog_3 prog4"
    hosts="os2 ordi os3 oldone newone"
    fetch_logs() {
        echo "fetch_logs: not implemented"
    }
fi

show_help() {
    exit_status=$1
    echo "Usage: $0 [-h] [-L] [-D] [-n] [-C] [-v] [-s]"
    echo "  -L, --logdir         : where to find logs, default: CWD,CWD/logs."
    echo "  -D, --default        : do not load specific vtable_spec.sh script"
    echo "  -n, --no-fetch       : just parse existing logs without fetching them"
    echo "  -C, --color [on|off] : force colors to off or on, default: auto."
    echo "  -v, --verbose        : verbose the table"
    echo "  -s, --short          : short table"
    exit $exit_status
}
while test -n "$1"; do
    case $1 in
        -h|--help)          show_help 0;;
        -L|--logdir)        test -z "$2" && show_help 2; logdir=$2; shift;;
        -D|--default)       ;;
        -n|--no-fetch)      fetch=;;
        -C|--color)         case $2 in ''|-*) colors=on;; on|off) colors=$2; shift;; *) show_help 2;; esac ;;
        -v|--verbose)       verbosetable=yes;;
        -s|--short)         shorttable=yes;;
        *)                  show_help 1;;
    esac
    shift
done

test "$colors" = "auto" && test -t && colors=on
if test "$colors" != "on";  then
    color_esc=
    color_end=
    color_rst=
    color_ok=
    color_ko=
    color_host=
    color_proj=
    color_ts=
    color_def=
    color_hstat=
    color_delta=
fi

# Parse logs, which must contain in their 20 last lines each of these (in order or disorder):
#builddate : YYYY.MM.DD_HH-MM-SS  # prefered format but not mandatory.
#dist      : projv1_YYYY...       # prefered format but not mandatory. sarch for git rev, then date, then version
#make      : OK (8s)
#run       : KO (0s)
#make_dbg  : OK (20s)
#run_dbg   : OK (3s)
#distclean : KO (999s)
# this will produce variables 'data_<host>_<proj>_<MD|MR|TD|TR|DC|DT|NN>[_secs]'
parse_logs() {
    local h n sep w w1 w2 w3
    for h in $hosts; do
        for n in $names; do
            for w in `tail -n 20 "${logdir}/${n}_${h}.log" 2> /dev/null | grep -A20 -E '^builddate ' \
                    | sed -n \
                             -e 's/^make_dbg/MD/' -e 's/^make/MR/' -e 's/^run_dbg/TD/' -e 's/^run/TR/' -e 's/^distclean/DC/' \
                             -e 's/^builddate/DT/' -e 's/^dist/NN/' \
                             -e "s/^[[:space:]]*\([^[:space:]]*\)[[:space:]]*:[[:space:]]*\([^[:space:]]*\)[^(]*(*\([0-9]*\).*/\1,\2,\3/p" \
                    | sort`; do
                sep=,
                w1=${w%%$sep*}; w=${w#*$sep}
                w2=${w%%$sep*}; w=${w#*$sep}
                w3=${w%%$sep*}; w=${w#*$sep}
                eval "data_${h}_${n}_${w1}=${w2}"
                eval "data_${h}_${n}_${w1}_secs=${w3}"
            done
        done
    done
}

# Get value from variable 'data_<host>_<proj>_<MD|MR|TD|TR|DC|DT|NN>[_secs]' and format it.
fmtdata() {
    local host=$1
    local proj=$2
    local key=$3
    local cut=${4}
    local data cutcmd
    local color="${color_def}"
    test -n "$cut" && cutcmd="cut -c -$cut" || cutcmd=cat
    # get value
    eval "data=\"\$data_${host}_${proj}_${key}\""
    # format
    case "${key}" in
        MD|MR|TD|TR|DC)
            case "$data" in "KO") color=${color_ko};;
                            "OK") color=${color_ok};;
                            '')   ;;
                            *)    color=${color_ko}; data="??";;
            esac ;;
        *_secs) color=${color_ts}; if test -n "$data"; then
                if test -$data -gt $((99*60)); then data="$((data/3600))h"
                elif test $data -gt 999; then data="$((data/60))m"; fi; fi ;;
        NN) data="`echo \"$data\" | sed -e 's/.*[^a-fA-F0-9]\([a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9]\).*/@\1/' \
                                     -e 's/.*\([0-9][0-9][0-9][0-9]\)/:\1/' \
                                     -e 's/.*\([0-9][0-9]*\.[0-9][0-9]*[0-9.]*\).*/#v\1/' | $cutcmd`" ;;
        DT) data="`echo $data | $cutcmd`" ;;
    esac
    data="${color}${data}${color_rst}"
    printf "$data"
}

# show table
print_table() {
    local h n cut
    local hostsz=10
    local namesz=19
    local stats="MR TR MD TD DC"
    local nstat=5
    local statsz=$(((namesz-1)/(nstat+1)))
    local statpad=$((namesz-(nstat*statsz)-(nstat-1)))
    local colorhostsz=$hostsz colornamesz=$namesz colorstatsz=$statsz
    if test "$colors" = "on"; then
        colorhostsz=$((colorhostsz+13))
        colornamesz=$((colornamesz+13))
        colorstatsz=$((colorstatsz+13))
    fi
    pline_hcol() {
        cline=${1:-_}
        ccol=${2:-|}
        test -z "$shorttable" -a -z "$verbosetable" && tit=$3 || tit=; titsz=${#tit}
        for ((i=0;i<hostsz;i=i+1)); do printf -- "$cline"; done
        for n in $names; do printf "$ccol"; for ((i=0;i<namesz-titsz;i=i+1)); do printf -- "$cline"; done; printf -- "${color_delta}${tit}${color_rst}"; done
        printf "$ccol\n"
    }
    pheader_hcol() {
        pline_hcol '' _
        printf "%${hostsz}s" "`echo '/proj ' | cut -c -$hostsz`"
        #for n in $names; do printf "| %-$((colornamesz-1))s" "`printf ${color_proj}${n}${color_rst}`"; done
        for n in $names; do printf "| ${color_proj}%-$((namesz-1))s${color_rst}" "`echo ${n} | cut -c -$((namesz-1))`"; done
        printf "|\n%-${hostsz}s" "`echo host/ | cut -c -$hostsz`"
        for n in $names; do
            for s in $stats; do printf "|%-${colorstatsz}s" "`printf ${color_hstat}${s}${color_rst}`"; done
            printf "%-${statpad}s"
        done
        printf "|\n"
        pline_hcol
    }
    pheader_hcol
    for h in $hosts; do
        #printf "%-${colorhostsz}s" "`printf ${color_host}${h}${color_rst}`"
        printf "${color_host}%-${hostsz}s${color_rst}" "`echo ${h} | cut -c -$hostsz`"
        cut=$statsz

        for n in $names; do
            # print build statuses
            printf "|%-${colorstatsz}s|%-${colorstatsz}s|%-${colorstatsz}s|%-${colorstatsz}s|%-${colorstatsz}s%-${statpad}s" \
                   `fmtdata $h $n MR $cut` `fmtdata $h $n TR $cut` `fmtdata $h $n MD $cut` `fmtdata $h $n TD $cut` `fmtdata $h $n DC $cut`
        done

        if test -z "$shorttable"; then
            # print build timings
            printf "|\n%-${colorhostsz}s" `fmtdata ${h}`
            for n in $names; do
                printf "|%-${colorstatsz}s|%-${colorstatsz}s|%-${colorstatsz}s|%-${colorstatsz}s|%-${colorstatsz}s%-${statpad}s" \
                       `fmtdata $h $n MR_secs $cut` `fmtdata $h $n TR_secs $cut` `fmtdata $h $n MD_secs $cut` `fmtdata $h $n TD_secs $cut` `fmtdata $h $n DC_secs $cut`
            done
        fi

        if test -n "$verbosetable"; then
            # Print build date and build dist name
            cut=$((namesz-2))
            printf "|\n%-${hostsz}s"
            for n in $names; do
                printf "|%-${colornamesz}s" "DT `fmtdata $h $n DT $cut`"
            done
            printf "|\n%-${hostsz}s"
            for n in $names; do
                printf "|%-${colornamesz}s" "NN`fmtdata $h $n NN $cut`"
            done
        fi

        printf "|\n"
        pline_hcol '' '' "?/?" # TODO
    done
    # print glossary
    test -z "$shorttable" \
    && echo "\n${color_ts}DT${color_rst}:builddate ${color_ts}NN${color_rst}:distname ${color_hstat}MR${color_rst}:make "\
            "${color_hstat}TR${color_rst}:test ${color_hstat}MD${color_rst}:make_dbg ${color_hstat}TD${color_rst}:test_dbg "\
            "${color_hstat}DC${color_rst}:distclean"
    test -z "$shorttable" -a -z "$verbosetable" \
    && echo "______Bt/Dt| ${color_delta}B${color_rst}:builddelta ${color_delta}D${color_rst}:distdelta "\
            "t:${color_delta}M${color_rst}(onth),${color_delta}d${color_rst}(ay),${color_delta}h${color_rst}(our),"\
            "${color_delta}m${color_rst}(in),${color_delta}s${color_rst}(ec)"
}

# fetch logs
if test -n "$fetch"; then
    fetch_logs
fi
# Parse & display
parse_logs
print_table

