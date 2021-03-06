#!/bin/sh
# Copyright (C) 2018-2019 Vincent Sallaberry
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
    for d in "$curdir/logs" "$mydir" "$mydir/logs"; do
        test -d "$d" -o -d "`readlink $d 2>/dev/null`" \
            && ls "$d"/*.log >/dev/null 2>&1 && logdir="$d" && break ;
    done
fi
vtablespec="$mydir/vtable_spec.sh"
sourceonly=
fetch=yes
colors=auto
verbosetable=
shorttable=
hostlayout=line
max_columns=auto
coltitle_size=auto
linetitle_size=auto
coltitle_max=31
linetitle_max=20

color_esc='\033['
color_end='m'
color_rst="${color_esc}00${color_end}"

# each "${color_...}${color_rst}" must be 13 chars
color_def="${color_esc}00;00${color_end}"
color_hstat="${color_esc}00;35${color_end}"
color_ok="${color_esc}00;32${color_end}"
color_ko="${color_esc}01;31${color_end}"
color_na="${color_esc}02;37${color_end}"
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
        for n in $names; do
            for h in $hosts; do
                test -e "$logdir/${n}_${h}.log" && eval "data_${h}__=ON"
            done
        done
    }
fi

show_help() {
    exit_status=$1
    echo "Usage: $0 [options]"
    echo "  -S, --source-only         : do nothing except parsing cmdline, used for script sourcing."
    echo "  -L, --logdir folder       : where to find logs, default: {CWD,sWD}/{,logs} (${logdir##$PWD/})."
    echo "  -D, --default             : do not load specific vtable_spec.sh script (${vtablespec##$PWD/})"
    echo "  -n, --no-fetch            : just parse existing logs without fetching them"
    echo "  -C, --color [on|off]      : force colors to off or on, default: $colors."
    echo "  -v, --verbose             : verbose the table"
    echo "  -s, --short               : short table"
    echo "  -H, --layout [line|col]   : invert or set host layout, default: $hostlayout."
    echo "  -c, --columns [chars]     : NOT_IMPLEMENTED - limit display to <chars> columns, default=$max_columns"
    echo "  -T, --col-title-size [n]  : set the size of a column title, default=$coltitle_size"
    echo "  -t, --line-title-size [n] : set the size of a line title, default=$linetitle_size"
    echo "  -M, --col-title-max [n]   : set the max size of a column title, default=$coltitle_max"
    echo "  -m, --line-title-max [n]  : set the max size of a line title, default=$linetitle_max"
    test -z "$sourceonly" && exit $exit_status
    test "$exit_status" = 0
}
while test -n "$1"; do
    case $1 in
        -h|--help)          show_help 0;;
        -S|--source-only)   sourceonly=yes;;
        -L|--logdir)        test -z "$2" && show_help 2; logdir=$2; shift;;
        -D|--default)       ;;
        -n|--no-fetch)      fetch=;;
        -C|--color)         case $2 in ''|-*) colors=on;; on|off) colors=$2; shift;; *) show_help 3;; esac ;;
        -v|--verbose)       verbosetable=yes;;
        -s|--short)         shorttable=yes;;
        -H|--layout)        case $2 in    ''|-*)  test "$hostlayout" = "line" && hostlayout=col || hostlayout=line;;
                                       line|col)  hostlayout=$2; shift;;
                                              *)  show_help 4;;
                            esac;;
        -c|--columns)       echo "'$1': Not implemented"; exit 12
                            case $2 in    ''|-*)  max_columns=auto;;
                                              *)  max_columns=$(($2)); shift;; esac ;;

        -T|--col-title-size)  case $2 in  ''|-*)  coltitle_size=auto;;
                                              *)  coltitle_size=$(($2)); shift;; esac ;;
        -t|--line-title-size) case $2 in  ''|-*)  linetitle_size=auto;;
                                              *)  linetitle_size=$(($2)); shift;; esac ;;
        -M|--col-title-max)   case $2 in  ''|-*)  show_help 5;;
                                              *)  coltitle_max=$(($2)); shift;; esac ;;
        -m|--line-title-max)  case $2 in  ''|-*)  show_help 6;;
                                              *)  linetitle_max=$(($2)); shift;; esac ;;
        *)                  show_help 1;;
    esac
    shift
done

if test -t 1; then
    test "$colors" = "auto" && colors=on
    if test "$max_columns" = "auto"; then
        max_columns=$COLUMNS
        if [ -x "`which tput`" ]; then
            tmp=$(tput cols columns | head -n1)
            if test $? -eq 0 -a -n "$tmp" -a "$tmp" != "$COLUMNS"; then
                unset COLUMNS
                export COLUMNS=$tmp
            fi
        fi
    fi
elif test "$max_columns" = "auto"; then
    max_columns=0
fi
if test "$colors" != "on";  then
    color_esc=
    color_end=
    color_rst=
    color_ok=
    color_na=
    color_ko=
    color_host=
    color_proj=
    color_ts=
    color_def=
    color_hstat=
    color_delta=
fi

timedelta() {
    local data
    data=$1
    if test $data -gt $((3600*24*365)); then data="$((data/(3600*24*365)))Y"
    elif test $data -gt $((3600*24*30)); then data="$((data/(3600*24*30)))M"
    elif test $data -gt $((3600*24)); then data="$((data/(3600*24)))d"
    elif test $data -gt 3600; then data="$((data/3600))h"
    elif test $data -gt 60; then data="$((data/60))m"
    else data="${data}s"; fi
    printf -- "$data"
}

# Parse logs, which must contain in their 20 last lines each of these (in order or disorder):
#builddate : YYYY.MM.DD_HH-MM-SS <seconds> # prefered format but not mandatory.
#distdate  : YYYY.MM.DD_HH-MM-SS <seconds> # prefered format but not mandatory.
#dist      : projv1_YYYY...                # prefered format but not mandatory. sarch for git rev, then date, then version
#make      : OK (8s)
#run       : KO (0s)
#make_dbg  : OK (20s)
#run_dbg   : OK (3s)
#distclean : KO (999s)
#make_obj  : KO (2s)
#run_obj   : NA (0s)
# this will produce variables 'data_<host>_<proj>_<MD|MR|TD|TR|DC|MO|TO|DT|NN|ND|DB|DD>[_secs]'
parse_logs() {
    local h n sep w w1 w2 w3 tmp now
    now=`date '+%s'`
    for h in $hosts; do
        for n in $names; do
            for w in `tail -n 20 "${logdir}/${n}_${h}.log" 2> /dev/null | grep -A20 -E '^builddate ' \
                    | sed -n \
                             -e 's/^make_dbg/MD/' -e 's/^make_obj/MO/' -e 's/^run_dbg/TD/' -e 's/^run_obj/TO/' -e 's/^distclean/DC/' \
                             -e 's/^make/MR/' -e 's/^run/TR/' -e 's/^builddate/DT/' -e 's/^distdate/ND/' -e 's/^dist/NN/' \
                             -e "s/^[[:space:]]*\([^[:space:]]*\)[[:space:]]*:[[:space:]]*\([^[:space:]]*\)[^(0-9]*(*\([0-9]*\).*/\1,\2,\3/p" \
                    | sort`; do
                sep=,
                w1=${w%%$sep*}; w=${w#*$sep}
                w2=${w%%$sep*}; w=${w#*$sep}
                w3=${w%%$sep*}; w=${w#*$sep}
                eval "data_${h}_${n}_${w1}=${w2}"
                eval "data_${h}_${n}_${w1}_secs=${w3}"
            done
            # compute diff builddate and diff distdate
            eval "tmp=\"\$data_${h}_${n}_DT_secs\""; test -z "$tmp" && eval "data_${h}_${n}_DB=-" || eval "data_${h}_${n}_DB=\"`timedelta $((now-tmp))`\""
            eval "tmp=\"\$data_${h}_${n}_ND_secs\""; test -z "$tmp" && eval "data_${h}_${n}_DD=-" || eval "data_${h}_${n}_DD=\"`timedelta $((now-tmp))`\""
        done
    done
}

# Get value from variable 'data_<host>_<proj>_<MD|MR|TD|TR|DC|MO|TO|DT|NN>[_secs]' and format it.
fmtdata() {
    local host=$1
    local proj=$2
    test "$hostlayout" = "col" && { host=$2; proj=$1; }
    local key=$3
    local cut=${4}
    local data cutcmd tmp
    local color="${color_def}"
    test -n "$cut" && cutcmd="cut -c -$cut" || cutcmd=cat

    # get value
    eval "data=\"\$data_${host}_${proj}_${key}\""
    # format
    case "${key}" in
        MD|MR|TD|TR|DC|MO|TO)
            case "$data" in "KO"*) color=${color_ko};;
                            "OK"*) color=${color_ok};;
                            "NA"*) color=${color_na};;
                            '')    ;;
                             *)    color=${color_ko}; data="??";;
            esac ;;
        *_secs) if test -n "$data"; then
                    data=$((data)); suf=; color=${color_ts};
                    if test $data -ge $((100*3600)); then data=""; suf='>'
                    elif test $data -ge $((100*60)); then data="$((data/3600))"; suf="h"
                    elif test $data -gt 99; then data="$((data/60))"; suf="m"; fi
                    if test -n "$cut" -a -n "$data" -a -n "$suf" && test $cut -lt 3; then
                        if test $data -ge 100; then data=; suf='>'
                        elif test $data -ge 10; then data=$((data/10)); test "$suf" = "h" && suf="^" || suf="*"; fi
                    fi; data="${data}${suf}"
                fi ;;
        NN) data="`echo \"$data\" | sed -e 's/.*[^a-fA-F0-9]\([a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9]\).*/@\1/' \
                                     -e 's/.*\([0-9][0-9][0-9][0-9]\)/:\1/' \
                                     -e 's/.*\([0-9][0-9]*\.[0-9][0-9]*[0-9.]*\).*/#v\1/' | $cutcmd`" ;;
        DT) data="`echo $data | $cutcmd`" ;;
        DB) color=;;
        DD) color=;;
    esac
    test -n "${color}" && data="${color}${data}${color_rst}"
    printf -- "$data"
}

# show table
print_table() {
    local col_header="$1"
    local col_items="$2"
    local colsz=$3
    local line_header="$4"
    local line_items="$5"
    local linesz=$6
    local stats="MR TR MD TD DC MO TO"
    local h n cut i
    local nstat=`echo "$stats" | wc -w`

    case "$colsz" in ''|auto|0|-*)
        test -n "$shorttable" && i=$((nstat*2+nstat-1)) || i=$((nstat*3+nstat-1))
        for h in "${col_header}" ${col_items}; do
            cut=${#h}; cut=$((cut+2))
            test $cut -gt $i && i=$cut
        done
        colsz=$i ;;
    esac
    case "$linesz" in ''|auto|0|-*)
        i=9
        for n in "${line_header}" ${line_items}; do
            cut=${#n}; cut=$((cut+1))
            test $cut -gt $i && i=$cut
        done
        linesz=$i ;;
    esac
    test "$colsz"  -gt "$coltitle_max"  &&  colsz=$coltitle_max
    test "$linesz" -gt "$linetitle_max" && linesz=$linetitle_max

    local statsz=$(((colsz-1)/(nstat+1)))
    local statpad=$((colsz-(nstat*statsz)-(nstat-1)))

    local colorlinesz=$linesz colorcolsz=$colsz colorstatsz=$statsz
    if test "$colors" = "on"; then
        colorlinesz=$((colorlinesz+13))
        colorcolsz=$((colorcolsz+13))
        colorstatsz=$((colorstatsz+13))
    fi

    pline_hcol() {
        local cline ccol tit h n i
        local titsz=0
        cline=${1:-_}
        ccol=${2:-|}
        h=$3 #test -z "$shorttable" -a -z "$verbosetable" && h=$3 || h=
        for ((i=0;i<linesz;i=i+1)); do printf -- "$cline"; done
        for n in $col_items; do
            test -n "$h" && { tit="`fmtdata $h $n DB`/`fmtdata $h $n DD`"; test "$tit" = "-/-" && tit=; titsz=${#tit}; }
            printf "$ccol"; for ((i=0;i<colsz-titsz;i=i+1)); do printf -- "$cline"; done; printf -- "${color_delta}${tit}${color_rst}"
        done
        printf "$ccol\n"
    }
    pheader_hcol() {
        local n s
        pline_hcol '' _
        printf "%${linesz}s" "`echo "${col_header}" | cut -c -$linesz`"
        for n in $col_items; do printf "| ${color_proj}%-$((colsz-1))s${color_rst}" "`echo ${n} | cut -c -$((colsz-1))`"; done
        printf "|\n%-${linesz}s" "`echo \"$line_header\" | cut -c -$linesz`"
        for n in $col_items; do
            for s in $stats; do printf "|%-${colorstatsz}s" "`printf ${color_hstat}${s}${color_rst}`"; done
            printf "%-${statpad}s"
        done
        printf "|\n"
        pline_hcol
    }
    pheader_hcol
    for h in $line_items; do
        case "`fmtdata ${h} '' ''`" in *ON*) i='*';; *) i=;; esac
        printf "${color_host}%-${linesz}s${color_rst}" "`echo \"${h}$i\" | cut -c -$linesz`"
        cut=$statsz

        # print build statuses
        for n in $col_items; do
            for s in $stats; do
                printf "|%-${colorstatsz}s" `fmtdata $h $n $s $cut`
            done
        done

        # print build timings
        if test -z "$shorttable"; then
            printf "|\n%-${linesz}s"
            for n in $col_items; do
                for s in $stats; do
                    printf "|%-${colorstatsz}s" `fmtdata $h $n ${s}_secs $cut`
                done
            done
        fi

        # Print build date and build dist name
        if test -n "$verbosetable"; then
            printf "|\n%-${linesz}s"
            for n in $col_items; do
                printf "|%-${colorcolsz}s" "DT `fmtdata $h $n DT $((colsz-3))`"
            done
            printf "|\n%-${linesz}s"
            for n in $col_items; do
                printf "|%-${colorcolsz}s" "NN`fmtdata $h $n NN $((colsz-2))`"
            done
        fi

        printf "|\n"
        pline_hcol '' '' "${h}"
    done
    # print glossary
    if test -z "$shorttable"; then
        local toprint
        toprint="\n${color_ts}DT${color_rst}:builddate ${color_ts}NN${color_rst}:distname ${color_hstat}xy${color_rst}:"
        toprint+="${color_hstat}x${color_rst}=${color_hstat}M${color_rst}ake|${color_hstat}T${color_rst}est,"
        toprint+="${color_hstat}y${color_rst}=${color_hstat}R${color_rst}elease|${color_hstat}D${color_rst}ebug)"
        toprint+="|${color_hstat}O${color_rst}bjbsd ${color_hstat}DC${color_rst}:distclean"
        echo "$toprint"
    fi
    test -z "$shorttable" \
    && echo "______Bt/Dt| ${color_delta}B${color_rst}:builddelta ${color_delta}D${color_rst}:distdelta "\
            "t:${color_delta}M${color_rst}(onth),${color_delta}d${color_rst}(ay),${color_delta}h${color_rst}(our),"\
            "${color_delta}m${color_rst}(in),${color_delta}s${color_rst}(ec)"
}

if test -z "$sourceonly"; then
    # fetch logs
    if test -n "$fetch"; then
        fetch_logs
    fi
    # Parse & display
    parse_logs
    if test "$hostlayout" = "col"; then
        print_table "/host " "$hosts" $coltitle_size "proj/" "$names" $linetitle_size # 19 15
    else
        print_table "/proj " "$names" $coltitle_size "host/" "$hosts" $linetitle_size # 19 10
    fi
fi

