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

_swarmLeave() {
	local force=$COMMON_FORCE
	COMMON_FORCE=$TC_EXEC_SURE

	_leave() {
		local -n peer=$1
		local status=$( ssh ${peer[node]} "$TC_SWARM_DOCKER swarm leave --force" 2>&1 )
		commonVerify $? "$status" "swarm status: $status"
	}

	commonPrintfBold " "
	commonPrintfBold "remember: removing the last manager erases all current state of the swarm!"
	commonPrintfBold " "
	commonIterate _leave "confirm|remove |array|node| from swarm?" "${TC_SWARM_WORKERS[@]}" "${TC_SWARM_MANAGERS[@]}"

	unset _leave
	COMMON_FORCE=$force
}

_swarmPrune() {
	local force=$COMMON_FORCE
	COMMON_FORCE=$TC_EXEC_SURE

	_prune() {
		local -n peer=$1
		local status
		# status=$( ssh ${peer[node]} "docker network prune -f" 2>&1 )
		# commonVerify $? "$status" "swarm status: $status"
		status=$( ssh ${peer[node]} "$TC_SWARM_DOCKER  system prune --all -f" 2>&1 )
		commonVerify $? "$status" "swarm status: $status"
		# status=$( ssh ${peer[node]} "docker volume rm $(docker volume ls -q)" 2>&1 )
		# commonPrintf "volume rm: `echo $status`"
		# commonVerify $? "$status" "volume rm: `echo $status`"
	}

	commonPrintfBold " "
	# commonPrintfBold "remember: this will remove all local stuff CURRENTLY not used by at least one container!"
	commonPrintfBold "remember: this will remove all local images, volumes, networks...!"
	commonPrintfBold " "
	commonIterate _prune "confirm|system prune --all -f @ |array|node|?" "${TC_SWARM_WORKERS[@]}" "${TC_SWARM_MANAGERS[@]}"

	unset _prune
	COMMON_FORCE=$force
}

_swarmInit() {
	declare -n leader="${TC_SWARM_MANAGERS[0]}"

	local out cmd

	out=$( ssh "${leader[node]}" "$TC_SWARM_DOCKER  swarm init ${TC_SWARM_INIT}" 2>&1 )
	commonVerify $? "failed: $out" "swarm status: $out"

	cmd="echo \"$TC_HTTP_API_KEY\" | $TC_SWARM_DOCKER  secret create tc_http_api_key -"
	out=$( ssh ${leader[node]} "$cmd" 2>&1 )
	commonVerify $? "failed: $out" "tc_http_api_key external secret is created"
	cmd="echo \"$TC_HTTPS_CERT\" | $TC_SWARM_DOCKER  secret create tc_https_cert -"
	out=$( ssh ${leader[node]} "$cmd" 2>&1 )
	commonVerify $? "failed: $out" "tc_https_cert external secret is created"
	cmd="echo \"$TC_HTTPS_KEY\" | $TC_SWARM_DOCKER  secret create tc_https_key -"
	out=$( ssh ${leader[node]} "$cmd" 2>&1 )
	commonVerify $? "failed: $out" "tc_https_key external secret is created"

	local tokerWorker=$( ssh ${leader[node]} "$TC_SWARM_DOCKER  swarm join-token -q worker" 2>&1 )
	commonVerify $? "failed: $tokerWorker" "worker token: $tokerWorker"
	local tokerManager=$( ssh ${leader[node]} "$TC_SWARM_DOCKER  swarm join-token -q manager" 2>&1 )
	commonVerify $? "failed: $tokerManager" "manager token: $tokerManager"

	# unset leader
}

_swarmJoin() {
	declare -n leader=${TC_SWARM_MANAGERS[0]}
	local managers=("${TC_SWARM_MANAGERS[@]:1}")
	local token=""

	_joinManager() {
		local -n peer=$1
		local cmd="$TC_SWARM_DOCKER  swarm join --advertise-addr ${peer[ip]}:2377 --token $( $TC_SWARM_DOCKER  swarm join-token -q manager ) ${leader[ip]}:2377"
		local status=$( ssh ${peer[node]} "$cmd" 2>&1 )
		commonVerify $? "$status" "swarm status: $status"
	}
	_joinWorker() {
		local -n peer=$1
		local cmd="$TC_SWARM_DOCKER  swarm join --advertise-addr ${peer[ip]}:2377 --token $( $TC_SWARM_DOCKER  swarm join-token -q worker ) ${leader[ip]}:2377"
		local status=$( ssh ${peer[node]} "$cmd" 2>&1 )
		commonVerify $? "$status" "swarm status: $status"
	}

	token=$tokeManager && commonIterate _joinManager "print|join node as a manager: |array|node|" "${managers[@]}"
	token=$tokenWorker && commonIterate _joinWorker "print|join node as a worker: |array|node|" "${TC_SWARM_WORKERS[@]}"

	local status=$( docker node ls 2>&1 )
	commonVerify $? "$status" "swarm nodes: $status"

	# unset leader
}

if [ "$TC_EXEC_DRY" == false ]; then
	commonYN "leave docker swarm?" _swarmLeave
	commonYN "prune networks/volumes/containers/images?" _swarmPrune
	commonYN "init docker swarm?" _swarmInit
	commonYN "join workers to swarm?" _swarmJoin

	_me=$( basename "$0" )
	_prefix="$COMMON_PREFIX"
	COMMON_PREFIX="===>>> "
	commonPrintfBold " "
	commonPrintfBold "ALL DONE! IF THIS IS FINAL, ISSUE THE FOLLOWING COMMAND: sudo chmod a-x ${TC_PATH_SCRIPTS}/${_me}"
	commonPrintfBold " "
	COMMON_PREFIX="_prefix"
	unset _prefix _me
fi
