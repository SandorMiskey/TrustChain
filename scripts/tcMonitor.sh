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


function _load() {
	local -n peer=$1
	local cmd='uptime | awk -F "load average:" "{print $2}"'
	local uptime=$( ssh ${peer[node]} uptime )
	local out=$( echo "$uptime" | /usr/bin/awk -F 'load average:' '{print "\t" $2}' )
	commonPrintf "${peer[node]} -> $out"

}

function _uptime() {
	local -n peer=$1
	local out=$( ssh ${peer[node]} "uptime --pretty" )
	commonPrintf "${peer[node]} -> $out"

}

function _df() {
	local -n peer=$1
	local cmd="df -h -t ext4 -t xfs -t fuse.glusterfs --output=target,fstype,size,used,avail,pcent"
	local out=$( ssh ${peer[node]} "${cmd}" )
	commonPrintf "${peer[node]}
$out"
}

commonPrintf " "
commonPrintf "$( date --rfc-3339=seconds )"

commonPrintf " "
commonPrintf "nodes"
commonPrintf "
$( docker node ls --format 'table{{.Hostname}}\t{{.Status}}\t{{.ManagerStatus}}' )"

commonPrintf " "
commonPrintf "services"
commonPrintf "
$( docker service ls --format 'table{{.Name}}\t{{.Mode}}\t{{.Replicas}}' )"

commonPrintf " "
commonPrintf "loads"
commonPrintf " "
commonIterate _load "ignore|checking |array|node|:" "${TC_SWARM_MANAGERS[@]}" "${TC_SWARM_WORKERS[@]}"

commonPrintf " "
commonPrintf "uptimes"
commonPrintf " "
commonIterate _uptime "ignore|checking |array|node|:" "${TC_SWARM_MANAGERS[@]}" "${TC_SWARM_WORKERS[@]}"

commonPrintf " "
commonPrintf "df"
commonPrintf " "
commonIterate _df "ignore|checking |array|node|:" "${TC_SWARM_MANAGERS[@]}" "${TC_SWARM_WORKERS[@]}"

unset _uptime _df
