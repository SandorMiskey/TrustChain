#!/bin/bash

#
# Copyright TE-FOOD International GmbH., All Rights Reserved
#

function commonDefaults() {
	#
	# sets default values where applicable
	#

	# TODO: validate setting COMMON_BASE

	# [[ ${COMMON_BOLD:-"unset"} == "unset" ]]		&& COMMON_BOLD=$(tput bold)
	# [[ ${COMMON_NORM:-"unset"} == "unset" ]]		&& COMMON_NORM=$(tput sgr0)
	[[ ${COMMON_BLUE:-"unset"} == "unset" ]]		&& COMMON_BLUE='\033[0;34m'
	[[ ${COMMON_GREEN:-"unset"} == "unset" ]]		&& COMMON_GREEN='\033[0;32m'
	[[ ${COMMON_NORM:-"unset"} == "unset" ]]		&& COMMON_NORM='\033[0m'
	[[ ${COMMON_RED:-"unset"} == "unset" ]]			&& COMMON_RED='\033[0;31m'
	[[ ${COMMON_YELLOW:-"unset"} == "unset" ]]		&& COMMON_YELLOW='\033[1;33m'
	[[ ${COMMON_BOLD:-"unset"} == "unset" ]]		&& COMMON_BOLD=$COMMON_YELLOW

	[[ ${COMMON_PREFIX:-"unset"} == "unset" ]]		&& COMMON_PREFIX="==> "
	[[ ${COMMON_SUBPREFIX:-"unset"} == "unset" ]]	&& COMMON_SUBPREFIX="    -> "

	[[ ${COMMON_DUMMY:-"unset"} == "unset" ]]		&& COMMON_DUMMY=false
	[[ ${COMMON_FORCE:-"unset"} == "unset" ]]		&& COMMON_FORCE=false
	[[ ${COMMON_PANIC:-"unset"} == "unset" ]]		&& COMMON_PANIC=false
	[[ ${COMMON_SILENT:-"unset"} == "unset" ]]		&& COMMON_SILENT=false
	[[ ${COMMON_VERBOSE:-"unset"} == "unset" ]]		&& COMMON_VERBOSE=true

	[[ ${COMMON_PREREQS:-"unset"} == "unset" ]]		&& COMMON_PREREQS=('sh')


	COMMON_SHELL=$( ps -p $$ -o comm= )
	if [[ -z $BASH ]]; then
		[[ ${COMMON_FUNCS:-"unset"} == "unset" ]]	&& COMMON_FUNCS=${funcstack[-1]}
		[[ ${COMMON_BASE:-"unset"} == "unset" ]]	&& COMMON_BASE=$(dirname "$COMMON_FUNCS")
	else
		_common=${BASH_SOURCE[0]}
		while [ -L "$_common" ]; do
			_base=$( cd -P "$( dirname "$_common" )" >/dev/null 2>&1 && pwd )
			_common=$(readlink "$_common")
			[[ $_common != /* ]] && _common=$_base/$_common
		done
		_base=$( cd -P "$( dirname "$_common" )" >/dev/null 2>&1 && pwd )

		[[ ${COMMON_BASE:-"unset"} == "unset" ]]	&& COMMON_BASE=$_base
		[[ ${COMMON_FUNCS:-"unset"} == "unset" ]]	&& COMMON_FUNCS=$_common
		unset _base _common
	fi
}
commonDefaults

function commonPrintf() {
	#
	# fancy echo
	#
	# usage:
	# -> commonPrintfBold "stuff to print" <printf format string>
	#
	# possible conf variables:
	# -> COMMON_SILENT=false
	# -> COMMON_PREFIX="===> "
	# -> COMMON_BOLD=$(tput bold)
	# -> COMMON_NORM=$(tput sgr0)

	commonDefaults
	[[ "$COMMON_SILENT" == true ]] && return 0
	[[ "$COMMON_VERBOSE" == true ]] || return 0
	[[ ${2:-"unset"} == "unset" ]] && local format="%s\n" || local format=$2
	printf $format "${COMMON_PREFIX}$( printf "%s\n" "$1" | head -n 1 )" 
	# printf $format "${TExPREFIX}$1"

	local lines=$( printf "%s\n" "$1" | wc -l )
	local cnt=2
	if [ $lines -gt 1 ]; then
		while [ $cnt -le $lines ] ; do
			printf $format "${COMMON_SUBPREFIX}$( printf "%s\n" "$1" | tail -n +$cnt | head -n 1 )" 
			cnt=$(expr $cnt + 1)
		done
	fi
}

function commonPrintfBold() {
	[[ ${2:-"unset"} == "unset" ]] && format="%s\n" || format=$2
	local verbose=$COMMON_VERBOSE
	COMMON_VERBOSE=true
	commonPrintf "$1" "${COMMON_BOLD}$format${COMMON_NORM}"
	COMMON_VERBOSE=$verbose
}

function commonSleep() {
	#
	# sleep w/ ticker
	#
	# usage:
	# -> COMMON_Sleep <secs to sleep> [msg]

	local delay
	local msg
	[[ ${1:-"unset"} == "unset" ]] && delay=3 || delay=$1
	[[ ${2:-"unset"} == "unset" ]] && msg="sleeping for ${delay}s" || msg=$2

	commonPrintf "$msg" "%s"
	local cnt
	for cnt in `seq 1 $delay`; do
		commonPrintf '%s' "."
		sleep 1
	done

	local prefix=$COMMON_PREFIX
	export COMMON_PREFIX=" "
	commonPrintf '\n' " "
	export COMMON_PREFIX=$prefix
}

function commonVerify() {
	#
	# dumps $2 if $1 -ne 0, exits if necessary
	#
	# typical usage:
	# -> commonVerify $? "error message"
	#
	# possible conf variables:
	# -> TE_PANIC=false

	commonDefaults
	if [ $1 -ne 0 ]
	then
		# >&2 commonPrintfBold "$2" "\b${COMMON_BOLD}%s${COMMON_NORM}\n"
		[[ -z "$2" ]] || >&2 commonPrintfBold "$2"
		if [[ "$COMMON_PANIC" == true ]]; then
			if [ ! "$COMMON_SHELL" = "bash" ] && [ ! "$COMMON_SHELL" = "zsh" ]; then
				commonPrintfBold "commonVerify(): COMMON_PANIC set to 'true' and no interactive shell ($COMMON_SHELL) detected, leaving..."
				exit 1
			fi
			commonPrintfBold "commonVerify(): COMMON_PANIC set to 'true' but shell seems to be interactive ($COMMON_SHELL), so keep rolling..."
		fi
	else
		if [ -z ${3+x} ]; then echo -n ""; else commonPrintf "$3"; fi
	fi
}

function commonDeps() {
	#
	# check if prerequisites are available
	#
	# possible conf variables:
	# -> declare -a COMMON_PREREQS=("curl" "git" "etc")

	prereqs=("$@")
	if [ 1 -gt ${#prereqs[@]} ]; then
		commonPrintf "commonDeps(): no \$@ passed, using env"
		commonDefaults
		prereqs=("${COMMON_PREREQS[@]}")
		if [ 1 -gt ${#prereqs[@]} ]; then
			declare -a prereqs=('sh')
		fi
	fi
	commonPrintf "commonDeps(): your PATH is: $PATH"
	commonPrintf "commonDeps(): checking for ${#prereqs[@]} dependencies:"
	
	for i in "${prereqs[@]}" ; do
		commonPrintf "commonDeps(): checking for $i and got " "%s"
		out=$( which $i )
		
		if [ $? -ne 0 ]
		then
			commonPrintf nothing
			commonVerify 1 "$i is missing!"
		else
			commonPrintf $out
		fi
	done

}

function commonYN() {
	local question=$1
	local ans
	shift

	if [[ "$COMMON_FORCE" == "true" ]]; then
		# commonPrintfBold "forced Y for '$question'" "${COMMON_BOLD}${COMMON_PREFIX}%s${COMMON_NORM} \n"
		# commonPrintfBold "COMMON_YN(): forced Y for '$question'" "${COMMON_BOLD}%s${COMMON_NORM}\n"
		commonPrintfBold "commonYN(): forced Y for '$question'" 
		ans="Y"
	else
		commonPrintfBold "$question [Y/n] " "%s"
		read ans
		# read -p "${COMMON_BOLD}${COMMON_PREFIX}$question [Y/n]${COMMON_NORM} " ans
	fi
	case "$ans" in
		y | Y | "")
			"$@"
			;;
		n | N)
			commonPrintf "skipping"
			;;
		*)
			commonPrintf "'y' or 'n'"
			commonYN "$question" "$@"
			;;
	esac
}

function commonContinue() {
	local question=$1; shift
	local answer

	if [[ "$COMMON_FORCE" == "true" ]]; then
		commonPrintfBold "commonYN(): forced Y for '$question'" 
		answer="Y"
	else
		commonPrintfBold "$question [Y/n] " "%s"
		read answer
	fi
	case "$answer" in
		y | Y)
			commonPrintf "okay, going ahead"
			;;
		n | N)
			exit
			;;
		*)
			commonPrintf "'y' or 'n'"
			commonContinue "$question"
			;;
	esac	
}

function commonPP() {
	pushd ${PWD} > /dev/null
	trap "popd > /dev/null" EXIT
	cd $1
}

function commonSetvar() {
	# replaces env variables with its value in strings
	target=$1
	while [[ $target =~ ^(.*)(\{[a-zA-Z0-9_]+\})(.*)$ ]] ; do
		varname=${BASH_REMATCH[2]}
		varname=${varname#"{"}
		varname=${varname%\}}
		printf -v target "%s%s%s" "${BASH_REMATCH[1]}" "${!varname}" "${BASH_REMATCH[3]}"
	done
	printf "%s" $target
}

function commonJoinArray() {
	local -n arr=$1
	[[ ${2:-"unset"} == "unset" ]] && local form="%s\n" || local form="$2"
	[[ ${3:-"unset"} == "unset" ]] && local cut="" || local cut="$3"
	local out
	printf -v out "$form" "${arr[@]}"
	# printf "${out%$cut}"
	echo "${out%$cut}"
}
