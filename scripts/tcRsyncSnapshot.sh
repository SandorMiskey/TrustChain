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
# region: mainnet specific config

export TC_BACKUP_PATH=/srv/TrustChain_Backup
export identity=/home/trustchain/.ssh/tc2_inner_circle

# endregion: mainnet specific config

function _tc() {
	commonPrintf " "
	commonPrintf "${TC_PATH_WORKBENCH} -> $TC_BACKUP_PATH"
	commonPrintf " "
	sudo rsync -avhP --delete ${TC_PATH_WORKBENCH} $TC_BACKUP_PATH
}

function _wal() {

	declare -A o1=( [node]=$TC_ORDERER1_O1_WORKER [src]=$TC_ORDERER1_O1_WAL [dest]="${TC_BACKUP_PATH}/${TC_ORDERER1_O1_NAME}_wal" )
	declare -A o2=( [node]=$TC_ORDERER1_O2_WORKER [src]=$TC_ORDERER1_O2_WAL [dest]="${TC_BACKUP_PATH}/${TC_ORDERER1_O2_NAME}_wal" )
	declare -A o3=( [node]=$TC_ORDERER1_O3_WORKER [src]=$TC_ORDERER1_O3_WAL [dest]="${TC_BACKUP_PATH}/${TC_ORDERER1_O3_NAME}_wal" )
	export orderers=("o1" "o2" "o3")

	_inner() {
		local -n peer=$1

		commonPrintf " "
		commonPrintf "${peer[node]}:${peer[src]} -> ${peer[dest]}"
		commonPrintf " "

		out=$( ssh ${peer[node]} "sudo mkdir -p ${peer[dest]}" )
		commonVerify $? "failed: $out"
		unset out

		ssh ${peer[node]} "sudo rsync -avhP --delete ${peer[src]} ${peer[dest]}"
		commonVerify $? "failed to snapshot"
	}
	commonIterate _inner "ignore||||" "${orderers[@]}"
}

if [[ "$TC_EXEC_DRY" == "false" ]]; then
	_inner() {
		_tc
		_wal
	}
	force=$COMMON_FORCE
	COMMON_FORCE=$TC_EXEC_SURE
	commonPrintfBold " "
	commonPrintfBold "THIS SCRIPT CAN BE DESTRUCTIVE, IT SHOULD BE RUN WITH SPECIAL CARE ON THE MAIN MANAGER NODE"
	commonPrintfBold " "
	commonYN "this is dangerous, do you want to continoue?" _inner
	COMMON_FORCE=$force
	unset _inner force

	_me=$( basename "$0" )
	_prefix="$COMMON_PREFIX"
	COMMON_PREFIX="===>>> "
	commonPrintfBold " "
	commonPrintfBold "ALL DONE! IF THIS IS FINAL, ISSUE THE FOLLOWING COMMAND: sudo chmod a-x ${TC_PATH_SCRIPTS}/${_me}"
	commonPrintfBold " "
	COMMON_PREFIX="_prefix"
	unset _prefix _me
fi
