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
	commonSleep 1 "done"
}

function _glusterServerUmountVolume() {
	commonPrintf " "
	commonPrintf "umounting shared volume"
	commonPrintf " "
	_inner() {
		local -n peer=$1
		_out=$( ssh ${peer[node]} "sudo umount -f ${TC_PATH_WORKBENCH}" 2>&1 )
		commonPrintf "status: $? $_out"
	}
	commonIterate _inner "confirm|umount volume on |array|node|?" "${TC_GLUSTER_MANAGERS[@]}"
	# _inner() {
	# 	local -n peer=$1
	# 	local _cmd="sudo umount -f ${peer[mnt]}"
	# 	commonPrintf "${_cmd} will be issued on ${peer[node]}"
	# 	local _out=$( ssh ${peer[node]} "$_cmd" 2>&1 )
	# 	commonPrintf "status: $? $_out"
	# }
	# commonIterate _inner "confirm|umount volume on |array|node|?" "${TC_GLUSTER_MOUNTS[@]}"

	unset _inner _out
	commonSleep 1 "done"
}

function _glusterDisable() {
	commonPrintf " "
	commonPrintf "reseting glusterd on glusterfs servers"
	commonPrintf " "
	_inner() {
		local -n peer=$1
		_out=$( ssh ${peer[node]} "sudo systemctl stop glusterd" 2>&1 )
		commonVerify $? "failed: $_out" "halted"
		out=$( ssh ${peer[node]} "sudo systemctl disable glusterd" 2>&1 )
		commonVerify $? "failed: $_out" "disabled"
		out=$( ssh ${peer[node]} "sudo sudo rm -rf /var/lib/glusterd" 2>&1 )
		commonVerify $? "failed: $_out" "/var/lib/glusterd removed"
	}
	commonIterate _inner "confirm|reset glusterd on |array|node|?" "${TC_GLUSTER_MANAGERS[@]}" 
	unset _inner _out
	commonSleep 1 "done"
}

function _glusterUmountDevice() {
	commonPrintf " "
	commonPrintf "umounting block device"
	commonPrintf " "
	_inner() {
		local -n peer=$1
		_out=$( ssh ${peer[node]} "sudo umount ${peer[gdev]}" 2>&1 )
		commonPrintf "status: $? $_out"
	}
	commonIterate _inner "print|umount blockdevice on |array|node|?" "${TC_GLUSTER_MANAGERS[@]}" 
	unset _inner _out
	commonSleep 1 "done"
}

function _glusterMkFs() {
	local force=$COMMON_FORCE
	COMMON_FORCE=$TC_EXEC_SURE

	commonPrintfBold " "
	commonPrintfBold "making filesystem on block devices: REMEMBER, THIS IS HOT CAKE!"
	commonPrintfBold " "
	_inner() {
		local -n peer=$1
		_innerInner() {
			_out=$( ssh ${peer[node]} "sudo mkfs.xfs -f -i size=512 ${peer[gdev]}" 2>&1 )
			commonVerify $? "failed: $_out" "succeeded: $_out"
		}
		commonYN "mkfs.xfs on ${peer[node]}:${peer[gdev]}" _innerInner
		unset _innerInner
	}
	commonIterate _inner "-|mkfs.xfs on |array|node|" "${TC_GLUSTER_MANAGERS[@]}" 

	unset _inner _out
	COMMON_FORCE=$force
	commonSleep 1 "done"
}

function _glusterServerMount() {
	commonPrintf " "
	commonPrintf "mounting block device"
	commonPrintf " "
	_inner() {
		local -n peer=$1
		_out=$( ssh ${peer[node]} "sudo mkdir -p -v ${peer[gmnt]}" 2>&1 )
		commonVerify $? "failed: $_out" "mkdir -p -v ${peer[gmnt]} on ${peer[node]} succeeded"
		_out=$( ssh ${peer[node]} "sudo mount ${peer[gdev]} ${peer[gmnt]}" 2>&1 )
		commonVerify $? "failed: $_out" "mount ${peer[gdev]} ${peer[gmnt]} on ${peer[node]} succeeded"
		if [ ! -z ${peer[wal]} ]; then
			_out=$( ssh ${peer[node]} "sudo mkdir -p -v ${peer[wal]}" 2>&1 )
			commonVerify $? "failed: $_out" "sudo mkdir -p -v ${peer[wal]} on ${peer[node]} succeeded" 
		fi
	}
	commonIterate _inner "print|mount on |array|node|:" "${TC_GLUSTER_MANAGERS[@]}" 
	unset _inner _out
	commonSleep 1 "done"
}

function _glusterEnable() {
	commonPrintf " "
	commonPrintf "enabling glusterd on peers"
	commonPrintf " "
	_inner() {
		local -n peer=$1
		_out=$( ssh ${peer[node]} "sudo systemctl enable --now glusterd " 2>&1 )
		commonVerify $? "failed: $_out" "enabled (${_out})"
	}
	commonIterate _inner "print|systemctl enable --now glusterd on |array|node|:" "${TC_GLUSTER_MANAGERS[@]}" 
	unset _inner _out
	commonSleep 1 "done"
}

function _glusterProbe() {
	commonPrintf " "
	commonPrintf "adding peers to trusted pool"
	commonPrintf " "

	declare -n server1=${TC_GLUSTER_MANAGERS[0]}
	declare -n server2=${TC_GLUSTER_MANAGERS[1]}

	# region: probe

	_inner() {
		local -n peer=$1
		_out=$( ssh ${server1[node]} "sudo gluster peer probe ${peer[node]} " 2>&1 )
		commonVerify $? "failed: $_out" "probe succeeded: (${_out})"
	}
	commonIterate _inner "print|gluster peer probe from ${server1[node]} to |array|node|:" "${TC_GLUSTER_MANAGERS[@]:1}" 
	commonPrintf "(${server1[node]}) gluster peer probe from ${server2[node]} "
	_out=$( ssh ${server2[node]} "sudo gluster peer probe ${server1[node]}" 2>&1 )
	commonVerify $? "failed: $_out" "probe succeeded: (${_out})"

	# endregion: probe
	# region: status

	_inner() {
		local -n peer=$1
		_out=$( ssh ${peer[node]} "sudo gluster peer status" 2>&1 )
		commonVerify $? "failed to query status: $_out" "${_out}"
	}
	commonIterate _inner "print|gluster peer status on |array|node|:" "${TC_GLUSTER_MANAGERS[@]}" 
	_inner() {
		local -n peer=$1
		_out=$( ssh ${peer[node]} "sudo gluster pool list" 2>&1 )
		commonVerify $? "failed to query pool list: $_out" "${_out}"
	}
	commonIterate _inner "print|gluster pool list on |array|node|:" "${TC_GLUSTER_MANAGERS[@]}" 

	# endregion: status

	unset _inner _out
	commonSleep 1 "done"
}

function _glusterLay() {

	# region: create vol dir

	commonPrintf " "
	commonPrintf "creating volume dir"
	commonPrintf " "
	_inner() {
		local -n peer=$1
		local dir=${peer[gmnt]}/${TC_GLUSTER_VOLUME}
		_out=$( ssh ${peer[node]} "sudo mkdir -p -v $dir " 2>&1 )
		commonVerify $? "failed: $_out" "mkdir -p -v $dir on ${peer[node]} succeeded"
	}
	commonIterate _inner "print|mkdir -p -v volume/bricks |array|node|:" "${TC_GLUSTER_MANAGERS[@]}" 
	unset _inner _out
	commonSleep 1 "done"

	# endregion: create vol dir
	# region: create volume

	commonPrintf " "
	commonPrintf "creating volume"
	commonPrintf " "
	local servers=""
	_inner() {
		local -n peer=$1
		servers+="${peer[node]}:${peer[gmnt]}/${TC_GLUSTER_VOLUME} "
	}
	commonIterate _inner "||||" "${TC_GLUSTER_MANAGERS[@]}" 
	local -n manager=${TC_GLUSTER_MANAGERS[0]}
	local cmd="sudo gluster volume create $TC_GLUSTER_VOLUME disperse $TC_GLUSTER_DISPERSE redundancy $TC_GLUSTER_REDUNDANCY $servers"
	commonPrintf "${cmd}will be issued on ${manager[node]}" 
	_out=$( ssh ${manager[node]} "$cmd" 2>&1 )
	commonVerify $? "failed: $_out" "created dispersed volume: $_out"
	unset _inner _out
	commonSleep 1 "done"

	# endregion: create volume
	# region: start volume

	commonPrintf " "
	commonPrintf "starting volume"
	commonPrintf " "
	local -n manager=${TC_GLUSTER_MANAGERS[0]}
	_out=$( ssh ${manager[node]} "sudo gluster volume start $TC_GLUSTER_VOLUME" 2>&1 )
	commonVerify $? "failed: $_out" "volume started: $_out"
	commonPrintf "gluster volume info"
	_out=$( ssh ${manager[node]} "sudo gluster volume info" 2>&1 )
	commonVerify $? "failed: $_out" "volume info: $_out"
	unset _out
	commonSleep 1 "done"

	# endregion: start volume
	# region: auth.allow

	commonPrintf " "
	commonPrintf "auth.allow"
	commonPrintf " "

	local servers="/("
	_inner() {
		local -n peer=$1
		servers+="${peer[ip]}|"
	}
	commonIterate _inner "||||" "${TC_GLUSTER_MANAGERS[@]}"
	servers="${servers%|})"

	servers+=",/${TC_ORG1_STACK}(${TC_SWARM_WORKER1[ip]}),/${TC_ORG2_STACK}(${TC_SWARM_WORKER1[ip]}),/${TC_ORG3_STACK}(${TC_SWARM_WORKER1[ip]})"
	# servers+=",/peerOrganizations/endorsers(${TC_SWARM_WORKER1[ip]}|${TC_SWARM_WORKER2[ip]}),/peerOrganizations/supernodes(${TC_SWARM_WORKER1[ip]}|${TC_SWARM_WORKER2[ip]}),/peerOrganizations/masternodes(${TC_SWARM_WORKER1[ip]}|${TC_SWARM_WORKER2[ip]})"
	# _inner() {
	# 	local -n peer=$1
	# 	local mnt=$( echo ${peer[mnt]} | sed s+$TC_PATH_WORKBENCH++ )
	# 	servers+=",${mnt}(${peer[ip]})"
	# }
	# commonIterate _inner "||||" "${TC_GLUSTER_MOUNTS[@]}"
	commonPrintf "$servers"

	local -n manager=${TC_GLUSTER_MANAGERS[0]}
	_cmd="sudo gluster volume set $TC_GLUSTER_VOLUME auth.allow \"$servers\""
	_out=$( ssh ${manager[node]} "$_cmd" 2>&1 )
	commonVerify $? "$_cmd failed: $_out" "$_cmd succeeded: $_out"
	_cmd="sudo gluster volume info"
	_out=$( ssh ${manager[node]} "$_cmd" 2>&1 )
	commonVerify $? "$_cmd failed: $_out" "$_cmd succeeded: $_out"
	unset _inner _out _cmd
	commonSleep 1 "done"

	# endregion: auth.allow

}

function _glusterServerFstab() {
	commonPrintf " "
	commonPrintf "creating fstab entries and mount -a"
	commonPrintf " "
	# declare -n server1=${TC_GLUSTER_MANAGERS[0]}
	# declare -n server2=${TC_GLUSTER_MANAGERS[1]}

	# region: servers

	_inner() {
		declare -n peer=$1
		local backup=${TC_SWARM_MANAGER1[node]}
		if [[ "${peer[node]}" == "$backup" ]]; then
			backup=${TC_SWARM_MANAGER3[node]}
		fi 

		commonPrintf "removing existing entries"
		_cmd="sudo sed -i \"/^$( echo ${peer[gdev]} | sed 's/\//\\\//g' )/d\" /etc/fstab"
		_out=$(ssh ${peer[node]} "$_cmd" 2>&1 )
		commonVerify $? "failed to remove ${peer[gdev]}: $_out" "${peer[gdev]} removed"
		_cmd="sudo sed -i \"/^$( echo ${peer[node]}:/${TC_GLUSTER_VOLUME} | sed 's/\//\\\//g' )/d\" /etc/fstab"
		_out=$(ssh ${peer[node]} "$_cmd" 2>&1 )
		commonVerify $? "failed to remove ${peer[node]}:/ ->  $_out" "${peer[node]}:/${TC_GLUSTER_VOLUME} removed"
		commonPrintf "removing consecutive empty lines"
		_cmd="sudo sed -i '/^$/N;/^\n$/D' /etc/fstab"
		_out=$(ssh ${peer[node]} "$_cmd" 2>&1 )
		commonVerify $? "failed to remove consecutive empty lines: $_out" "consecutive empty lines are removed"

		commonPrintf "appending new entries"
		local entry=""
		commonPrintf "backupvolfile-server=${backup}"
		entry+="${peer[gdev]} ${peer[gmnt]} xfs defaults,noatime,nodiratime,allocsize=64m 1 2\n"
		entry+="${peer[node]}:/${TC_GLUSTER_VOLUME} $TC_PATH_WORKBENCH glusterfs defaults,_netdev,backupvolfile-server=${backup} 0 0\n"
		_out=$( ssh ${peer[node]} "sudo bash -c 'echo -e \"$entry\" >> /etc/fstab'" 2>&1 )
		commonVerify $? "failed to update fstab: $_out" "fstab update succeeded"

		commonPrintf "mkdir -p -v ${peer[node]}:${TC_PATH_WORKBENCH}"
		_out=$( ssh ${peer[node]} "sudo mkdir -p -v ${TC_PATH_WORKBENCH}" 2>&1 )
		commonVerify $? "failed: $_out" "mkdir -p -v ${TC_PATH_WORKBENCH} on ${peer[node]} succeeded"

		commonPrintf "mount -a at ${peer[node]}"
		_out=$( ssh ${peer[node]} "sudo mount -a" 2>&1 )
		commonVerify $? "failed mount -a: $_out" "mount -a succeeded"

		# commonPrintf "chown -R $TC_USER_NAME:$TC_USER_GROUP"
		# _out=$( ssh ${peer[node]} "sudo chown $TC_USER_NAME:$TC_USER_GROUP ${TC_PATH_WORKBENCH}" 2>&1 )
		# commonVerify $? "failed: $_out" "chown $TC_USER_NAME:$TC_USER_GROUP ${TC_PATH_WORKBENCH} succeeded"
		# _out=$( sudo chmod g+rwx "$TC_PATH_WORKBENCH" )
		# commonVerify $? $_out
	}
	commonIterate _inner "confirm|update fstab and mount -a on server |array|node|?" "${TC_GLUSTER_MANAGERS[@]}"
	# unset backupvol

	# endregion: servers

	commonPrintf "chgrp and chmod g+rwx"
	local grp=$( id -g )
	_out=$( sudo chgrp $grp "$TC_PATH_WORKBENCH" )
	commonVerify $? $_out
	_out=$( sudo chmod g+rwx "$TC_PATH_WORKBENCH" )
	commonVerify $? $_out

	unset _inner _out
	commonSleep 1 "done"
}

if [[ "$TC_EXEC_DRY" == "false" ]]; then
	_inner() {
		commonYN "umount shared wolume on glusterfs clients?" _glusterClientUmountVolume
		commonYN "umount shared wolume on glusterfs servers?" _glusterServerUmountVolume
		commonYN "reset glusterd on glusterfs servers?" _glusterDisable
		commonYN "umount gluster's dedicated devices?" _glusterUmountDevice
		commonYN "mkfs on those devices?" _glusterMkFs
		commonYN "mount filesystems?" _glusterServerMount
		commonYN "start and enable glusterd on peers?" _glusterEnable
		commonYN "configure the trusted pool?" _glusterProbe
		commonYN "lay the brick?" _glusterLay
		commonYN "add /etc/fstab entry and mount -a?" _glusterServerFstab
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
