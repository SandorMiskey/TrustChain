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


_SwarmLeave() {
	local status

	_leave() {
		local worker=$1
		local status
		status=$( ssh $worker "docker swarm leave" 2>&1 )
		commonVerify $? "$status" "swarm status: $status"
	}
		
	_leaveManager() {
		local status
		status=$( docker swarm leave --force 2>&1 )
		commonVerify $? "$status" "swarm status: $status"

	}

	local force=$COMMON_FORCE
	COMMON_FORCE=$TC_EXEC_SURE
	commonYN "remove ${TC_SWARM_WORKER1[node]}?" _leave ${TC_SWARM_WORKER1[node]}
	commonYN "remove ${TC_SWARM_WORKER2[node]}?" _leave ${TC_SWARM_WORKER2[node]}
	commonYN "remove ${TC_SWARM_WORKER3[node]}?" _leave ${TC_SWARM_WORKER3[node]}
	commonYN "removing the last manager erases all current state of the swarm, are you sure?" _leaveManager
	COMMON_FORCE=$force
}

token=""
_SwarmInit() {
	local status
	token=$( docker swarm init ${TC_SWARM_INIT} 2>&1 )
	status=$?
	commonVerify $status "$token"
	if [ $status -eq 0 ]; then
		token=$( printf "$token" | tr -d '\n' | sed "s/.*--token //" | sed "s/ .*$//" )
		local file=${TC_SWARM_PATH}/swarm-worker-token
		commonPrintf "swarm worker token is $token"
		echo $token > $file
		commonVerify $? "unable to write worker token to $file" "worker token is writen to $file"
	fi
	unset status
	unset file
}

_SwarmPrune() {
	_prune() {
		local status

		# workers

		status=$( ssh ${TC_SWARM_WORKER1[node]} "docker system prune --all -f" 2>&1 )
		commonVerify $? "$status" "swarm status: $status"
		status=$( ssh ${TC_SWARM_WORKER2[node]} "docker system prune --all -f" 2>&1 )
		commonVerify $? "$status" "swarm status: $status"
		status=$( ssh ${TC_SWARM_WORKER3[node]} "docker system prune --all -f" 2>&1 )
		commonVerify $? "$status" "swarm status: $status"

		# manager
		status=$( docker system prune --all -f 2>&1 )
		commonVerify $? "$status" "system prune: `echo $status`"
		status=$( docker volume rm $(docker volume ls -q) )
		commonVerify $? "$status" "volume rm: `echo $status`"
		# status=$( docker network prune -f 2>&1 )
		# commonVerify $? "$status" "network prune: `echo $status`"
		# status=$( docker volume prune -f 2>&1 )
		# commonVerify $? "$status" "volume prune: `echo $status`"
		# status=$( docker container prune -f 2>&1 )
		# commonVerify $? "$status" "container prune: `echo $status`"
		# status=$( docker image prune -f 2>&1 )
		# commonVerify $? "$status" "image prune: `echo $status`"
	}

	local force=$COMMON_FORCE
	COMMON_FORCE=$TC_EXEC_SURE
	commonYN "this will remove all local stuff CURRENTLY not used by at least one container, are you sure?" _prune
	COMMON_FORCE=$force

	unset status
	unset force
}

_SwarmJoin() {
	local cmd="docker swarm join --token $token ${TC_SWARM_PUBLIC}:2377"
	_join() {
		local status
		local worker=$1
		commonPrintf "$cmd will be issued on $worker"
		status=$( ssh $worker $cmd 2>&1 )
		commonVerify $? "$status" "swarm status: $status"
		status=$( docker node ls 2>&1 )
		commonVerify $? "$status" "swarm nodes: $status"
	}
	commonYN "join ${TC_SWARM_WORKER1[node]}?" _join ${TC_SWARM_WORKER1[node]}
	commonYN "join ${TC_SWARM_WORKER2[node]}?" _join ${TC_SWARM_WORKER2[node]}
	commonYN "join ${TC_SWARM_WORKER3[node]}?" _join ${TC_SWARM_WORKER3[node]}
}

if [ "$TC_EXEC_DRY" == false ]; then
	commonYN "leave docker swarm?" _SwarmLeave
	commonYN "init docker swarm?" _SwarmInit
	commonYN "prune networks/volumes/containers/images?" _SwarmPrune
	commonYN "join workers to swarm?" _SwarmJoin
fi
unset token
