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

function _iterate() {
	local func=$1; shift
	local msg=$1; shift
	local mode=$1; shift

	for k in "$@"; do
		declare -n peer=$k
		case $mode in
			"confirm")
				commonYN "(${peer[node]}) $msg" $func "$k"
				;;
			"ignore")
				$func "$k"
				;;
			"bold")
				commonPrintfBold "(${peer[node]}) $msg"
				$func "$k"
				;;
			*)
				commonPrintf "(${peer[node]}) $msg"	
				$func "$k"
				;;
		esac
	done

	unset func msg k
}

function _glusterUmountVolume() {
	commonPrintf " "
	commonPrintf "umounting shared volume"
	commonPrintf " "
	_inner() {
		local -n peer=$1
		_out=$( ssh ${peer[node]} "sudo umount -f ${TC_PATH_WORKBENCH}" 2>&1 )
		commonPrintf "status: $? $_out"
	}
	_iterate _inner "umount volume" configm "${TC_GLUSTER_NODES[@]}"
	unset _inner _out
	commonSleep 3 "done"
}

function _glusterDisable() {
	commonPrintf " "
	commonPrintf "disabling glusterd on nodes"
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
	_iterate _inner "reset glusterd" - "${TC_GLUSTER_NODES[@]}"
	unset _inner _out
	commonSleep 3 "done"
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
	_iterate _inner "umount blockdevice" - "${TC_GLUSTER_NODES[@]}"
	unset _inner _out
	commonSleep 3 "done"
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
	_iterate _inner "mkfs.xfs" ignore "${TC_GLUSTER_NODES[@]}"

	unset _inner _out
	COMMON_FORCE=$force
	commonSleep 3 "done"
}

function _glusterMount() {
	commonPrintf " "
	commonPrintf "mounting block device"
	commonPrintf " "
	_inner() {
		local -n peer=$1
		_out=$( ssh ${peer[node]} "sudo mkdir -p -v ${peer[gmnt]}" 2>&1 )
		commonVerify $? "failed: $_out" "mkdir -p -v ${peer[gmnt]} on ${peer[node]} succeeded"
		_out=$( ssh ${peer[node]} "sudo mount ${peer[gdev]} ${peer[gmnt]}" 2>&1 )
		commonVerify $? "failed: $_out" "mount ${peer[gdev]} ${peer[gmnt]} on ${peer[node]} succeeded" 
	}
	_iterate _inner "mount" - "${TC_GLUSTER_NODES[@]}"
	unset _inner _out
	commonSleep 3 "done"
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
	_iterate _inner "systemctl enable --now glusterd" - "${TC_GLUSTER_NODES[@]}"
	unset _inner _out
	commonSleep 3 "done"
}

function _glusterProbe() {
	commonPrintf " "
	commonPrintf "adding peers to trusted pool"
	commonPrintf " "

	declare -n server1=${TC_GLUSTER_NODES[0]}
	declare -n server2=${TC_GLUSTER_NODES[1]}

	# region: probe

	_inner() {
		local -n peer=$1
		_out=$( ssh ${server1[node]} "sudo gluster peer probe ${peer[node]} " 2>&1 )
		commonVerify $? "failed: $_out" "probe succeeded: (${_out})"
	}
	_iterate _inner "gluster peer probe from ${server1[node]}" - "${TC_GLUSTER_NODES[@]:1}"
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
	_iterate _inner "gluster peer status:" - "${TC_GLUSTER_NODES[@]}"
	_inner() {
		local -n peer=$1
		_out=$( ssh ${peer[node]} "sudo gluster pool list" 2>&1 )
		commonVerify $? "failed to query pool list: $_out" "${_out}"
	}
	_iterate _inner "gluster pool list:" - "${TC_GLUSTER_NODES[@]}"

	# endregion: status

	unset _inner _out
	commonSleep 3 "done"
}

function _glusterLay() {

	# region: create vol dir

	commonPrintf " "
	commonPrintf "creating volume dir"
	commonPrintf " "
	_inner() {
		local -n peer=$1
		local dir=${peer[gmnt]}/${TC_GLUSTER_BRICK}
		_out=$( ssh ${peer[node]} "sudo mkdir -p -v $dir " 2>&1 )
		commonVerify $? "failed: $_out" "mkdir -p -v $dir on ${peer[node]} succeeded"
	}
	_iterate _inner "mkdir -p -v mountpoint/brick" - "${TC_GLUSTER_NODES[@]}"
	unset _inner _out
	commonSleep 3 "done"

	# endregion: create vol dir
	# region: create volume

	commonPrintf " "
	commonPrintf "creating volume"
	commonPrintf " "
	local servers=""
	_inner() {
		local -n peer=$1
		servers+="${peer[node]}:${peer[gmnt]}/${TC_GLUSTER_BRICK} "
	}
	_iterate _inner - ignore "${TC_GLUSTER_NODES[@]}"
	local -n manager=${TC_GLUSTER_NODES[0]}
	local cmd="sudo gluster volume create $TC_GLUSTER_BRICK disperse $TC_GLUSTER_DISPERSE redundancy $TC_GLUSTER_REDUNDANCY $servers"
	commonPrintf "${cmd}will be issued on ${manager[node]}" 
	_out=$( ssh ${manager[node]} "$cmd" 2>&1 )
	commonVerify $? "failed: $_out" "created dispersed volume: $_out"
	unset _inner _out
	commonSleep 3 "done"

	# endregion: create volume
	# region: start volume

	commonPrintf " "
	commonPrintf "starting volume"
	commonPrintf " "
	local -n manager=${TC_GLUSTER_NODES[0]}
	_out=$( ssh ${manager[node]} "sudo gluster volume start $TC_GLUSTER_BRICK" 2>&1 )
	commonVerify $? "failed: $_out" "volume started: $_out"
	commonPrintf "gluster volume info"
	_out=$( ssh ${manager[node]} "sudo gluster volume info" 2>&1 )
	commonVerify $? "failed: $_out" "volume info: $_out"
	unset _out
	commonSleep 3 "done"

	# endregion: start volume

}

function _glusterFstab() {
	commonPrintf " "
	commonPrintf "creating fstab entries and mount -a"
	commonPrintf " "
	declare -n server1=${TC_GLUSTER_NODES[0]}
	declare -n server2=${TC_GLUSTER_NODES[1]}
	_inner() {
		local -n peer=$1

		commonPrintf "removing existing entries"
		_cmd="sudo sed -i \"/^$( echo ${peer[gdev]} | sed 's/\//\\\//g' )/d\" /etc/fstab"
		_out=$(ssh ${peer[node]} "$_cmd" 2>&1 )
		commonVerify $? "failed to remove ${peer[gdev]}: $_out" "${peer[gdev]} removed"
		_cmd="sudo sed -i \"/^$( echo ${peer[node]}:${TC_GLUSTER_BRICK} | sed 's/\//\\\//g' )/d\" /etc/fstab"
		_out=$(ssh ${peer[node]} "$_cmd" 2>&1 )
		commonVerify $? "failed to remove ${peer[node]}:/${TC_GLUSTER_BRICK}: $_out" "${peer[node]}:/${TC_GLUSTER_BRICK} removed"

		commonPrintf "appending new entries"
		local backupvol=${server1[node]}
		if [[ "${peer[node]}" == "$backupvol" ]]; then
			backupvol=${server2[node]}
		fi
		local entry=""
		entry+="\n"
		entry+="#\n"
		entry+="# TC entries\n"
		entry+="#\n"
		entry+="${peer[gdev]} ${peer[gmnt]} xfs defaults 1 2\n"
		entry+="${peer[node]}:/${TC_GLUSTER_BRICK} $TC_PATH_WORKBENCH glusterfs defaults,_netdev,backupvolfile-server=${backupvol} 0 0\n"
		_out=$( ssh ${peer[node]} "sudo bash -c 'echo -e \"$entry\" >> /etc/fstab'" 2>&1 )
		commonVerify $? "failed to update fstab: $_out" "fstab update succeeded"

		commonPrintf "mkdir -p -v ${peer[node]}:${TC_PATH_WORKBENCH}"
		_out=$( ssh ${peer[node]} "sudo mkdir -p -v ${TC_PATH_WORKBENCH}" 2>&1 )
		commonVerify $? "failed: $_out" "mkdir -p -v ${TC_PATH_WORKBENCH} on ${peer[node]} succeeded"

		commonPrintf "chgrp and chmod g+rwx"
		local grp=$( id -g )
		_out=$( sudo chgrp $grp "$TC_PATH_WORKBENCH" )
		commonVerify $? $_out
		_out=$( sudo chmod g+rwx "$TC_PATH_WORKBENCH" )
		commonVerify $? $_out

		commonPrintf "mount -a at ${peer[node]}"
		_out=$( ssh ${peer[node]} "sudo mount -a" 2>&1 )
		commonVerify $? "failed mount -a: $_out" "mount -a succeeded"
	}
	_iterate _inner "update fstab and mount -a on" confirm "${TC_GLUSTER_NODES[@]}"
	unset _inner _out
	commonSleep 3 "done"
}

if [[ "$TC_EXEC_DRY" == "false" ]]; then
	_inner() {
		commonYN "umount shared wolume on peers?" _glusterUmountVolume
		commonYN "disable glusterd on peers?" _glusterDisable
		commonYN "umount gluster's dedicated devices?" _glusterUmountDevice
		commonYN "mkfs on those devices?" _glusterMkFs
		commonYN "mount filesystems?" _glusterMount
		commonYN "start and enable glusterd on peers?" _glusterEnable
		commonYN "configure the trusted pool?" _glusterProbe
		commonYN "lay the brick?" _glusterLay
		commonYN "add /etc/fstab entry and mount -a?" _glusterFstab
	}
	force=$COMMON_FORCE
	COMMON_FORCE=$TC_EXEC_SURE
	commonPrintfBold " "
	commonPrintfBold "THIS SCRIPT CAN BE DESTRUCTIVE, IT SHOULD BE RUN WITH SPECIAL CARE ON THE MAIN MANAGER NODE"
	commonPrintfBold " "
	commonYN "this is dangerous, do you want to continoue?" _inner
	COMMON_FORCE=$force
	unset _inner force
fi
