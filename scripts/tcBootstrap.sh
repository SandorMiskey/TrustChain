#!/bin/bash

#
# Copyright TE-FOOD International GmbH., All Rights Reserved
#

# region: load common functions

[[ ${TC_PATH_RC:-"unset"} == "unset" ]] && TC_PATH_RC=${TC_PATH_BASE}/scripts/commonFuncs.sh
if [ ! -f  $TC_PATH_RC ]; then
	echo "=> TC_PATH_RC ($TC_PATH_RC) not found, make sure proper path is set or you execute this from the repo's 'scrips' directory!"
	exit 1
fi
source $TC_PATH_RC

if [[ ${TC_PATH_SCRIPTS:-"unset"} == "unset" ]]; then
	commonVerify 1 "TC_PATH_SCRIPTS is unset"
fi
commonPP $TC_PATH_SCRIPTS

# endregion: common
# region: helper functions

_printHelp() {
	commonPrintf "usage:"
	commonPrintf "	$0 [up|down] [flags|stack]"
	commonPrintf ""
	commonPrintf "flags:"
	commonPrintf "	-h - print this message "
	commonPrintf "	-m <up|down> - start or stop stacks"
	commonPrintf "	-s name - stack (name must be alphanumeric) to move in the direction of -m"
	exit 1
}

_checkMode() {
	local mode=$1
	if [[ "$mode" =~ ^(up|down|dummy)$ ]]; then
		return 0
	fi
	return 1
}

_checkStack() {
	local stack=$1
	# if [[ "$stack" =~ [^a-zA-Z0-9]  ]]; then
	if [[ "$stack" =~ [^a-zA-Z0-9-_]  ]]; then
		return 1
	fi
	return 0
}

# endregion: functions
# region: mode

mode=""
if [[ $# -lt 1 ]] ; then
	_printHelp
	exit 0
else
	mode=$1
	_checkMode $mode
	[[ $? -eq 0 ]] && shift
	# if [ $? -eq 0 ]; then
	# 	shift
	# fi
fi

# endregion: mode
# region: flags	

declare -a stacks=()
while [[ $# -ge 1 ]]; do
	case $1 in
	-h )
		_printHelp
		exit 0
		;;
	-m )
		mode=$2
		_checkMode $mode
		if [ $? -ne 0 ]; then
			_printHelp
		fi
		shift
		;;
	-s )
		stack=$2
		_checkStack $stack
		if [ $? -ne 0 ]; then
			_printHelp
		fi
		stacks+=("${TC_SWARM_NETNAME}_$stack")
		unset stack
		shift
		;;
	* )
		_checkStack $key
		if [ $? -ne 0 ]; then
			_printHelp
		fi
		stacks+=("${TC_SWARM_NETNAME}_$key")
		;;
	esac
	shift
	unset key
done

# endregion: glags
# region: execute

_checkMode $mode
if [ $? -ne 0 ]; then
	_printHelp
else
	verb=are
	(( ${#stacks[@]} == 1 )) && verb=is
	(( ${#stacks[@]} <  1 )) && joined="all ${TC_SWARM_NETNAME} services" || printf -v joined '%s & ' "${stacks[@]}"
	! [[ $mode == dummy ]] && commonPrintf "${joined% & } $verb going $mode"
	unset verb
	unset joined
fi

case $mode in
	"up" )
		# network
		if [ ! "$(docker network ls --format "{{.Name}}" --filter "name=${TC_SWARM_NETNAME}" | grep -w ${TC_SWARM_NETNAME})" ]; then
			out=$( docker network create $TC_SWARM_NETINIT 2>&1 )
			commonVerify $? "failed to create network: $out" "$TC_SWARM_NETNAME network is up"
			unset out
		else
			commonPrintf "${TC_SWARM_NETNAME} network already exists"
		fi

		# empty list of stacks
		if (( ${#stacks[@]} <  1 )); then
			# config files
			cfg=$( find $TC_PATH_SWARM/*yaml ! -name '.*' -print 2>&1 )
			commonVerify $? "$cfg"
			cfg=$(echo $cfg | sort)

			# deploy
			for cfg in $cfg; do
				stack=$( printf $cfg | sed "s/.*_//" | sed "s/.yaml//" | sed "s/^/${TC_SWARM_NETNAME}_/" )
				commonPrintf "deploying $cfg as ${stack}"
				out=$( docker stack deploy -c $cfg $stack --with-registry-auth 2>&1 )
				# commonVerify $? "failed to deploy $stack: `echo $out`" "$stack is deployed"
				commonVerify $? "failed to deploy $stack: $out" "$stack is deployed: $out"
				commonSleep $TC_SWARM_DELAY "waiting ${TC_SWARM_DELAY}s for the startup to finish"
				unset out
				unset stack
			done
			unset cfg
		# non-empty list of stacks
		else
			for stack in "${stacks[@]}"; do
				cfg=$( echo "${stack}" | sed "s/^${TC_SWARM_NETNAME}//")
				cfg=$( find $TC_PATH_SWARM/*${cfg}.yaml ! -name '.*' -print 2>&1 )
				commonVerify $? "no config found for $stack $cfg"
				commonPrintf "deploying $cfg as ${stack}"
				out=$( docker stack deploy -c $cfg $stack --with-registry-auth 2>&1 )
				commonVerify $? "failed to deploy $stack: $out" "$stack is deployed: $out"
				commonSleep $TC_SWARM_DELAY "waiting ${TC_SWARM_DELAY}s for the startup to finish"
				unset out
				unset cfg
			done
			unset stack
		fi
		;;
	"down" )
		(( ${#stacks[@]} <  1 )) && readarray -t stacks <<<$(docker stack ls --format "{{.Name}}")
		for stack in "${stacks[@]}"; do
			[[ $stack == ${TC_SWARM_NETNAME}_* ]] && commonPrintf "$stack is being terminated" || break
			out=$( docker stack rm $stack 2>&1 )
			commonVerify $? "failed to remove $stack: $out" "$stack services are removed: $out"
			unset out
		done
		unset stack
		;;
	"dummy" )
		commonPrintf "$0 is in dummy mode"
		;;
	* )
		_printHelp
		;;
esac

unset mode
unset stacks
unset _printHelp
unset _checkMode
unset _checkStacks

# endregion: execute
