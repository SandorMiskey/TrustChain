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
	# local cmd='uptime | awk -F "load average:" "{print $2}"'
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

function _chInfo() {
	for chname in "$TC_CHANNEL1_NAME" "$TC_CHANNEL2_NAME"; do
		base=$(
			export FABRIC_CFG_PATH=$TC_PATH_CHANNELS
			export CORE_PEER_TLS_ENABLED=true
			export CORE_PEER_LOCALMSPID="${TC_ORG1_STACK}MSP"
			export CORE_PEER_TLS_ROOTCERT_FILE=${TC_ORG1_DATA}/msp/tlscacerts/ca-cert.pem
			export CORE_PEER_MSPCONFIGPATH=$TC_ORG1_ADMINMSP
			export CORE_PEER_ADDRESS=localhost:${TC_ORG1_P1_PORT}
			peer channel getinfo -c $chname 2>&1 | grep -v "channelCmd" | sed "s/.*Blockchain info: //" | jq -r ".height" 2>&1
		)
		commonVerify $? "failed: $out" "height of $chname at localhost:${TC_ORG1_P1_PORT} -> $base"

		for port in "$TC_ORG1_P1_PORT" "$TC_ORG1_P2_PORT" "$TC_ORG1_P3_PORT"; do
			# commonPrintf "get info for $chname on localhost:$port"
			out=$(
				export FABRIC_CFG_PATH=$TC_PATH_CHANNELS
				export CORE_PEER_TLS_ENABLED=true
				export CORE_PEER_LOCALMSPID="${TC_ORG1_STACK}MSP"
				export CORE_PEER_TLS_ROOTCERT_FILE=${TC_ORG1_DATA}/msp/tlscacerts/ca-cert.pem
				export CORE_PEER_MSPCONFIGPATH=$TC_ORG1_ADMINMSP
				export CORE_PEER_ADDRESS=localhost:${port}
				height=$(peer channel getinfo -c $chname 2>&1 | grep -v "channelCmd" | sed "s/.*Blockchain info: //" | jq -r ".height" 2>&1)
				percentage=$(( (height * 100) / base ))
				echo "$height (${percentage}%)"
			)
			commonVerify $? "failed: $out" "$chname -> localhost:${port} -> $out"
		done

		for port in "$TC_ORG2_P1_PORT" "$TC_ORG2_P2_PORT" "$TC_ORG2_P3_PORT"; do
			# commonPrintf "get info for $chname on localhost:$port"
			out=$(
				export FABRIC_CFG_PATH=$TC_PATH_CHANNELS
				export CORE_PEER_TLS_ENABLED=true
				export CORE_PEER_LOCALMSPID="${TC_ORG2_STACK}MSP"
				export CORE_PEER_TLS_ROOTCERT_FILE=${TC_ORG2_DATA}/msp/tlscacerts/ca-cert.pem
				export CORE_PEER_MSPCONFIGPATH=$TC_ORG2_ADMINMSP
				export CORE_PEER_ADDRESS=localhost:${port}
				height=$(peer channel getinfo -c $chname 2>&1 | grep -v "channelCmd" | sed "s/.*Blockchain info: //" | jq -r ".height" 2>&1)
				percentage=$(( (height * 100) / base ))
				echo "$height (${percentage}%)"
			)
			commonVerify $? "failed: $out" "$chname -> localhost:${port} -> $out"
		done


		for port in "$TC_ORG3_P1_PORT" "$TC_ORG3_P2_PORT" "$TC_ORG3_P3_PORT"; do
			# commonPrintf "get info for $chname on localhost:$port"
			out=$(
				export FABRIC_CFG_PATH=$TC_PATH_CHANNELS
				export CORE_PEER_TLS_ENABLED=true
				export CORE_PEER_LOCALMSPID="${TC_ORG3_STACK}MSP"
				export CORE_PEER_TLS_ROOTCERT_FILE=${TC_ORG3_DATA}/msp/tlscacerts/ca-cert.pem
				export CORE_PEER_MSPCONFIGPATH=$TC_ORG3_ADMINMSP
				export CORE_PEER_ADDRESS=localhost:${port}
				height=$(peer channel getinfo -c $chname 2>&1 | grep -v "channelCmd" | sed "s/.*Blockchain info: //" | jq -r ".height" 2>&1)
				percentage=$(( (height * 100) / base ))
				echo "$height (${percentage}%)"
			)
			commonVerify $? "failed: $out" "$chname -> localhost:${port} -> $out"
		done
	done
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
commonPrintf "services per node"
commonPrintf " "
for node in `docker node ls --format "{{.Hostname}}"`; do docker node ps $node --format "table{{.Node}}\t{{.Name}}\t{{.CurrentState}}"; echo; done

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

commonPrintf " "
commonPrintf "peer channel info"
commonPrintf " "
_chInfo

unset _uptime _df
