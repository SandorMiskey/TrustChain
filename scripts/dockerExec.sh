#!/bin/bash

#
# Copyright TE-FOOD International GmbH., All Rights Reserved
#

# region: load config

[[ ${COMMON_FUNCS:-"unset"} == "unset" ]] && COMMON_FUNCS=${COMMON_BASE}/commonFuncs.sh
if [ ! -f  $COMMON_FUNCS ]; then
	echo "=> COMMON_FUNCS ($COMMON_FUNCS) not found, make sure proper path is set or you execute this from the repo's 'scrips' directory!"
	exit 1
fi
source $COMMON_FUNCS

# if [[ ${COMMON_BASE:-"unset"} == "unset" ]]; then
# 	commonVerify 1 "COMMON_BASE is unset"
# fi
# commonPP $COMMON_BASE
commonPP .

# endregion: load config

# region: flags	

_printHelp() {
	commonPrintf "usage:"
	commonPrintf "	$0 [cmd] [flags]"
	commonPrintf ""
	commonPrintf "flags:"
	commonPrintf "	-h             -> print this message "
	commonPrintf "	-n <node name> -> service to execute on, can be repeated"
	commonPrintf "	-c <command>   -> command to execute, can be multiple"
	commonPrintf "	-v             -> sets verbose mode regardles of environment"
	commonPrintf "	-t             -> unsets verbose mode"
	commonPrintf "	-a             -> add all local nodes to the list of nodes, can be isssued multiple times (shortcut to -n \"\")"
	commonPrintf "	-r             -> iterate first on commands, not nodes"
	commonPrintf "	-d             -> dummy mode, commands will not be executed"
	commonPrintf "	-i             -> interactive mode"
}

dockerExecIactive=false
dockerExecReverse=false
dockerExecVerbose=$COMMON_VERBOSE
dockerExecDummy=$COMMON_DUMMY

declare -a dockerExecNodes=()
declare -a dockerExecCommands=()

while [[ $# -ge 1 ]]; do
	key="$1"
	case $key in
		-h )
			_printHelp
			exit 0
			;;
		-n )
			dockerExecNodes+=("$2")
			shift
			;;
		-c )
			dockerExecCommands+=("$2")
			shift
			;;
		-v )
			COMMON_VERBOSE=true
			;;
		-t )
			COMMON_VERBOSE=false
			;;
		-a )
			# for node in $( docker ps --format "{{.Names}}"); do nodes+=("$node"); done
			dockerExecNodes+=("")
			# unset node
			;;
		-r )
			dockerExecReverse=true
			;;
		-d )
			COMMON_DUMMY=true
			;;
		-i )
			dockerExecIactive=true
			;;
		* )
			dockerExecCommands+=("$key")
			;;
	esac
	shift
	unset key
done
(( ${#dockerExecCommands[@]} == 0 )) && dockerExecCommands+=("uname -a" "hostname")
# (( ${#dockerExecNodes[@]} < 1 )) && commonVerify 1 "no actual node to execute commands on"

# endregion: flags
# region: nodes

declare -a dockerExecNodesActual=()
for node in "${dockerExecNodes[@]}"; do
	list=$(docker ps --format "{{.Names}}" -f "name=$node")
	[[ -z "$list" ]] && commonVerify 1 "cannot resolv \"$node\" as node" || commonPrintf "\"$node\" as node name is resolved to \"$list\""
	for resolved in $list; do dockerExecNodesActual+=("$resolved"); done
	unset node
	unset resolved
	unset list
done
if (( ${#dockerExecNodesActual[@]} < 1 )); then
	[[ "$COMMON_DUMMY" == true ]] || commonVerify 1 "no actual node to execute commands on"
fi
unset dockerExecNodes

# endregion: nodes
# region: execute

(( ${#dockerExecCommands[@]} > 1 )) && cs=s || cs="" 
(( ${#dockerExecNodesActual[@]} > 1 )) && ns=s || ns="" 
commonPrintf "command${cs} to be executed: $(commonJoinArray dockerExecCommands "\n%s" "")"
commonPrintf "node${ns} to execute command${cs} on: $(commonJoinArray dockerExecNodesActual "\n%s" "")"
unset cs ns

dockerExecExecute() {
	local node="$1"
	local cmd="$2"
	local out=""
	local res=0
	[[ "$dockerExecIactive" == true ]] && local imode=" in interactive mode" || local imode=""
	[[ "$COMMON_DUMMY" == true ]] && local dmode="NOT (because of COMMON_DUMMY mode is set) " || local dmode=""
	commonPrintf "\"$cmd\" will ${dmode}be executed on \"$node\"$imode"

	[[ "$COMMON_DUMMY" == true ]] && return
	case $dockerExecIactive in
		true )
			local temp=$( mktemp "${TMPDIR:-/tmp/}$(basename "$0").XXXXXX" )
			# set -o pipefail
			docker exec -it $(docker ps -q -f name="$node" ) $cmd 2>&1 | tee $temp
			# res=$?
			res=${PIPESTATUS[0]}
			out=`cat $temp`
			rm $temp
		;;
		* )
			out=$( docker exec -it $(docker ps -q -f name="$node" ) $cmd 2>&1 )
			res=$?
		;;
	esac

	if [ "$COMMON_VERBOSE" == true ]; then
		commonVerify $res "$out" "command output: $out"
	else
		if [[ $res -eq 0 ]]; then
			[[ "$dockerExecIactive" == true ]] || echo "$out"
		else
			[[ "$dockerExecIactive" == true ]] || commonVerify $res "$out"
		fi
	fi
	unset res out
}

case $dockerExecReverse in
	true )
		commonPrintf "-r has been set, so it will be iterated first on the commands, then on the nodes"
		for cmd in "${dockerExecCommands[@]}"; do
			for node in "${dockerExecNodesActual[@]}"; do
				dockerExecExecute "$node" "$cmd"
			done
			unset cmd
			unset node
		done
	;;
	* ) 
		for node in "${dockerExecNodesActual[@]}"; do
			for cmd in "${dockerExecCommands[@]}"; do
				dockerExecExecute "$node" "$cmd"
			done
			unset cmd
			unset node
		done
	;;
esac

# endregion: execute
# region: closing provisions

COMMON_VERBOSE=$dockerExecVerbose
COMMON_DUMMY=$dockerExecDummy
unset dockerExecReverse
unset dockerExecCommands
unset dockerExecNodesActual
unset dockerExecVerbose
unset dockerExecDummy

# endregion: closing
