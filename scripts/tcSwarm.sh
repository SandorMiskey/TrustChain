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

_iterate() {
	local func=$1
	local msg=$2
	shift 2

	for k in "$@"; do
		declare -n details=$k
		local node=${details[node]}
		commonYN "$msg${node}?" $func ${node}
		# unset details
	done

	unset func msg k
}

_swarmLeave() {
	local force=$COMMON_FORCE
	COMMON_FORCE=$TC_EXEC_SURE

	_leave() {
		local worker=$1
		local status=$( ssh $worker "docker swarm leave --force" 2>&1 )
		commonVerify $? "$status" "swarm status: $status"
	}

	commonPrintfBold "remember: removing the last manager erases all current state of the swarm!"
	_iterate _leave "remove node " "${TC_SWARM_WORKERS[@]}" "${TC_SWARM_MANAGERS[@]}"

	unset _leave
	COMMON_FORCE=$force
}

_swarmPrune() {
	local force=$COMMON_FORCE
	COMMON_FORCE=$TC_EXEC_SURE

	_prune() {
		local worker=$1
		local status=$( ssh $worker "docker system prune --all -f" 2>&1 )
		commonVerify $? "$status" "swarm status: $status"

		# status=$( ssh $worker "docker volume rm $(docker volume ls -q)" 2>&1 )
		# commonVerify $? "$status" "volume rm: `echo $status`"
	}

	commonPrintfBold "remember: this will remove all local stuff CURRENTLY not used by at least one container!"
	_iterate _prune "system prune --all -f @" "${TC_SWARM_WORKERS[@]}" "${TC_SWARM_MANAGERS[@]}"

	unset _prune
	COMMON_FORCE=$force
}

_swarmInit() {
	declare -n leader="${TC_SWARM_MANAGERS[0]}"

	local out=$( ssh "${leader[node]}" "docker swarm init ${TC_SWARM_INIT}" 2>&1 )
	commonVerify $? "failed: $out" "swarm status: $out"

	local tokerWorker=$( ssh ${leader[node]} "docker swarm join-token -q worker" 2>&1 )
	commonVerify $? "failed: $tokerWorker" "worker token: $tokerWorker"
	local tokerManager=$( ssh ${leader[node]} "docker swarm join-token -q manager" 2>&1 )
	commonVerify $? "failed: $tokerManager" "manager token: $tokerManager"

	# unset leader
}

_swarmJoin() {
	declare -n leader=${TC_SWARM_MANAGERS[0]}
	local managers=("${TC_SWARM_MANAGERS[@]:1}")
	local token=""

	_joinManager() {
		local node=$1
		local cmd="docker swarm join --token $( docker swarm join-token -q manager ) ${leader[ip]}:2377"
		local status=$( ssh $node "$cmd" 2>&1 )
		commonVerify $? "$status" "swarm status: $status"
	}
	_joinWorker() {
		local node=$1
		local cmd="docker swarm join --token $( docker swarm join-token -q worker ) ${leader[ip]}:2377"
		local status=$( ssh $node "$cmd" 2>&1 )
		commonVerify $? "$status" "swarm status: $status"
	}

	token=$tokeManager && _iterate _joinManager "join node as a manager: " "${managers[@]}"
	token=$tokenWorker && _iterate _joinWorker "join node as a worker: " "${TC_SWARM_WORKERS[@]}"

	local status=$( docker node ls 2>&1 )
	commonVerify $? "$status" "swarm nodes: $status"

	# unset leader
}

if [ "$TC_EXEC_DRY" == false ]; then
	commonYN "leave docker swarm?" _swarmLeave
	commonYN "prune networks/volumes/containers/images?" _swarmPrune
	commonYN "init docker swarm?" _swarmInit
	commonYN "join workers to swarm?" _swarmJoin
fi
