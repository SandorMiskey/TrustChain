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

function _glusterClientUmountVolume() {
	commonPrintf " "
	commonPrintf "umounting shared volume on clients"
	commonPrintf " "
	_inner() {
		local -n peer=$1
		local _cmd="sudo umount -f ${peer[mnt]}"
		commonPrintf "${_cmd} will be issued on ${peer[node]}"
		local _out=$( ssh ${peer[node]} "$_cmd" 2>&1 )
		commonPrintf "status: $? $_out"
	}
	commonIterate _inner "confirm|umount volume on |array|node|?" "${TC_GLUSTER_MOUNTS[@]}"

	unset _inner
	commonSleep 3 "done"
}

function _glusterClientFstabClear() {
	commonPrintf " "
	commonPrintf "removing Gluster entries and consecutive empty lines"
	commonPrintf " "

	_inner() {
		local -n peer=$1

		_inInner() {
			local -n server=$1

			# commonPrintf "removing ${server[node]}:/${TC_GLUSTER_BRICK} entries"
			_cmd="sudo sed -i \"/^$( echo ${server[node]}:/${TC_GLUSTER_BRICK} | sed 's/\//\\\//g' )/d\" /etc/fstab"
			_out=$(ssh ${peer[node]} "$_cmd" 2>&1 )
			commonVerify $? "failed to remove ${peer[node]}:/${TC_GLUSTER_BRICK}: $_out" "${server[node]}:/${TC_GLUSTER_BRICK} removed"

			unset _cmd _out
		}
		commonIterate _inInner "print|removing |array|node| entries on ${peer[node]}" "${TC_GLUSTER_MANAGERS[@]}"

		# commonPrintf "removing consecutive empty lines"
		_cmd="sudo sed -i '/^$/N;/^\n$/D' /etc/fstab"
		_out=$(ssh ${peer[node]} "$_cmd" 2>&1 )
		commonVerify $? "failed to remove consecutive empty lines: $_out" "consecutive empty lines are removed"

		unset _cmd _out _inInner
	}
	commonIterate _inner "confirm|update fstab and mount -a on cient |array|node|?" "${TC_SWARM_WORKERS[@]}"

	unset peer _inner
	commonSleep 3 "done"
}

function _glusterClientFstab() {
	commonPrintf " "
	commonPrintf "creating fstab entries and mount -a"
	commonPrintf " "
	declare -n server1=${TC_GLUSTER_MANAGERS[0]}
	declare -n server2=${TC_GLUSTER_MANAGERS[1]}


	_inner() {
		local -n peer=$1
		local _path=$( echo ${peer[mnt]} | sed s+$TC_PATH_WORKBENCH++ )
		local _peer=${peer[node]}

		local _entry+="${server1[node]}:/${TC_GLUSTER_BRICK}${_path} ${peer[mnt]} glusterfs defaults,_netdev,backupvolfile-server=${server2[node]} 0 0\n"
		commonPrintf "appending new entry on ${_peer}: $_entry"
		_out=$( ssh ${_peer} "sudo bash -c 'echo -e \"$_entry\" >> /etc/fstab'" 2>&1 )
		commonVerify $? "failed to update fstab: $_out" "fstab update succeeded"

		commonPrintf "mkdir -p -v ${_peer}:${peer[mnt]}"
		_out=$( ssh ${_peer} "sudo mkdir -p -v ${peer[mnt]}" 2>&1 )
		commonVerify $? "failed: $_out" "mkdir -p -v ${peer[mnt]} on ${_peer} succeeded"

		commonPrintf "mount -a at ${_peer}"
		_out=$( ssh ${peer[node]} "sudo mount -a" 2>&1 )
		commonVerify $? "failed mount -a: $_out" "mount -a succeeded"

		unset _out
		# sudo mount -t glusterfs tc2-test-manager1:/TrustChain/organizations/peerOrganizations/supernodes /srv/TrustChain/organizations/peerOrganizations/supernodes
	}
	commonIterate _inner "confirm|update fstab and mount -a on client |array|node|?" "${TC_GLUSTER_MOUNTS[@]}"

	unset _inner _out
	commonSleep 3 "done"
}

if [[ "$TC_EXEC_DRY" == "false" ]]; then
	commonYN "umount shared wolume on glusterfs clients?" _glusterClientUmountVolume
	commonYN "remove Gluster entries and consecutive empty lines?" _glusterClientFstabClear
	commonYN "add /etc/fstab entry and mount -a?" _glusterClientFstab

	_me=$( basename "$0" )
	_prefix="$COMMON_PREFIX"
	COMMON_PREFIX="===>>> "
	commonPrintfBold " "
	commonPrintfBold "ALL DONE! IF THIS IS FINAL, ISSUE THE FOLLOWING COMMAND: sudo chmod a-x ${TC_PATH_SCRIPTS}/${_me}"
	commonPrintfBold " "
	COMMON_PREFIX="_prefix"
	unset _prefix _me
fi
