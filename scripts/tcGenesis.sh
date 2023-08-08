#!/bin/bash

#
# Copyright TE-FOOD International GmbH., All Rights Reserved
#

# region: load config

[[ ${TC_PATH_RC:-"unset"} == "unset" ]] && TC_PATH_RC=${TC_PATH_BASE}/scripts/commonFuncs.sh
if [ ! -f  $TC_PATH_RC ]; then
	echo "=> TC_PATH_RC ($TC_PATH_RC) not found, make sure proper path is set or you execute this from the repo's 'scrips' directory!"
	exit 1
fi
source $TC_PATH_RC

# commonPrintfBold "note that certain environment variables must be set to work properly!"
# commonContinue "have you reloded ${TC_PATH_BASE}/.env?"

if [[ ${TC_PATH_SCRIPTS:-"unset"} == "unset" ]]; then
	commonVerify 1 "TC_PATH_SCRIPTS is unset"
fi
commonPP $TC_PATH_SCRIPTS

# endregion: config
# region: strartup warning

commonPrintfBold " "
commonPrintfBold "THIS SCRIPT CAN BE DESTRUCTIVE, IT SHOULD BE RUN WITH SPECIAL CARE ON THE MAIN MANAGER NODE"
commonPrintfBold " "
force=$COMMON_FORCE
COMMON_FORCE=$TC_EXEC_SURE
commonContinue "do you want to continue?"
COMMON_FORCE=$force
unset force

# endregion: warning
# region: check for dependencies and versions

_FabricVersions() {
	local required_version=$TC_DEPS_FABRIC
	local cryptogen_version=$( cryptogen version | grep Version: | sed 's/.*Version: //i' | sed 's/^v//i' )
	local configtxgen_version=$( configtxgen -version | grep Version: | sed 's/.*Version: //i' | sed 's/^v//i' )

	commonPrintf "required fabric binary version: $required_version"
	commonPrintf "installed cryptogen version: $cryptogen_version"
	commonPrintf "installed configtxgen version: $configtxgen_version"

	if [ "$cryptogen_version" != "$required_version" ] || [ "$configtxgen_version" != "$required_version" ]; then
		commonVerify 1  "versions do not match required"
	fi 
}
_CAVersions() {
	local required_version=$TC_DEPS_CA
	local actual_version=$( fabric-ca-client version | grep Version: | sed 's/.*Version: //' | sed 's/^v//i' )

	commonPrintf "required ca version: $required_version"
	commonPrintf "installed fabric-ca-client version: $actual_version"

	if [ "$actual_version" != "$required_version" ]; then
		commonVerify 1  "versions do not match required"
	fi 
}

commonYN "search for dependencies?" commonDeps ${COMMON_PREREQS[@]}
commonYN "validate fabric binary versions?" _FabricVersions
commonYN "validate ca binary versions?" _CAVersions

# endregion: dependencies and versions
# region: remove config and persistent data

_WipePersistent() {


	_wipe() {
		commonPrintf "removing $TC_PATH_LOCALWORKBENCH symlink to $TC_PATH_WORKBENCH"
		err=$( sudo rm -f "$TC_PATH_LOCALWORKBENCH" )
		commonVerify $? $err

		if [ -d "$TC_PATH_WORKBENCH" ]; then
			commonPrintf "$TC_PATH_WORKBENCH exists"
			commonPrintf "removing ${TC_PATH_WORKBENCH}/*"
			# err=$( sudo rm -rf "${TC_PATH_WORKBENCH}/*" )
			err=$( sudo find "$TC_PATH_WORKBENCH" -mindepth 1 -delete )
			commonVerify $? $err
		else
			commonPrintf "$TC_PATH_WORKBENCH doesn't exists"
			commonPrintf "mkdir -p -v $TC_PATH_WORKBENCH" 
			err=$( sudo mkdir -p -v "$TC_PATH_WORKBENCH" )
			commonVerify $? $err
		fi

		commonPrintf "chgrp and chmod g+rwx"
		local grp=$( id -g )
		err=$( sudo chgrp $grp "$TC_PATH_WORKBENCH" )
		commonVerify $? $err
		err=$( sudo chmod g+rwx "$TC_PATH_WORKBENCH" )
		commonVerify $? $err

		commonPrintf "symlink $TC_PATH_LOCALWORKBENCH -> $TC_PATH_WORKBENCH"
		err=$( ln -s "$TC_PATH_WORKBENCH" "$TC_PATH_LOCALWORKBENCH" )
		commonVerify $? $err
		unset err
	}

	local force=$COMMON_FORCE
	COMMON_FORCE=$TC_EXEC_SURE
	commonPrintfBold " "
	commonPrintfBold "THIS WILL WIPE ALL PERSISTENT DATA OF YOURS..."
	commonPrintfBold " "
	commonYN "SURE?" _wipe
	COMMON_FORCE=$force
}

[[ "$TC_EXEC_DRY" == false ]] && commonYN "wipe persistent data?" _WipePersistent

# endregion: remove config and persistent data
# region: create user and group

# _prepareUser() {
# 	commonPrintf " "
# 	commonPrintf "del/add user and group, whach out: no error handling here!"
# 	commonPrintf

# 	_inner() {
# 		local -n peer=$1
# 		commonPrintf "delete user and group"
# 		ssh ${peer[node]} "export LC_ALL=C.UTF-8; sudo deluser $TC_USER_NAME"
# 		ssh ${peer[node]} "export LC_ALL=C.UTF-8; sudo delgroup $TC_USER_GROUP"
# 		commonPrintf "create group"
# 		ssh ${peer[node]} "export LC_ALL=C.UTF-8; sudo addgroup --gid $TC_USER_GID $TC_USER_GROUP"
# 		commonPrintf "create user and add to docker group"
# 		ssh ${peer[node]} "export LC_ALL=C.UTF-8; sudo adduser --uid $TC_USER_UID --gid $TC_USER_UID --shell /usr/sbin/nologin --home $TC_PATH_WORKBENCH --gecos "" --no-create-home --disabled-login --quiet $TC_USER_NAME"
# 		ssh ${peer[node]} "export LC_ALL=C.UTF-8; sudo usermod -aG docker $TC_USER_NAME"
# 		ssh ${peer[node]} "export LC_ALL=C.UTF-8; sudo usermod -aG $TC_USER_GROUP $( whoami )"
# 	}
# 	commonIterate _inner "confirm|recreate user ($TC_USER_NAME) and group ($TC_USER_GROUP) on |array|node|?" "${TC_SWARM_WORKERS[@]}" "${TC_SWARM_MANAGERS[@]}"
# }

# [[ "$TC_EXEC_DRY" == false ]] && _prepareUser

# endregion: create user and group
# region: reset glusterd

[[ "$TC_EXEC_DRY" == false ]] && commonYN "reset cluster filesystem?" ${TC_PATH_SCRIPTS}/tcGlusterServers.sh

# endregion: reset glusterd
# region: process templates

_templates() {
	commonPrintf " "
	commonPrintf "processing templates:"
	commonPrintf " "
	for template in $( find $TC_PATH_TEMPLATES/* ! -name '.*' -print ); do
		target=$( commonSetvar $template )
		target=$( echo $target | sed s+$TC_PATH_TEMPLATES+$TC_PATH_WORKBENCH+ )

		local templateRel=$( echo "$template" | sed s+${TC_PATH_BASE}/++g )
		local targetRel=$( echo "$target" | sed s+${TC_PATH_BASE}/++g | sed s+_nope$++g )
		if [[ -d $template ]]; then
			commonPrintf "mkdir: $templateRel -> $targetRel"
			err=$( mkdir -p "$target" )
			commonVerify $? $err
		elif [[ $template == *_nope ]]; then
			target=$( echo "$target" | sed s+_nope$++g )
			commonPrintfBold "rename and cp: $templateRel -> $targetRel" "${COMMON_BLUE}%s\n${COMMON_NORM}"
			cp $template $target
		elif [[ $(file --mime-encoding -b $template) == "binary" ]]; then
			commonPrintf "binary or empty: $templateRel -> $targetRel" "${COMMON_RED}%s\n${COMMON_NORM}"
			cp $template $target
		elif [[ -f $template ]]; then
			commonPrintf "processed: $templateRel -> $targetRel"
			( echo "cat <<EOF" ; cat $template ; echo EOF ) | sh > $target
			commonVerify $? "unable to process $templateRel"
		else
			commonVerify 1 "$templateRel is not valid"
		fi
	done

	commonPrintf " "
	commonPrintf "unpacking chaincode templates"
	commonPrintf " "
	for template in $( find $TC_PATH_CHAINCODE/*tgz -print ); do 
		commonPrintf "working on $template"
		local out=$( tar -C "${TC_PATH_CHAINCODE}/" -xzvf $template 2>&1 )
		commonVerify $? "failed: $out" "$out"
	done

	commonPrintf " "
	commonPrintf "unpacking private docker repo"
	commonPrintf " "
	out=$( tar -C ${TC_COMMON1_REGISTRY_DATA}/ -xzvf ${TC_COMMON1_REGISTRY_DATA}/docker.tgz  )
	commonVerify $? "failed: $out" "$out"
	out=$( rm ${TC_COMMON1_REGISTRY_DATA}/docker.tgz  )
	commonVerify $? "failed: $out" "$out"

	# commonPrintf " "
	# commonPrintf "chown -R $TC_USER_NAME:$TC_USER_GROUP $TC_PATH_WORKBENCH"
	# commonPrintg
	# sudo chown -R $TC_USER_NAME:$TC_USER_GROUP $TC_PATH_WORKBENCH 

	unset out
	unset templates
	unset target
}

[[ "$TC_EXEC_DRY" == false ]] && commonYN "process templates?" _templates 

# endregion: process templates
# region: swarm init

[[ "$TC_EXEC_DRY" == false ]] && commonYN "prune and reset docker swarm?" ${TC_PATH_SCRIPTS}/tcSwarm.sh

# endregion: swarm init
# region: tls ca and file sharing

_TLS1() (

	local out

	# region: bootstrap tls ca

	_bootstrap() {
		commonPrintf "bootstrapping >>>${TC_COMMON1_STACK}<<<"
		${TC_PATH_SCRIPTS}/tcBootstrap.sh -m up -s ${TC_COMMON1_STACK}
		commonVerify $? "failed!"
	}
	commonYN "bootstrap ${TC_COMMON1_STACK}?" _bootstrap

	# endregion: bootstrap
	# region: set fabric-ca-client

	_setClient() {
		export FABRIC_CA_CLIENT_TLS_CERTFILES=${TC_COMMON1_C1_HOME}/ca-cert.pem
		export FABRIC_CA_CLIENT_HOME=${TC_COMMON1_C1_DATA}/${TC_COMMON1_C1_ADMIN}
	}

	# endregion: set fabric-ca-client
	# region: enroll tls ca admin

	_enrollAdmin() {
		commonPrintf "enrolling >>>${TC_COMMON1_C1_ADMIN}<<< with >>>$TC_COMMON1_C1_FQDN<<<"
		out=$(
			_setClient
		 	fabric-ca-client enroll -u https://${TC_COMMON1_C1_ADMIN}:${TC_COMMON1_C1_ADMINPW}@0.0.0.0:${TC_COMMON1_C1_PORT} 2>&1
		)
		commonVerify $? "failed to enroll tls admin: $out" "$out"
	}
	commonYN "enroll >>${TC_COMMON1_C1_ADMIN}<<< with >>>$TC_COMMON1_C1_FQDN<<<?" _enrollAdmin

	# endregion: enroll tls ca admin
	# region: register orderer1

	_registerOrderer1() {
		commonPrintf "registering >>>$TC_ORDERER1_ADMIN<<< orderers with >>>$TC_COMMON1_C1_FQDN<<<" 
		out=$(
			_setClient
			fabric-ca-client register --id.name $TC_ORDERER1_ADMIN --id.secret $TC_ORDERER1_ADMINPW --id.type admin --id.attrs "$TC_ORDERER1_ADMINATRS" -u https://0.0.0.0:${TC_COMMON1_C1_PORT} 2>&1
		)
		commonVerify $? "failed to register ${TC_ORDERER1_ADMIN}: $out" "$out"

		commonPrintf "registering >>>$TC_ORDERER1_DOMAIN<<< orderers with >>>$TC_COMMON1_C1_FQDN<<<" 
		out=$(
			_setClient
			fabric-ca-client register --id.name $TC_ORDERER1_O1_TLS_NAME --id.secret $TC_ORDERER1_O1_TLS_PW --id.type orderer -u https://0.0.0.0:${TC_COMMON1_C1_PORT}  2>&1
		)
		commonVerify $? "failed to register tls identity: $out" "$out"
		out=$(
			_setClient
			fabric-ca-client register --id.name $TC_ORDERER1_O2_TLS_NAME --id.secret $TC_ORDERER1_O2_TLS_PW --id.type orderer -u https://0.0.0.0:${TC_COMMON1_C1_PORT}  2>&1
		)
		commonVerify $? "failed to register tls identity: $out" "$out"
		out=$(
			_setClient
			fabric-ca-client register --id.name $TC_ORDERER1_O3_TLS_NAME --id.secret $TC_ORDERER1_O3_TLS_PW --id.type orderer -u https://0.0.0.0:${TC_COMMON1_C1_PORT}  2>&1
		)
		commonVerify $? "failed to register tls identity: $out" "$out"
	}
	commonYN "registering >>>$TC_ORDERER1_DOMAIN<<< orderers with >>>$TC_COMMON1_C1_FQDN<<<?" _registerOrderer1

	# endregion: register orderer1
	# region: registering org1 peers

	_registerOrg1() {
		commonPrintf "registering >>>$TC_ORG1_DOMAIN<<< peers and gw with >>>$TC_COMMON1_C1_FQDN<<<" 
		out=$(
			_setClient
			fabric-ca-client register --id.name $TC_ORG1_G1_TLS_NAME --id.secret $TC_ORG1_G1_TLS_PW --id.type client -u https://0.0.0.0:${TC_COMMON1_C1_PORT}  2>&1
		)
		commonVerify $? "failed to register tls identity: $out" "$out"
		out=$(
			_setClient
			fabric-ca-client register --id.name $TC_ORG1_P1_TLS_NAME --id.secret $TC_ORG1_P1_TLS_PW --id.type peer -u https://0.0.0.0:${TC_COMMON1_C1_PORT}  2>&1
		)
		commonVerify $? "failed to register tls identity: $out" "$out"
		out=$(
			_setClient
			fabric-ca-client register --id.name $TC_ORG1_P2_TLS_NAME --id.secret $TC_ORG1_P2_TLS_PW --id.type peer -u https://0.0.0.0:${TC_COMMON1_C1_PORT}  2>&1
		)
		commonVerify $? "failed to register tls identity: $out" "$out"
		out=$(
			_setClient
			fabric-ca-client register --id.name $TC_ORG1_P3_TLS_NAME --id.secret $TC_ORG1_P3_TLS_PW --id.type peer -u https://0.0.0.0:${TC_COMMON1_C1_PORT}  2>&1
		)
		commonVerify $? "failed to register tls identity: $out" "$out"
	}
	commonYN "register >>>$TC_ORG1_DOMAIN<<< peers and gw with >>>$TC_COMMON1_C1_FQDN<<<?" _registerOrg1

	# endregion: registering org1 peers
	# region: registering org2 peers

	_registerOrg2() {
		commonPrintf "registering >>>$TC_ORG2_DOMAIN<<< peers with >>>$TC_COMMON1_C1_FQDN<<<" 
		out=$(
			_setClient
			fabric-ca-client register --id.name $TC_ORG2_P1_TLS_NAME --id.secret $TC_ORG2_P1_TLS_PW --id.type peer -u https://0.0.0.0:${TC_COMMON1_C1_PORT}  2>&1
		)
		commonVerify $? "failed to register tls identity: $out" "$out"
		out=$(
			_setClient
			fabric-ca-client register --id.name $TC_ORG2_P2_TLS_NAME --id.secret $TC_ORG2_P2_TLS_PW --id.type peer -u https://0.0.0.0:${TC_COMMON1_C1_PORT}  2>&1
		)
		commonVerify $? "failed to register tls identity: $out" "$out"
		out=$(
			_setClient
			fabric-ca-client register --id.name $TC_ORG2_P3_TLS_NAME --id.secret $TC_ORG2_P3_TLS_PW --id.type peer -u https://0.0.0.0:${TC_COMMON1_C1_PORT}  2>&1
		)
		commonVerify $? "failed to register tls identity: $out" "$out"
	}
	commonYN "register >>>$TC_ORG2_DOMAIN<<< peers with >>>$TC_COMMON1_C1_FQDN<<<?" _registerOrg2

	# endregion: registering org2 peers
	# region: registering org3 peers

	_registerOrg3() {
		commonPrintf "registering >>>$TC_ORG3_DOMAIN<<< peers with >>>$TC_COMMON1_C1_FQDN<<<" 
		out=$(
			_setClient
			fabric-ca-client register --id.name $TC_ORG3_P1_TLS_NAME --id.secret $TC_ORG3_P1_TLS_PW --id.type peer -u https://0.0.0.0:${TC_COMMON1_C1_PORT}  2>&1
		)
		commonVerify $? "failed to register tls identity: $out" "$out"
		out=$(
			_setClient
			fabric-ca-client register --id.name $TC_ORG3_P2_TLS_NAME --id.secret $TC_ORG3_P2_TLS_PW --id.type peer -u https://0.0.0.0:${TC_COMMON1_C1_PORT}  2>&1
		)
		commonVerify $? "failed to register tls identity: $out" "$out"
		out=$(
			_setClient
			fabric-ca-client register --id.name $TC_ORG3_P3_TLS_NAME --id.secret $TC_ORG3_P3_TLS_PW --id.type peer -u https://0.0.0.0:${TC_COMMON1_C1_PORT}  2>&1
		)
		commonVerify $? "failed to register tls identity: $out" "$out"
	}
	commonYN "register >>>$TC_ORG3_DOMAIN<<< peers with >>>$TC_COMMON1_C1_FQDN<<<?" _registerOrg3

	# endregion: registering org3 peers

	unset out
)

[[ "$TC_EXEC_DRY" == false ]] && commonYN "bootstrap ${TC_COMMON1_STACK}, enroll tls ca admin, then register peers and orderers?" _TLS1

# endregion: tls
# region: func for disseminating certs

_disseminate() {
		local cert=$1
		local dest=$2
		local dir=$( dirname $2 )
		local certRel=$( echo "$cert" | sed s+${TC_PATH_BASE}/++g )
		local destRel=$( echo "$dest" | sed s+${TC_PATH_BASE}/++g )
		local dirRel=$( echo "$dir" | sed s+${TC_PATH_BASE}/++g )

		local out
		commonPrintf "disseminating $certRel as $destRel"
		[ -d "$dir" ] && commonPrintf "$dirRel already exists." || out=$( mkdir -p $dir 2>&1 )
		commonVerify $? "failed to create $dir: $out"
		out=$( cp $cert $dest 2>&1 )
		commonVerify $? "failed to disseminate $certRel to $destRel: $out"
}

# endregion: func for disseminating certs
# region: orderer1

_Orderer1() {

	local out

	# region: bootstrap

	_bootstrap() {
		commonPrintf "bootstrapping ${TC_ORDERER1_STACK}"
		${TC_PATH_SCRIPTS}/tcBootstrap.sh -m up -s ${TC_ORDERER1_STACK}
		commonVerify $? "failed!"
	}
	commonYN "bootstrap ${TC_ORDERER1_STACK}?" _bootstrap

	# endregion: bootstrap
	# region: set ca admin

	_setAdminClient() {
		export FABRIC_CA_CLIENT_TLS_CERTFILES=${TC_ORDERER1_C1_HOME}/ca-cert.pem
		export FABRIC_CA_CLIENT_HOME=${TC_ORDERER1_C1_DATA}/${TC_ORDERER1_C1_ADMIN}
	}

	# endregion: set ca admin
	# region: enroll ca admin

	_enrollAdmin() {
		commonPrintf "enrolling ${TC_ORDERER1_C1_ADMIN} with $TC_ORDERER1_C1_FQDN"
		out=$(
			_setAdminClient
			fabric-ca-client enroll -u https://${TC_ORDERER1_C1_ADMIN}:${TC_ORDERER1_C1_ADMINPW}@0.0.0.0:${TC_ORDERER1_C1_PORT}  2>&1
		)
		commonVerify $? "failed to enroll $TC_ORDERER1_C1_ADMIN: $out" "$out"
	}
	commonYN "enroll ${TC_ORDERER1_C1_ADMIN} with $TC_ORDERER1_C1_FQDN?" _enrollAdmin

	# endregion: enroll ca admin
	# region: register orderer1 admin
	
	_registerUsers() {
		commonPrintf "registering ${TC_ORDERER1_STACK} admin with $TC_ORDERER1_C1_FQDN" 
		out=$(
			_setAdminClient
			fabric-ca-client register --id.name $TC_ORDERER1_ADMIN --id.secret $TC_ORDERER1_ADMINPW --id.type admin --id.attrs "$TC_ORDERER1_ADMINATRS" -u https://0.0.0.0:${TC_ORDERER1_C1_PORT} 2>&1
		)
		commonVerify $? "failed to register ${TC_ORDERER1_ADMIN}: $out" "$out"
	}
	commonYN "register ${TC_ORDERER1_ADMIN} with ${TC_ORDERER1_C1_FQDN}?" _registerUsers

	# endregion: register orderer1 admin
	# region: register orderer nodes 

	_registerNodes() {
		commonPrintf "registering ${TC_ORDERER1_STACK}'s orderers with $TC_ORDERER1_C1_FQDN"
		out=$(
			_setAdminClient;
			fabric-ca-client register --id.name $TC_ORDERER1_O1_CA_NAME --id.secret $TC_ORDERER1_O1_CA_PW --id.type orderer -u https://0.0.0.0:${TC_ORDERER1_C1_PORT} 2>&1
		)
		commonVerify $? "failed to register ${TC_ORDERER1_O1_CA_NAME}: $out" "$out"
		out=$(
			_setAdminClient
			fabric-ca-client register --id.name $TC_ORDERER1_O2_CA_NAME --id.secret $TC_ORDERER1_O2_CA_PW --id.type orderer -u https://0.0.0.0:${TC_ORDERER1_C1_PORT} 2>&1
		)
		commonVerify $? "failed to register ${TC_ORDERER1_O2_CA_NAME}: $out" "$out"
		out=$(
			_setAdminClient
			fabric-ca-client register --id.name $TC_ORDERER1_O3_CA_NAME --id.secret $TC_ORDERER1_O3_CA_PW --id.type orderer -u https://0.0.0.0:${TC_ORDERER1_C1_PORT} 2>&1
		)
		commonVerify $? "failed to register ${TC_ORDERER1_O3_CA_NAME}: $out" "$out"
	}
	commonYN "register ${TC_ORDERER1_STACK}'s orderers with $TC_ORG1_C1_FQDN?" _registerNodes

	# endregion: register orderer nodes
	# region: copy root certs

	_rootCerts() {
		commonPrintf "acquiring root certs"
		local certCA=${TC_ORDERER1_C1_HOME}/ca-cert.pem
		local tlsCA=${TC_COMMON1_C1_HOME}/ca-cert.pem

		# org msp
		# mkdir -p "${TC_ORDERER1_DATA}/msp/cacerts" && cp $certCA "$_"
		# mkdir -p "${TC_ORDERER1_DATA}/msp/tlscacerts" && cp $tlsCA "$_"
		_disseminate $certCA "${TC_ORDERER1_DATA}/msp/cacerts/ca-cert.pem"	
		_disseminate $tlsCA "${TC_ORDERER1_DATA}/msp/tlscacerts/ca-cert.pem"	

		# local msps
		_disseminate $certCA $TC_ORDERER1_O1_ASSETS_CACERT
		_disseminate $tlsCA $TC_ORDERER1_O1_ASSETS_TLSCERT
		_disseminate $certCA $TC_ORDERER1_O2_ASSETS_CACERT
		_disseminate $tlsCA $TC_ORDERER1_O2_ASSETS_TLSCERT
		_disseminate $certCA $TC_ORDERER1_O3_ASSETS_CACERT
		_disseminate $tlsCA $TC_ORDERER1_O3_ASSETS_TLSCERT
	}
	commonYN "acquire root certs for org msp and orderers?" _rootCerts


	# endregion: root certs
	# region: enroll orderers

	_enrollOrderers() {

		# region: o1

		commonPrintf "enrolling $TC_ORDERER1_O1_NAME with $TC_ORDERER1_C1_FQDN"
		out=$(
			export FABRIC_CA_CLIENT_HOME=${TC_ORDERER1_O1_DATA}
			export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORDERER1_O1_ASSETS_CACERT
			export FABRIC_CA_CLIENT_MSPDIR=$TC_ORDERER1_O1_MSP
			fabric-ca-client enroll -u https://${TC_ORDERER1_O1_CA_NAME}:${TC_ORDERER1_O1_CA_PW}@0.0.0.0:${TC_ORDERER1_C1_PORT} 2>&1
		)
		commonVerify $? "failed to enroll with ${TC_ORDERER1_C1_FQDN}: $out" "$out"

		commonPrintf "enrolling $TC_ORDERER1_O1_NAME with $TC_COMMON1_C1_FQDN"
		out=$(
			export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORDERER1_O1_ASSETS_TLSCERT
			export FABRIC_CA_CLIENT_MSPDIR=$TC_ORDERER1_O1_TLSMSP
			fabric-ca-client enroll -u https://${TC_ORDERER1_O1_TLS_NAME}:${TC_ORDERER1_O1_TLS_PW}@0.0.0.0:${TC_COMMON1_C1_PORT} --enrollment.profile tls --csr.hosts ${TC_ORDERER1_O1_FQDN},${TC_ORDERER1_O1_NAME},localhost 2>&1
		)
		commonVerify $? "failed to enroll with ${TC_COMMON1_C1_FQDN}: $out" "$out"
		out=$( mv ${TC_ORDERER1_O1_TLSMSP}/keystore/* ${TC_ORDERER1_O1_TLSMSP}/keystore/key.pem 2>&1 ) 
		commonVerify $? "failed to rename key.pem: $out" "tls private key inplace renamed to key.pem"

		# endregion: o1
		# region: o2

		commonPrintf "enrolling $TC_ORDERER1_O2_NAME with $TC_ORDERER1_C1_FQDN"
		out=$(
			export FABRIC_CA_CLIENT_HOME=${TC_ORDERER1_O2_DATA}
			export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORDERER1_O2_ASSETS_CACERT
			export FABRIC_CA_CLIENT_MSPDIR=$TC_ORDERER1_O2_MSP
			fabric-ca-client enroll -u https://${TC_ORDERER1_O2_CA_NAME}:${TC_ORDERER1_O2_CA_PW}@0.0.0.0:${TC_ORDERER1_C1_PORT} 2>&1
		)
		commonVerify $? "failed to enroll with ${TC_ORDERER1_C1_FQDN}: $out" "$out"

		commonPrintf "enrolling $TC_ORDERER1_O2_NAME with $TC_COMMON1_C1_FQDN"
		out=$(
			export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORDERER1_O2_ASSETS_TLSCERT
			export FABRIC_CA_CLIENT_MSPDIR=$TC_ORDERER1_O2_TLSMSP
			fabric-ca-client enroll -u https://${TC_ORDERER1_O2_TLS_NAME}:${TC_ORDERER1_O2_TLS_PW}@0.0.0.0:${TC_COMMON1_C1_PORT} --enrollment.profile tls --csr.hosts ${TC_ORDERER1_O2_FQDN},${TC_ORDERER1_O2_NAME},localhost 2>&1
		)
		commonVerify $? "failed to enroll with ${TC_COMMON1_C1_FQDN}: $out" "$out"
		out=$( mv ${TC_ORDERER1_O2_TLSMSP}/keystore/* ${TC_ORDERER1_O2_TLSMSP}/keystore/key.pem 2>&1 ) 
		commonVerify $? "failed to rename key.pem: $out" "tls private key inplace renamed to key.pem"

		# endregion: o2
		# region: o3

		commonPrintf "enrolling $TC_ORDERER1_O3_NAME with $TC_ORDERER1_C1_FQDN"
		out=$(
			export FABRIC_CA_CLIENT_HOME=${TC_ORDERER1_O3_DATA}
			export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORDERER1_O3_ASSETS_CACERT
			export FABRIC_CA_CLIENT_MSPDIR=$TC_ORDERER1_O3_MSP
			fabric-ca-client enroll -u https://${TC_ORDERER1_O3_CA_NAME}:${TC_ORDERER1_O3_CA_PW}@0.0.0.0:${TC_ORDERER1_C1_PORT} 2>&1
		)
		commonVerify $? "failed to enroll with ${TC_ORDERER1_C1_FQDN}: $out" "$out"

		commonPrintf "enrolling $TC_ORDERER1_O3_NAME with $TC_COMMON1_C1_FQDN"
		out=$(
			export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORDERER1_O3_ASSETS_TLSCERT
			export FABRIC_CA_CLIENT_MSPDIR=$TC_ORDERER1_O3_TLSMSP
			fabric-ca-client enroll -u https://${TC_ORDERER1_O3_TLS_NAME}:${TC_ORDERER1_O3_TLS_PW}@0.0.0.0:${TC_COMMON1_C1_PORT} --enrollment.profile tls --csr.hosts ${TC_ORDERER1_O3_FQDN},${TC_ORDERER1_O3_NAME},localhost 2>&1
		)
		commonVerify $? "failed to enroll with ${TC_COMMON1_C1_FQDN}: $out" "$out"
		out=$( mv ${TC_ORDERER1_O3_TLSMSP}/keystore/* ${TC_ORDERER1_O3_TLSMSP}/keystore/key.pem 2>&1 ) 
		commonVerify $? "failed to rename key.pem: $out" "tls private key inplace renamed to key.pem"

		# endregion: o3
	
	}
	commonYN "enroll orderers?" _enrollOrderers

	# endregion: enroll orderers
	# region: enroll users

	_enrollAdmin() {

		local out

		commonPrintf "enrolling $TC_ORDERER1_ADMIN"
		out=$(
			export FABRIC_CA_CLIENT_HOME=$TC_ORDERER1_ADMINHOME
			export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORDERER1_O1_ASSETS_CACERT
			export FABRIC_CA_CLIENT_MSPDIR=$TC_ORDERER1_ADMINMSP
			fabric-ca-client enroll -u https://${TC_ORDERER1_ADMIN}:${TC_ORDERER1_ADMINPW}@0.0.0.0:${TC_ORDERER1_C1_PORT} 2>&1
		)
		commonVerify $? "failed: $out" "$out"
		out=$( mv ${TC_ORDERER1_ADMINMSP}/keystore/* ${TC_ORDERER1_ADMINMSP}/keystore/key.pem 2>&1 ) 
		commonVerify $? "failed to rename key.pem: $out" "tls private key inplace renamed to key.pem"

		commonPrintf "enrolling >>>${TC_ORDERER1_ADMIN}<<< with >>>$TC_COMMON1_C1_FQDN<<<"
		out=$(
			export FABRIC_CA_CLIENT_HOME=$TC_ORDERER1_ADMINHOME
			# export FABRIC_CA_CLIENT_TLS_CERTFILES=${TC_COMMON1_C1_HOME}/ca-cert.pem
			export FABRIC_CA_CLIENT_TLS_CERTFILES=${TC_ORDERER1_DATA}/msp/tlscacerts/ca-cert.pem
			export FABRIC_CA_CLIENT_MSPDIR=$TC_ORDERER1_ADMINTLSMSP			
		 	fabric-ca-client enroll -u https://${TC_ORDERER1_ADMIN}:${TC_ORDERER1_ADMINPW}@0.0.0.0:${TC_COMMON1_C1_PORT} 2>&1
		)
		commonVerify $? "failed: $out" "$out"
		out=$( mv ${TC_ORDERER1_ADMINTLSMSP}/keystore/* ${TC_ORDERER1_ADMINTLSMSP}/keystore/key.pem 2>&1 ) 
		commonVerify $? "failed to rename key.pem: $out" "tls private key inplace renamed to key.pem"

		local admincert="${TC_ORDERER1_ADMINMSP}/signcerts/cert.pem"
		for destNode in "${TC_ORDERER1_O1_MSP}" "${TC_ORDERER1_O2_MSP}" "${TC_ORDERER1_O3_MSP}"
		do
			for destLocal in admincerts users
			do 
				_disseminate "$admincert" "${destNode}/${destLocal}/${TC_ORDERER1_ADMIN}.pem"
			done
		done

		unset destNode destLocal
		unset out

	}
	commonYN "eroll ${TC_ORDERER1_STACK} users?" _enrollAdmin

	# endregion: enroll users
	# region: launch peers

	_launch() {

		local out

		commonPrintf "launching peers"
		# out=$( docker service update --replicas 1 ${TC_NETWORK_NAME}_${TC_ORG1_STACK}_${TC_ORG1_P1_NAME} 2>&1 )
		# commonVerify $? "failed $out" "$out"
		docker service update --replicas 1 ${TC_NETWORK_NAME}_${TC_ORDERER1_STACK}_${TC_ORDERER1_O1_NAME}
		commonVerify $? "failed"
		docker service update --replicas 1 ${TC_NETWORK_NAME}_${TC_ORDERER1_STACK}_${TC_ORDERER1_O2_NAME}
		commonVerify $? "failed"
		docker service update --replicas 1 ${TC_NETWORK_NAME}_${TC_ORDERER1_STACK}_${TC_ORDERER1_O3_NAME}
		commonVerify $? "failed"

		unset out
	}
	commonYN "launch ${TC_ORDERER1_STACK} orderers?" _launch

	# endregion: launch peers
	# region: update replicas

	_replicas() {
		commonPrintf "updating orderer replicas"
		yq -i ".services.${TC_ORDERER1_O1_NAME}.deploy.replicas=1" ${TC_PATH_SWARM}/*_${TC_ORDERER1_STACK}.yaml
		yq -i ".services.${TC_ORDERER1_O2_NAME}.deploy.replicas=1" ${TC_PATH_SWARM}/*_${TC_ORDERER1_STACK}.yaml
		yq -i ".services.${TC_ORDERER1_O3_NAME}.deploy.replicas=1" ${TC_PATH_SWARM}/*_${TC_ORDERER1_STACK}.yaml
	}
	commonYN "update replicas in swarm config?" _replicas

	# endregion: update replicas

	unset out

}

[[ "$TC_EXEC_DRY" == false ]] && commonYN "bootstrap ${TC_ORDERER1_STACK}, enroll ca admin, and register identities?" _Orderer1

# endregion: orderer1
# region: endorser orgs

	# region: org1

	_Org1() {

		local out

		# region: bootstrap

		_bootstrap() {
			commonPrintf "bootstrapping ${TC_ORG1_STACK}"
			${TC_PATH_SCRIPTS}/tcBootstrap.sh -m up -s ${TC_ORG1_STACK}
			commonVerify $? "failed!"
		}
		commonYN "bootstrap ${TC_ORG1_STACK}?" _bootstrap

		# endregion: bootstrap
		# region: set ca admin

		_setAdminClient() {
			export FABRIC_CA_CLIENT_TLS_CERTFILES=${TC_ORG1_C1_HOME}/ca-cert.pem
			export FABRIC_CA_CLIENT_HOME=${TC_ORG1_C1_DATA}/${TC_ORG1_C1_ADMIN}
		}

		# endregion: set ca admin
		# region: enroll org1 ca admin

		_enrollAdmin() {
			commonPrintf "enrolling ${TC_ORG1_C1_ADMIN} with $TC_ORG1_C1_FQDN"
			out=$(
				_setAdminClient
				export FABRIC_CA_CLIENT_TLS_CERTFILES=${TC_ORG1_C1_HOME}/ca-cert.pem
				export FABRIC_CA_CLIENT_HOME=${TC_ORG1_C1_DATA}/${TC_ORG1_C1_ADMIN}
				fabric-ca-client enroll -u https://${TC_ORG1_C1_ADMIN}:${TC_ORG1_C1_ADMINPW}@0.0.0.0:${TC_ORG1_C1_PORT}  2>&1
			)
			commonVerify $? "failed to enroll $TC_ORG1_C1_ADMIN: $out" "$out"
		}
		commonYN "enroll ${TC_ORG1_C1_ADMIN} with $TC_ORG1_C1_FQDN?" _enrollAdmin

		# endregion: enroll org1 ca admin
		# region: register org1 admin and users
		
		_registerUsers() {
			commonPrintf "registering ${TC_ORG1_STACK} admin, user and client with $TC_ORG1_C1_FQDN"
			out=$(
				_setAdminClient
				fabric-ca-client register --id.name $TC_ORG1_ADMIN --id.secret $TC_ORG1_ADMINPW --id.type admin --id.attrs "$TC_ORG1_ADMINATRS" -u https://0.0.0.0:${TC_ORG1_C1_PORT} 2>&1
			)
			commonVerify $? "failed to register ${TC_ORG1_ADMIN}: $out" "$out"
			out=$(
				_setAdminClient
				fabric-ca-client register --id.name $TC_ORG1_CLIENT --id.secret $TC_ORG1_CLIENTPW --id.type client -u https://0.0.0.0:${TC_ORG1_C1_PORT} 2>&1
			)
			commonVerify $? "failed to register ${TC_ORG1_CLIENT}: $out" "$out"
		}
		commonYN "register ${TC_ORG1_STACK} admin, user and client with ${TC_ORG1_C1_FQDN}?" _registerUsers

		# endregion: register org1 users
		# region: register org1 gw and peers

		_registerNodes() {
			commonPrintf "registering ${TC_ORG1_STACK}'s gw and peers with $TC_ORG1_C1_FQDN"
			out=$(
				_setAdminClient
				fabric-ca-client register --id.name $TC_ORG1_G1_CA_NAME --id.secret $TC_ORG1_G1_CA_PW --id.type client -u https://0.0.0.0:${TC_ORG1_C1_PORT} 2>&1
			)
			commonVerify $? "failed to register ${TC_ORG1_G1_CA_NAME}: $out" "$out"
			out=$(
				_setAdminClient
				fabric-ca-client register --id.name $TC_ORG1_P1_CA_NAME --id.secret $TC_ORG1_P1_CA_PW --id.type peer -u https://0.0.0.0:${TC_ORG1_C1_PORT} 2>&1
			)
			commonVerify $? "failed to register ${TC_ORG1_P1_CA_NAME}: $out" "$out"
			out=$(
				_setAdminClient
				fabric-ca-client register --id.name $TC_ORG1_P2_CA_NAME --id.secret $TC_ORG1_P2_CA_PW --id.type peer -u https://0.0.0.0:${TC_ORG1_C1_PORT} 2>&1
			)
			commonVerify $? "failed to register ${TC_ORG1_P2_CA_NAME}: $out" "$out"
			out=$(
				_setAdminClient
				fabric-ca-client register --id.name $TC_ORG1_P3_CA_NAME --id.secret $TC_ORG1_P3_CA_PW --id.type peer -u https://0.0.0.0:${TC_ORG1_C1_PORT} 2>&1
			)
			commonVerify $? "failed to register ${TC_ORG1_O3_CA_NAME}: $out" "$out"
		}
		commonYN "register ${TC_ORG1_STACK}'s gw and peers with $TC_ORG1_C1_FQDN?" _registerNodes

		# endregion: register org1's gw and peers
		# region: copy root certs

		_rootCerts() {
			commonPrintf "acquiring root certs"
			local certCA=${TC_ORG1_C1_HOME}/ca-cert.pem
			local tlsCA=${TC_COMMON1_C1_HOME}/ca-cert.pem

			# org msp
			_disseminate $certCA "${TC_ORG1_DATA}/msp/cacerts/ca-cert.pem"	
			_disseminate $tlsCA "${TC_ORG1_DATA}/msp/tlscacerts/ca-cert.pem"	

			# local msps
			_disseminate $certCA $TC_ORG1_G1_ASSETS_CACERT
			_disseminate $tlsCA $TC_ORG1_G1_ASSETS_TLSCERT
			_disseminate $certCA $TC_ORG1_P1_ASSETS_CACERT
			_disseminate $tlsCA $TC_ORG1_P1_ASSETS_TLSCERT
			_disseminate $certCA $TC_ORG1_P2_ASSETS_CACERT
			_disseminate $tlsCA $TC_ORG1_P2_ASSETS_TLSCERT
			_disseminate $certCA $TC_ORG1_P3_ASSETS_CACERT
			_disseminate $tlsCA $TC_ORG1_P3_ASSETS_TLSCERT
		}
		commonYN "acquire root certs for peers?" _rootCerts

		# endregion: root certs	
		# region: enroll peers

		_enrollPeers() {

			# region: g1

			commonPrintf "enrolling g1 with $TC_ORG1_C1_FQDN"
			out=$(
				export FABRIC_CA_CLIENT_HOME=${TC_ORG1_G1_DATA}
				export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORG1_G1_ASSETS_CACERT
				export FABRIC_CA_CLIENT_MSPDIR=$TC_ORG1_G1_MSP
				fabric-ca-client enroll -u https://${TC_ORG1_G1_CA_NAME}:${TC_ORG1_G1_CA_PW}@0.0.0.0:${TC_ORG1_C1_PORT} 2>&1
			)
			commonVerify $? "failed: $out" "$out"

			commonPrintf "enrolling g1 with $TC_COMMON1_C1_FQDN"
			out=$(
				export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORG1_G1_ASSETS_TLSCERT
				export FABRIC_CA_CLIENT_MSPDIR=$TC_ORG1_G1_TLSMSP
				fabric-ca-client enroll -u https://${TC_ORG1_G1_TLS_NAME}:${TC_ORG1_G1_TLS_PW}@0.0.0.0:${TC_COMMON1_C1_PORT} --enrollment.profile tls --csr.hosts ${TC_ORG1_G1_FQDN},${TC_ORG1_G1_NAME},localhost 2>&1
			)
			commonVerify $? "failed: $out" "$out"
			out=$( mv ${TC_ORG1_G1_TLSMSP}/keystore/* ${TC_ORG1_G1_TLSMSP}/keystore/key.pem 2>&1 ) 
			commonVerify $? "failed to rename key.pem: $out" "tls private key inplace renamed to key.pem"

			# endregion: g1
			# region: p1

			commonPrintf "enrolling p1 with $TC_ORG1_C1_FQDN" 
			out=$(
				export FABRIC_CA_CLIENT_HOME=${TC_ORG1_P1_DATA}
				export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORG1_P1_ASSETS_CACERT
				export FABRIC_CA_CLIENT_MSPDIR=$TC_ORG1_P1_MSP
				fabric-ca-client enroll -u https://${TC_ORG1_P1_CA_NAME}:${TC_ORG1_P1_CA_PW}@0.0.0.0:${TC_ORG1_C1_PORT} 2>&1
			)
			commonVerify $? "failed: $out" "$out"

			commonPrintf "enrolling with $TC_COMMON1_C1_FQDN"
			out=$(
				export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORG1_P1_ASSETS_TLSCERT
				export FABRIC_CA_CLIENT_MSPDIR=$TC_ORG1_P1_TLSMSP
				fabric-ca-client enroll -u https://${TC_ORG1_P1_TLS_NAME}:${TC_ORG1_P1_TLS_PW}@0.0.0.0:${TC_COMMON1_C1_PORT} --enrollment.profile tls --csr.hosts ${TC_ORG1_P1_FQDN},${TC_ORG1_P1_NAME},localhost 2>&1
			)
			commonVerify $? "failed: $out" "$out"
			out=$( mv ${TC_ORG1_P1_TLSMSP}/keystore/* ${TC_ORG1_P1_TLSMSP}/keystore/key.pem 2>&1 )
			commonVerify $? "failed to rename key.pem: $out" "tls private key inplace renamed to key.pem"

			# endregion: p1
			# region: p2

			commonPrintf "enrolling p1 with $TC_ORG1_C1_FQDN" 
			out=$(
				export FABRIC_CA_CLIENT_HOME=${TC_ORG1_P2_DATA}
				export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORG1_P2_ASSETS_CACERT
				export FABRIC_CA_CLIENT_MSPDIR=$TC_ORG1_P2_MSP
				fabric-ca-client enroll -u https://${TC_ORG1_P2_CA_NAME}:${TC_ORG1_P2_CA_PW}@0.0.0.0:${TC_ORG1_C1_PORT} 2>&1
			)
			commonVerify $? "failed: $out" "$out"

			commonPrintf "enrolling with $TC_COMMON1_C1_FQDN"
			out=$(
				export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORG1_P2_ASSETS_TLSCERT
				export FABRIC_CA_CLIENT_MSPDIR=$TC_ORG1_P2_TLSMSP
				fabric-ca-client enroll -u https://${TC_ORG1_P2_TLS_NAME}:${TC_ORG1_P2_TLS_PW}@0.0.0.0:${TC_COMMON1_C1_PORT} --enrollment.profile tls --csr.hosts ${TC_ORG1_P2_FQDN},${TC_ORG1_P2_NAME},localhost 2>&1
			)
			commonVerify $? "failed: $out" "$out"
			out=$( mv ${TC_ORG1_P2_TLSMSP}/keystore/* ${TC_ORG1_P2_TLSMSP}/keystore/key.pem 2>&1 )
			commonVerify $? "failed to rename key.pem: $out" "tls private key inplace renamed to key.pem"

			# endregion: p2
			# region: p3

			commonPrintf "enrolling p1 with $TC_ORG1_C1_FQDN" 
			out=$(
				export FABRIC_CA_CLIENT_HOME=${TC_ORG1_P3_DATA}
				export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORG1_P3_ASSETS_CACERT
				export FABRIC_CA_CLIENT_MSPDIR=$TC_ORG1_P3_MSP
				fabric-ca-client enroll -u https://${TC_ORG1_P3_CA_NAME}:${TC_ORG1_P3_CA_PW}@0.0.0.0:${TC_ORG1_C1_PORT} 2>&1
			)
			commonVerify $? "failed: $out" "$out"

			commonPrintf "enrolling with $TC_COMMON1_C1_FQDN"
			out=$(
				export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORG1_P3_ASSETS_TLSCERT
				export FABRIC_CA_CLIENT_MSPDIR=$TC_ORG1_P3_TLSMSP
				fabric-ca-client enroll -u https://${TC_ORG1_P3_TLS_NAME}:${TC_ORG1_P3_TLS_PW}@0.0.0.0:${TC_COMMON1_C1_PORT} --enrollment.profile tls --csr.hosts ${TC_ORG1_P3_FQDN},${TC_ORG1_P3_NAME},localhost 2>&1
			)
			commonVerify $? "failed: $out" "$out"
			out=$( mv ${TC_ORG1_P3_TLSMSP}/keystore/* ${TC_ORG1_P3_TLSMSP}/keystore/key.pem 2>&1 )
			commonVerify $? "failed to rename key.pem: $out" "tls private key inplace renamed to key.pem"

			# endregion: p3
		
		}
		commonYN "enroll peers?" _enrollPeers

		# endregion: enroll peers
		# region: enroll users

		_enrollUsers() {

			local out

			# region: admin

			commonPrintf "enrolling $TC_ORG1_ADMIN"
			out=$(
				export FABRIC_CA_CLIENT_HOME=$TC_ORG1_ADMINHOME
				export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORG1_P1_ASSETS_CACERT
				export FABRIC_CA_CLIENT_MSPDIR=$TC_ORG1_ADMINMSP
				fabric-ca-client enroll -u https://${TC_ORG1_ADMIN}:${TC_ORG1_ADMINPW}@0.0.0.0:${TC_ORG1_C1_PORT} 2>&1
			)
			commonVerify $? "failed: $out" "$out"

			local admincert="${TC_ORG1_ADMINMSP}/signcerts/cert.pem"
			for destNode in "${TC_ORG1_P1_MSP}" "${TC_ORG1_P2_MSP}" "${TC_ORG1_P3_MSP}" "${TC_ORG1_G1_MSP}"
			do
				for destLocal in admincerts users
				do 
					_disseminate "$admincert" "${destNode}/${destLocal}/${TC_ORG1_ADMIN}.pem"
				done
			done

			unset destNode destLocal

			# endregion: admin
			# region: client

			commonPrintf "enrolling $TC_ORG1_CLIENT"
			out=$(
				export FABRIC_CA_CLIENT_HOME=$( dirname $TC_ORG1_CLIENTMSP )
				export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORG1_P1_ASSETS_CACERT
				export FABRIC_CA_CLIENT_MSPDIR=$TC_ORG1_CLIENTMSP
				fabric-ca-client enroll -u https://${TC_ORG1_CLIENT}:${TC_ORG1_CLIENTPW}@0.0.0.0:${TC_ORG1_C1_PORT} 2>&1
			)
			commonVerify $? "failed: $out" "$out"

			local clientcert="${TC_ORG1_CLIENTMSP}/signcerts/cert.pem"
			for destNode in "${TC_ORG1_P1_MSP}" "${TC_ORG1_P2_MSP}" "${TC_ORG1_P3_MSP}"  "${TC_ORG1_G1_MSP}"
			do
				_disseminate "$clientcert" "${destNode}/users/${TC_ORG1_CLIENT}.pem"
			done

			# endregion: client

			unset destNode destLocal
			unset out

		}
		commonYN "eroll ${TC_ORG1_STACK} users?" _enrollUsers

		# endregion: enroll users
		# region: launch peers

		_launch() {

			local out

			commonPrintf "launching peers"
			# out=$( docker service update --replicas 1 ${TC_NETWORK_NAME}_${TC_ORG1_STACK}_${TC_ORG1_P1_NAME} 2>&1 )
			# commonVerify $? "failed $out" "$out"
			docker service update --replicas 1 ${TC_NETWORK_NAME}_${TC_ORG1_STACK}_${TC_ORG1_P1_NAME}
			commonVerify $? "failed"
			docker service update --replicas 1 ${TC_NETWORK_NAME}_${TC_ORG1_STACK}_${TC_ORG1_P2_NAME}
			commonVerify $? "failed"
			docker service update --replicas 1 ${TC_NETWORK_NAME}_${TC_ORG1_STACK}_${TC_ORG1_P3_NAME}
			commonVerify $? "failed"

			unset out
		}
		commonYN "launch ${TC_ORG1_STACK} peers?" _launch

		# endregion: launch peers
		# region: update replicas

		_replicas() {
			commonPrintf "updating peer replicas"
			yq -i ".services.${TC_ORG1_P1_NAME}.deploy.replicas=1" ${TC_PATH_SWARM}/*_${TC_ORG1_STACK}.yaml
			yq -i ".services.${TC_ORG1_P2_NAME}.deploy.replicas=1" ${TC_PATH_SWARM}/*_${TC_ORG1_STACK}.yaml
			yq -i ".services.${TC_ORG1_P3_NAME}.deploy.replicas=1" ${TC_PATH_SWARM}/*_${TC_ORG1_STACK}.yaml
		}
		commonYN "update replicas in swarm config?" _replicas

		# endregion: update replicas

		unset out
	}

	[[ "$TC_EXEC_DRY" == false ]] && commonYN "bootstrap ${TC_ORG1_STACK}, register and enroll identities?" _Org1

	# endregion: org1
	# region: org2

	_Org2() {

		local out

		# region: bootstrap

		_bootstrap() {
			commonPrintf "bootstrapping ${TC_ORG2_STACK}"
			${TC_PATH_SCRIPTS}/tcBootstrap.sh -m up -s ${TC_ORG2_STACK}
			commonVerify $? "failed!"
		}
		commonYN "bootstrap ${TC_ORG2_STACK}?" _bootstrap

		# endregion: bootstrap
		# region: set ca admin

		_setAdminClient() {
			export FABRIC_CA_CLIENT_TLS_CERTFILES=${TC_ORG2_C1_HOME}/ca-cert.pem
			export FABRIC_CA_CLIENT_HOME=${TC_ORG2_C1_DATA}/${TC_ORG2_C1_ADMIN}
		}

		# endregion: set ca admin
		# region: enroll org2 ca admin

		_enrollAdmin() {
			commonPrintf "enrolling ${TC_ORG2_C1_ADMIN} with $TC_ORG2_C1_FQDN"
			out=$(
				_setAdminClient
				fabric-ca-client enroll -u https://${TC_ORG2_C1_ADMIN}:${TC_ORG2_C1_ADMINPW}@0.0.0.0:${TC_ORG2_C1_PORT}  2>&1
			)
			commonVerify $? "failed to enroll $TC_ORG2_C1_ADMIN: $out" "$out"
		}
		commonYN "enroll ${TC_ORG2_C1_ADMIN} with $TC_ORG2_C1_FQDN?" _enrollAdmin

		# endregion: enroll org2 ca admin
		# region: register org2 users
		
		_registerUsers() {
			commonPrintf "registering ${TC_ORG2_STACK} admin, user and client with $TC_ORG2_C1_FQDN" 
			out=$(
				_setAdminClient
				fabric-ca-client register --id.name $TC_ORG2_ADMIN --id.secret $TC_ORG2_ADMINPW --id.type admin --id.attrs "$TC_ORG2_ADMINATRS" -u https://0.0.0.0:${TC_ORG2_C1_PORT} 2>&1
			)
			commonVerify $? "failed to register ${TC_ORG2_ADMIN}: $out" "$out"
			out=$(
				_setAdminClient
				fabric-ca-client register --id.name $TC_ORG2_CLIENT --id.secret $TC_ORG2_CLIENTPW --id.type client -u https://0.0.0.0:${TC_ORG2_C1_PORT} 2>&1
			)
			commonVerify $? "failed to register ${TC_ORG2_CLIENT}: $out" "$out"
		}
		commonYN "register ${TC_ORG2_STACK} admin, user and client with ${TC_ORG2_C1_FQDN}?" _registerUsers

		# endregion: register org2 users
		# region: register org2 gw and peers

		_registerNodes() {
			commonPrintf "registering ${TC_ORG2_STACK}'s gw and peers with $TC_ORG2_C1_FQDN"
			out=$(
				_setAdminClient
				fabric-ca-client register --id.name $TC_ORG2_P1_CA_NAME --id.secret $TC_ORG2_P1_CA_PW --id.type peer -u https://0.0.0.0:${TC_ORG2_C1_PORT} 2>&1
			)
			commonVerify $? "failed to register ${TC_ORG2_P1_CA_NAME}: $out" "$out"
			out=$(
				_setAdminClient
				fabric-ca-client register --id.name $TC_ORG2_P2_CA_NAME --id.secret $TC_ORG2_P2_CA_PW --id.type peer -u https://0.0.0.0:${TC_ORG2_C1_PORT} 2>&1
			)
			commonVerify $? "failed to register ${TC_ORG2_P2_CA_NAME}: $out" "$out"
			out=$(
				_setAdminClient
				fabric-ca-client register --id.name $TC_ORG2_P3_CA_NAME --id.secret $TC_ORG2_P3_CA_PW --id.type peer -u https://0.0.0.0:${TC_ORG2_C1_PORT} 2>&1
			)
			commonVerify $? "failed to register ${TC_ORG2_O3_CA_NAME}: $out" "$out"
		}
		commonYN "register ${TC_ORG2_STACK}'s gw and peers with $TC_ORG2_C1_FQDN?" _registerNodes

		# endregion: register org2's gw and peers
		# region: copy root certs

		_rootCerts() {
			commonPrintf "acquiring root certs"
			local certCA=${TC_ORG2_C1_HOME}/ca-cert.pem
			local tlsCA=${TC_COMMON1_C1_HOME}/ca-cert.pem

			# org msp
			mkdir -p "${TC_ORG2_DATA}/msp/cacerts" && cp $certCA "$_"
			mkdir -p "${TC_ORG2_DATA}/msp/tlscacerts" && cp $tlsCA "$_"

			# org msp
			_disseminate $certCA "${TC_ORG2_DATA}/msp/cacerts/ca-cert.pem"	
			_disseminate $tlsCA "${TC_ORG2_DATA}/msp/tlscacerts/ca-cert.pem"	

			# local msps
			# _disseminate $certCA $TC_ORG2_G1_ASSETS_CACERT
			# _disseminate $tlsCA $TC_ORG2_G1_ASSETS_TLSCERT
			_disseminate $certCA $TC_ORG2_P1_ASSETS_CACERT
			_disseminate $tlsCA $TC_ORG2_P1_ASSETS_TLSCERT
			_disseminate $certCA $TC_ORG2_P2_ASSETS_CACERT
			_disseminate $tlsCA $TC_ORG2_P2_ASSETS_TLSCERT
			_disseminate $certCA $TC_ORG2_P3_ASSETS_CACERT
			_disseminate $tlsCA $TC_ORG2_P3_ASSETS_TLSCERT
		}
		commonYN "acquire root certs for peers?" _rootCerts

		# endregion: root certs	
		# region: enroll peers

		_enrollPeers() {

			# region: p1

			commonPrintf "enrolling p1 with $TC_ORG2_C1_FQDN"
			out=$(
				export FABRIC_CA_CLIENT_HOME=${TC_ORG2_P1_DATA}
				export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORG2_P1_ASSETS_CACERT
				export FABRIC_CA_CLIENT_MSPDIR=$TC_ORG2_P1_MSP
				fabric-ca-client enroll -u https://${TC_ORG2_P1_CA_NAME}:${TC_ORG2_P1_CA_PW}@0.0.0.0:${TC_ORG2_C1_PORT} 2>&1
			)
			commonVerify $? "failed: $out" "$out"

			commonPrintf "enrolling with $TC_COMMON1_C1_FQDN"
			out=$(
				export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORG2_P1_ASSETS_TLSCERT
				export FABRIC_CA_CLIENT_MSPDIR=$TC_ORG2_P1_TLSMSP
				fabric-ca-client enroll -u https://${TC_ORG2_P1_TLS_NAME}:${TC_ORG2_P1_TLS_PW}@0.0.0.0:${TC_COMMON1_C1_PORT} --enrollment.profile tls --csr.hosts ${TC_ORG2_P1_FQDN},${TC_ORG2_P1_NAME},localhost 2>&1
			)
			commonVerify $? "failed: $out" "$out"
			out=$( mv ${TC_ORG2_P1_TLSMSP}/keystore/* ${TC_ORG2_P1_TLSMSP}/keystore/key.pem 2>&1 )
			commonVerify $? "failed to rename key.pem: $out" "tls private key inplace renamed to key.pem"

			# endregion: p1
			# region: p2

			commonPrintf "enrolling p1 with $TC_ORG2_C1_FQDN"
			out=$(
				export FABRIC_CA_CLIENT_HOME=${TC_ORG2_P2_DATA}
				export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORG2_P2_ASSETS_CACERT
				export FABRIC_CA_CLIENT_MSPDIR=$TC_ORG2_P2_MSP
				fabric-ca-client enroll -u https://${TC_ORG2_P2_CA_NAME}:${TC_ORG2_P2_CA_PW}@0.0.0.0:${TC_ORG2_C1_PORT} 2>&1
			)
			commonVerify $? "failed: $out" "$out"

			commonPrintf "enrolling with $TC_COMMON1_C1_FQDN"
			out=$(
				export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORG2_P2_ASSETS_TLSCERT
				export FABRIC_CA_CLIENT_MSPDIR=$TC_ORG2_P2_TLSMSP
				fabric-ca-client enroll -u https://${TC_ORG2_P2_TLS_NAME}:${TC_ORG2_P2_TLS_PW}@0.0.0.0:${TC_COMMON1_C1_PORT} --enrollment.profile tls --csr.hosts ${TC_ORG2_P2_FQDN},${TC_ORG2_P2_NAME},localhost 2>&1
			)
			commonVerify $? "failed: $out" "$out"
			out=$( mv ${TC_ORG2_P2_TLSMSP}/keystore/* ${TC_ORG2_P2_TLSMSP}/keystore/key.pem 2>&1 )
			commonVerify $? "failed to rename key.pem: $out" "tls private key inplace renamed to key.pem"

			# endregion: p2
			# region: p3

			commonPrintf "enrolling p1 with $TC_ORG2_C1_FQDN"
			out=$(
				export FABRIC_CA_CLIENT_HOME=${TC_ORG2_P3_DATA}
				export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORG2_P3_ASSETS_CACERT
				export FABRIC_CA_CLIENT_MSPDIR=$TC_ORG2_P3_MSP
				fabric-ca-client enroll -u https://${TC_ORG2_P3_CA_NAME}:${TC_ORG2_P3_CA_PW}@0.0.0.0:${TC_ORG2_C1_PORT} 2>&1
			)
			commonVerify $? "failed: $out" "$out"

			commonPrintf "enrolling with $TC_COMMON1_C1_FQDN"
			out=$(
				export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORG2_P3_ASSETS_TLSCERT
				export FABRIC_CA_CLIENT_MSPDIR=$TC_ORG2_P3_TLSMSP
				fabric-ca-client enroll -u https://${TC_ORG2_P3_TLS_NAME}:${TC_ORG2_P3_TLS_PW}@0.0.0.0:${TC_COMMON1_C1_PORT} --enrollment.profile tls --csr.hosts ${TC_ORG2_P3_FQDN},${TC_ORG2_P3_NAME},localhost 2>&1
			)
			commonVerify $? "failed: $out" "$out"
			out=$( mv ${TC_ORG2_P3_TLSMSP}/keystore/* ${TC_ORG2_P3_TLSMSP}/keystore/key.pem 2>&1 )
			commonVerify $? "failed to rename key.pem: $out" "tls private key inplace renamed to key.pem"

			# endregion: p3

		}
		commonYN "enroll peers?" _enrollPeers

		# endregion: enroll peers
		# region: enroll users

		_enrollUsers() {

			local out

			# region: admin

			commonPrintf "enrolling $TC_ORG2_ADMIN"
			out=$(
				export FABRIC_CA_CLIENT_HOME=$TC_ORG2_ADMINHOME
				export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORG2_P1_ASSETS_CACERT
				export FABRIC_CA_CLIENT_MSPDIR=$TC_ORG2_ADMINMSP
				fabric-ca-client enroll -u https://${TC_ORG2_ADMIN}:${TC_ORG2_ADMINPW}@0.0.0.0:${TC_ORG2_C1_PORT} 2>&1
			)
			commonVerify $? "failed: $out" "$out"

			local admincert="${TC_ORG2_ADMINMSP}/signcerts/cert.pem"
			for destNode in "${TC_ORG2_P1_MSP}" "${TC_ORG2_P2_MSP}" "${TC_ORG2_P3_MSP}"
			do
				for destLocal in admincerts users
				do 
					_disseminate "$admincert" "${destNode}/${destLocal}/${TC_ORG2_ADMIN}.pem"
				done
			done

			unset destNode destLocal

			# endregion: admin
			# region: client

			commonPrintf "enrolling $TC_ORG2_CLIENT"
			out=$(
				export FABRIC_CA_CLIENT_HOME=$( dirname $TC_ORG2_CLIENTMSP )
				export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORG2_P1_ASSETS_CACERT
				export FABRIC_CA_CLIENT_MSPDIR=$TC_ORG2_CLIENTMSP
				fabric-ca-client enroll -u https://${TC_ORG2_CLIENT}:${TC_ORG2_CLIENTPW}@0.0.0.0:${TC_ORG2_C1_PORT} 2>&1
			)
			commonVerify $? "failed: $out" "$out"

			local clientcert="${TC_ORG2_CLIENTMSP}/signcerts/cert.pem"
			for destNode in "${TC_ORG2_P1_MSP}" "${TC_ORG2_P2_MSP}" "${TC_ORG2_P3_MSP}"
			do
				_disseminate "$clientcert" "${destNode}/users/${TC_ORG2_CLIENT}.pem"
			done

			# endregion: client

			unset destNode destLocal
			unset out

		}
		commonYN "eroll ${TC_ORG2_STACK} users?" _enrollUsers

		# endregion: enroll users
		# region: launch peers

		_launch() {

			local out

			commonPrintf "launching peers"
			# out=$( docker service update --replicas 1 ${TC_NETWORK_NAME}_${TC_ORG2_STACK}_${TC_ORG2_P1_NAME} 2>&1 )
			# commonVerify $? "failed $out" "$out"
			docker service update --replicas 1 ${TC_NETWORK_NAME}_${TC_ORG2_STACK}_${TC_ORG2_P1_NAME}
			commonVerify $? "failed"
			docker service update --replicas 1 ${TC_NETWORK_NAME}_${TC_ORG2_STACK}_${TC_ORG2_P2_NAME}
			commonVerify $? "failed"
			docker service update --replicas 1 ${TC_NETWORK_NAME}_${TC_ORG2_STACK}_${TC_ORG2_P3_NAME}
			commonVerify $? "failed"

			unset out
		}
		commonYN "launch ${TC_ORG2_STACK} peers?" _launch

		# endregion: launch peers
		# region: update replicas

		_replicas() {
			commonPrintf "updating peer replicas"
			yq -i ".services.${TC_ORG2_P1_NAME}.deploy.replicas=1" ${TC_PATH_SWARM}/*_${TC_ORG2_STACK}.yaml
			yq -i ".services.${TC_ORG2_P2_NAME}.deploy.replicas=1" ${TC_PATH_SWARM}/*_${TC_ORG2_STACK}.yaml
			yq -i ".services.${TC_ORG2_P3_NAME}.deploy.replicas=1" ${TC_PATH_SWARM}/*_${TC_ORG2_STACK}.yaml
		}
		commonYN "update replicas in swarm config?" _replicas

		# endregion: update replicas

		unset out
	}

	[[ "$TC_EXEC_DRY" == false ]] && commonYN "bootstrap ${TC_ORG2_STACK}, register and enroll identities?" _Org2

	# endregion: org2
	# region: org3

	_Org3() {

		local out

		# region: bootstrap

		_bootstrap() {
			commonPrintf "bootstrapping ${TC_ORG3_STACK}"
			${TC_PATH_SCRIPTS}/tcBootstrap.sh -m up -s ${TC_ORG3_STACK}
			commonVerify $? "failed!"
		}
		commonYN "bootstrap ${TC_ORG3_STACK}?" _bootstrap

		# endregion: bootstrap
		# region: set ca admin

		_setAdminClient() {
			export FABRIC_CA_CLIENT_TLS_CERTFILES=${TC_ORG3_C1_HOME}/ca-cert.pem
			export FABRIC_CA_CLIENT_HOME=${TC_ORG3_C1_DATA}/${TC_ORG3_C1_ADMIN}
		}

		# endregion: set ca admin
		# region: enroll org2 ca admin

		_enrollAdmin() {
			commonPrintf "enrolling ${TC_ORG3_C1_ADMIN} with $TC_ORG3_C1_FQDN"
			out=$(
				_setAdminClient
				fabric-ca-client enroll -u https://${TC_ORG3_C1_ADMIN}:${TC_ORG3_C1_ADMINPW}@0.0.0.0:${TC_ORG3_C1_PORT}  2>&1
			)
			commonVerify $? "failed to enroll $TC_ORG3_C1_ADMIN: $out" "$out"
		}
		commonYN "enroll ${TC_ORG3_C1_ADMIN} with $TC_ORG3_C1_FQDN?" _enrollAdmin

		# endregion: enroll org2 ca admin
		# region: register org2 users
		
		_registerUsers() {
			commonPrintf "registering ${TC_ORG3_STACK} admin, user and client with $TC_ORG3_C1_FQDN" 
			out=$(
				_setAdminClient
				fabric-ca-client register --id.name $TC_ORG3_ADMIN --id.secret $TC_ORG3_ADMINPW --id.type admin --id.attrs "$TC_ORG3_ADMINATRS" -u https://0.0.0.0:${TC_ORG3_C1_PORT} 2>&1
			)
			commonVerify $? "failed to register ${TC_ORG3_ADMIN}: $out" "$out"
			out=$(
				_setAdminClient
				fabric-ca-client register --id.name $TC_ORG3_CLIENT --id.secret $TC_ORG3_CLIENTPW --id.type client -u https://0.0.0.0:${TC_ORG3_C1_PORT} 2>&1
			)
			commonVerify $? "failed to register ${TC_ORG3_CLIENT}: $out" "$out"
		}
		commonYN "register ${TC_ORG3_STACK} admin, user and client with ${TC_ORG3_C1_FQDN}?" _registerUsers

		# endregion: register org2 users
		# region: register org2 gw and peers

		_registerNodes() {
			commonPrintf "registering ${TC_ORG3_STACK}'s gw and peers with $TC_ORG3_C1_FQDN"
			out=$(
				_setAdminClient
				fabric-ca-client register --id.name $TC_ORG3_P1_CA_NAME --id.secret $TC_ORG3_P1_CA_PW --id.type peer -u https://0.0.0.0:${TC_ORG3_C1_PORT} 2>&1
			)
			commonVerify $? "failed to register ${TC_ORG3_P1_CA_NAME}: $out" "$out"
			out=$(
				_setAdminClient
				fabric-ca-client register --id.name $TC_ORG3_P2_CA_NAME --id.secret $TC_ORG3_P2_CA_PW --id.type peer -u https://0.0.0.0:${TC_ORG3_C1_PORT} 2>&1
			)
			commonVerify $? "failed to register ${TC_ORG3_P2_CA_NAME}: $out" "$out"
			out=$(
				_setAdminClient
				fabric-ca-client register --id.name $TC_ORG3_P3_CA_NAME --id.secret $TC_ORG3_P3_CA_PW --id.type peer -u https://0.0.0.0:${TC_ORG3_C1_PORT} 2>&1
			)
			commonVerify $? "failed to register ${TC_ORG3_O3_CA_NAME}: $out" "$out"
		}
		commonYN "register ${TC_ORG3_STACK}'s gw and peers with $TC_ORG3_C1_FQDN?" _registerNodes

		# endregion: register org2's gw and peers
		# region: copy root certs

		_rootCerts() {
			commonPrintf "acquiring root certs"
			local certCA=${TC_ORG3_C1_HOME}/ca-cert.pem
			local tlsCA=${TC_COMMON1_C1_HOME}/ca-cert.pem

			# org msp
			mkdir -p "${TC_ORG3_DATA}/msp/cacerts" && cp $certCA "$_"
			mkdir -p "${TC_ORG3_DATA}/msp/tlscacerts" && cp $tlsCA "$_"

			# org msp
			_disseminate $certCA "${TC_ORG3_DATA}/msp/cacerts/ca-cert.pem"	
			_disseminate $tlsCA "${TC_ORG3_DATA}/msp/tlscacerts/ca-cert.pem"	

			# local msps
			# _disseminate $certCA $TC_ORG3_G1_ASSETS_CACERT
			# _disseminate $tlsCA $TC_ORG3_G1_ASSETS_TLSCERT
			_disseminate $certCA $TC_ORG3_P1_ASSETS_CACERT
			_disseminate $tlsCA $TC_ORG3_P1_ASSETS_TLSCERT
			_disseminate $certCA $TC_ORG3_P2_ASSETS_CACERT
			_disseminate $tlsCA $TC_ORG3_P2_ASSETS_TLSCERT
			_disseminate $certCA $TC_ORG3_P3_ASSETS_CACERT
			_disseminate $tlsCA $TC_ORG3_P3_ASSETS_TLSCERT
		}
		commonYN "acquire root certs for peers?" _rootCerts

		# endregion: root certs	
		# region: enroll peers

		_enrollPeers() {

			# region: p1

			commonPrintf "enrolling p1 with $TC_ORG3_C1_FQDN"
			out=$(
				export FABRIC_CA_CLIENT_HOME=${TC_ORG3_P1_DATA}
				export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORG3_P1_ASSETS_CACERT
				export FABRIC_CA_CLIENT_MSPDIR=$TC_ORG3_P1_MSP
				fabric-ca-client enroll -u https://${TC_ORG3_P1_CA_NAME}:${TC_ORG3_P1_CA_PW}@0.0.0.0:${TC_ORG3_C1_PORT} 2>&1
			)
			commonVerify $? "failed: $out" "$out"

			commonPrintf "enrolling with $TC_COMMON1_C1_FQDN"
			out=$(
				export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORG3_P1_ASSETS_TLSCERT
				export FABRIC_CA_CLIENT_MSPDIR=$TC_ORG3_P1_TLSMSP
				fabric-ca-client enroll -u https://${TC_ORG3_P1_TLS_NAME}:${TC_ORG3_P1_TLS_PW}@0.0.0.0:${TC_COMMON1_C1_PORT} --enrollment.profile tls --csr.hosts ${TC_ORG3_P1_FQDN},${TC_ORG3_P1_NAME},localhost 2>&1
			)
			commonVerify $? "failed: $out" "$out"
			out=$( mv ${TC_ORG3_P1_TLSMSP}/keystore/* ${TC_ORG3_P1_TLSMSP}/keystore/key.pem 2>&1 )
			commonVerify $? "failed to rename key.pem: $out" "tls private key inplace renamed to key.pem"

			# endregion: p1
			# region: p2

			commonPrintf "enrolling p1 with $TC_ORG3_C1_FQDN"
			out=$(
				export FABRIC_CA_CLIENT_HOME=${TC_ORG3_P2_DATA}
				export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORG3_P2_ASSETS_CACERT
				export FABRIC_CA_CLIENT_MSPDIR=$TC_ORG3_P2_MSP
				fabric-ca-client enroll -u https://${TC_ORG3_P2_CA_NAME}:${TC_ORG3_P2_CA_PW}@0.0.0.0:${TC_ORG3_C1_PORT} 2>&1
			)
			commonVerify $? "failed: $out" "$out"

			commonPrintf "enrolling with $TC_COMMON1_C1_FQDN"
			out=$(
				export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORG3_P2_ASSETS_TLSCERT
				export FABRIC_CA_CLIENT_MSPDIR=$TC_ORG3_P2_TLSMSP
				fabric-ca-client enroll -u https://${TC_ORG3_P2_TLS_NAME}:${TC_ORG3_P2_TLS_PW}@0.0.0.0:${TC_COMMON1_C1_PORT} --enrollment.profile tls --csr.hosts ${TC_ORG3_P2_FQDN},${TC_ORG3_P2_NAME},localhost 2>&1
			)
			commonVerify $? "failed: $out" "$out"
			out=$( mv ${TC_ORG3_P2_TLSMSP}/keystore/* ${TC_ORG3_P2_TLSMSP}/keystore/key.pem 2>&1 )
			commonVerify $? "failed to rename key.pem: $out" "tls private key inplace renamed to key.pem"

			# endregion: p2
			# region: p3

			commonPrintf "enrolling p1 with $TC_ORG3_C1_FQDN"
			out=$(
				export FABRIC_CA_CLIENT_HOME=${TC_ORG3_P3_DATA}
				export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORG3_P3_ASSETS_CACERT
				export FABRIC_CA_CLIENT_MSPDIR=$TC_ORG3_P3_MSP
				fabric-ca-client enroll -u https://${TC_ORG3_P3_CA_NAME}:${TC_ORG3_P3_CA_PW}@0.0.0.0:${TC_ORG3_C1_PORT} 2>&1
			)
			commonVerify $? "failed: $out" "$out"

			commonPrintf "enrolling with $TC_COMMON1_C1_FQDN"
			out=$(
				export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORG3_P3_ASSETS_TLSCERT
				export FABRIC_CA_CLIENT_MSPDIR=$TC_ORG3_P3_TLSMSP
				fabric-ca-client enroll -u https://${TC_ORG3_P3_TLS_NAME}:${TC_ORG3_P3_TLS_PW}@0.0.0.0:${TC_COMMON1_C1_PORT} --enrollment.profile tls --csr.hosts ${TC_ORG3_P3_FQDN},${TC_ORG3_P3_NAME},localhost 2>&1
			)
			commonVerify $? "failed: $out" "$out"
			out=$( mv ${TC_ORG3_P3_TLSMSP}/keystore/* ${TC_ORG3_P3_TLSMSP}/keystore/key.pem 2>&1 )
			commonVerify $? "failed to rename key.pem: $out" "tls private key inplace renamed to key.pem"

			# endregion: p3

		}
		commonYN "enroll peers?" _enrollPeers

		# endregion: enroll peers
		# region: enroll users

		_enrollUsers() {

			local out

			# region: admin

			commonPrintf "enrolling $TC_ORG3_ADMIN"
			out=$(
				export FABRIC_CA_CLIENT_HOME=$TC_ORG3_ADMINHOME
				export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORG3_P1_ASSETS_CACERT
				export FABRIC_CA_CLIENT_MSPDIR=$TC_ORG3_ADMINMSP
				fabric-ca-client enroll -u https://${TC_ORG3_ADMIN}:${TC_ORG3_ADMINPW}@0.0.0.0:${TC_ORG3_C1_PORT} 2>&1
			)
			commonVerify $? "failed: $out" "$out"

			local admincert="${TC_ORG3_ADMINMSP}/signcerts/cert.pem"
			for destNode in "${TC_ORG3_P1_MSP}" "${TC_ORG3_P2_MSP}" "${TC_ORG3_P3_MSP}"
			do
				for destLocal in admincerts users
				do 
					_disseminate "$admincert" "${destNode}/${destLocal}/${TC_ORG3_ADMIN}.pem"
				done
			done

			unset destNode destLocal

			# endregion: admin
			# region: client

			commonPrintf "enrolling $TC_ORG3_CLIENT"
			out=$(
				export FABRIC_CA_CLIENT_HOME=$( dirname $TC_ORG3_CLIENTMSP )
				export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORG3_P1_ASSETS_CACERT
				export FABRIC_CA_CLIENT_MSPDIR=$TC_ORG3_CLIENTMSP
				fabric-ca-client enroll -u https://${TC_ORG3_CLIENT}:${TC_ORG3_CLIENTPW}@0.0.0.0:${TC_ORG3_C1_PORT} 2>&1
			)
			commonVerify $? "failed: $out" "$out"

			local clientcert="${TC_ORG3_CLIENTMSP}/signcerts/cert.pem"
			for destNode in "${TC_ORG3_P1_MSP}" "${TC_ORG3_P2_MSP}" "${TC_ORG3_P3_MSP}"
			do
				_disseminate "$clientcert" "${destNode}/users/${TC_ORG3_CLIENT}.pem"
			done

			# endregion: client

			unset destNode destLocal
			unset out

		}
		commonYN "eroll ${TC_ORG3_STACK} users?" _enrollUsers

		# endregion: enroll users
		# region: launch peers

		_launch() {

			local out

			commonPrintf "launching peers"
			# out=$( docker service update --replicas 1 ${TC_NETWORK_NAME}_${TC_ORG3_STACK}_${TC_ORG3_P1_NAME} 2>&1 )
			# commonVerify $? "failed $out" "$out"
			docker service update --replicas 1 ${TC_NETWORK_NAME}_${TC_ORG3_STACK}_${TC_ORG3_P1_NAME}
			commonVerify $? "failed"
			docker service update --replicas 1 ${TC_NETWORK_NAME}_${TC_ORG3_STACK}_${TC_ORG3_P2_NAME}
			commonVerify $? "failed"
			docker service update --replicas 1 ${TC_NETWORK_NAME}_${TC_ORG3_STACK}_${TC_ORG3_P3_NAME}
			commonVerify $? "failed"

			unset out
		}
		commonYN "launch ${TC_ORG3_STACK} peers?" _launch

		# endregion: launch peers
		# region: update replicas

		_replicas() {
			commonPrintf "updating peer replicas"
			yq -i ".services.${TC_ORG3_P1_NAME}.deploy.replicas=1" ${TC_PATH_SWARM}/*_${TC_ORG3_STACK}.yaml
			yq -i ".services.${TC_ORG3_P2_NAME}.deploy.replicas=1" ${TC_PATH_SWARM}/*_${TC_ORG3_STACK}.yaml
			yq -i ".services.${TC_ORG3_P3_NAME}.deploy.replicas=1" ${TC_PATH_SWARM}/*_${TC_ORG3_STACK}.yaml
		}
		commonYN "update replicas in swarm config?" _replicas

		# endregion: update replicas

		unset out
	}

	[[ "$TC_EXEC_DRY" == false ]] && commonYN "bootstrap ${TC_ORG3_STACK}, register and enroll identities?" _Org3

	# endregion: org3

# endregion: endorser orgs
# region: common services

	# region: bootstrap COMMON2

	_bootstrapCommon2() {
		commonPrintf "bootstrapping >>>${TC_COMMON2_STACK}<<<"
		${TC_PATH_SCRIPTS}/tcBootstrap.sh -m up -s ${TC_COMMON2_STACK}
		commonVerify $? "failed!"
	}
	commonYN "bootstrap ${TC_COMMON2_STACK}?" _bootstrapCommon2

	# endregion: bootstrap COMMON2
	# region: bootstrap COMMON3

	_bootstrapCommon3() {
		commonPrintf "bootstrapping >>>${TC_COMMON3_STACK}<<<"
		${TC_PATH_SCRIPTS}/tcBootstrap.sh -m up -s ${TC_COMMON3_STACK}
		commonVerify $? "failed!"
	}
	commonYN "bootstrap ${TC_COMMON3_STACK}?" _bootstrapCommon3

	# endregion: bootstrap COMMON3

# endregion: common services
# region: channels

_channels() {

	local out
	local cfpath="${TC_PATH_CHANNELS}"

	# region: create channels and join orgs


	for chname in "$TC_CHANNEL1_NAME" "$TC_CHANNEL2_NAME"
	do

		
		local gblock="${TC_PATH_CHANNELS}/${chname}/genesis_block.pb"

		# region: genesis block

		_genesis() {
			commonPrintf "configtxgen genesis block for $chname ($cfpath)"
			out=$(
				export FABRIC_CFG_PATH="$cfpath"
				configtxgen -profile $TC_CHANNEL_PROFILE -outputBlock ${gblock} -channelID $chname  2>&1
			)
			commonVerify $? "failed: $out" "$out"
		}
		commonYN "create genesis block for ${chname}?" _genesis

		# endregion: genesis block
		# region: join orderers

		_joinOrderers() {

			# region: o1

			commonPrintf "joining $TC_ORDERER1_O1_NAME:${TC_ORDERER1_O1_PORT} to $chname"
			out=$(
				export FABRIC_CFG_PATH="$cfpath"
				export OSN_TLS_CA_ROOT_CERT=$TC_ORDERER1_O1_ASSETS_TLSCERT
				export ADMIN_TLS_SIGN_CERT=${TC_ORDERER1_ADMINTLSMSP}/signcerts/cert.pem
				export ADMIN_TLS_PRIVATE_KEY=${TC_ORDERER1_ADMINTLSMSP}/keystore/key.pem
				osnadmin channel join --channelID $chname  --config-block $gblock -o localhost:${TC_ORDERER1_O1_ADMINPORT} --ca-file $OSN_TLS_CA_ROOT_CERT --client-cert $ADMIN_TLS_SIGN_CERT --client-key $ADMIN_TLS_PRIVATE_KEY  2>&1
			)
			commonVerify $? "failed: $out" "$out"

			# endregion: o1
			# region: o2

			commonPrintf "joining $TC_ORDERER1_O2_NAME:${TC_ORDERER1_O2_PORT} to $chname"
			out=$(
				export FABRIC_CFG_PATH="$cfpath"
				export OSN_TLS_CA_ROOT_CERT=$TC_ORDERER1_O2_ASSETS_TLSCERT
				export ADMIN_TLS_SIGN_CERT=${TC_ORDERER1_ADMINTLSMSP}/signcerts/cert.pem
				export ADMIN_TLS_PRIVATE_KEY=${TC_ORDERER1_ADMINTLSMSP}/keystore/key.pem
				osnadmin channel join --channelID $chname  --config-block $gblock -o localhost:${TC_ORDERER1_O2_ADMINPORT} --ca-file $OSN_TLS_CA_ROOT_CERT --client-cert $ADMIN_TLS_SIGN_CERT --client-key $ADMIN_TLS_PRIVATE_KEY  2>&1
			)
			commonVerify $? "failed: $out" "$out"

			# endregion: o2
			# region: o3

			commonPrintf "joining $TC_ORDERER1_O3_NAME:${TC_ORDERER1_O3_PORT} to $chname"
			out=$(
				export FABRIC_CFG_PATH="$cfpath"
				export OSN_TLS_CA_ROOT_CERT=$TC_ORDERER1_O3_ASSETS_TLSCERT
				export ADMIN_TLS_SIGN_CERT=${TC_ORDERER1_ADMINTLSMSP}/signcerts/cert.pem
				export ADMIN_TLS_PRIVATE_KEY=${TC_ORDERER1_ADMINTLSMSP}/keystore/key.pem
				osnadmin channel join --channelID $chname  --config-block $gblock -o localhost:${TC_ORDERER1_O3_ADMINPORT} --ca-file $OSN_TLS_CA_ROOT_CERT --client-cert $ADMIN_TLS_SIGN_CERT --client-key $ADMIN_TLS_PRIVATE_KEY  2>&1
			)
			commonVerify $? "failed: $out" "$out"

			# endregion: o3
			# region: status

			commonPrintf "getting status of $chname"
			out=$(
				export FABRIC_CFG_PATH="$cfpath"
				export OSN_TLS_CA_ROOT_CERT=$TC_ORDERER1_O1_ASSETS_TLSCERT
				export ADMIN_TLS_SIGN_CERT=${TC_ORDERER1_ADMINTLSMSP}/signcerts/cert.pem
				export ADMIN_TLS_PRIVATE_KEY=${TC_ORDERER1_ADMINTLSMSP}/keystore/key.pem
				osnadmin channel list --channelID $chname -o localhost:${TC_ORDERER1_O1_ADMINPORT} --ca-file $OSN_TLS_CA_ROOT_CERT --client-cert $ADMIN_TLS_SIGN_CERT --client-key $ADMIN_TLS_PRIVATE_KEY  2>&1
			)
			commonVerify $? "failed: $out" "$out"

			# endregion: status

		}
		commonYN "join orderers?" _joinOrderers

		# endregion: join orderers
		# region: join peers

		_joinPeers() {

			# region: org1

			_joinOrg1() {
				commonPrintf "joining $TC_ORG1_STACK peers" 
				for port in $TC_ORG1_P1_PORT $TC_ORG1_P2_PORT $TC_ORG1_P3_PORT
				do
					out=$(
						export FABRIC_CFG_PATH="$cfpath"
						export CORE_PEER_TLS_ENABLED=true
						export CORE_PEER_LOCALMSPID="${TC_ORG1_STACK}MSP"
						export CORE_PEER_TLS_ROOTCERT_FILE=${TC_ORG1_DATA}/msp/tlscacerts/ca-cert.pem
						export CORE_PEER_MSPCONFIGPATH=$TC_ORG1_ADMINMSP
						export CORE_PEER_ADDRESS=localhost:${port}
						peer channel join -b $gblock  2>&1
					)
					commonVerify $? "failed: $out" "$out"
				done
			}
			commonYN "join $TC_ORG1_STACK peers to $chname?" _joinOrg1

			# endregion: org1
			# region: org2

			_joinOrg2() {
				commonPrintf "joining $TC_ORG2_STACK peers" 
				for port in $TC_ORG2_P1_PORT $TC_ORG2_P2_PORT $TC_ORG2_P3_PORT
				do
					out=$(
						export FABRIC_CFG_PATH="$cfpath"
						export CORE_PEER_TLS_ENABLED=true
						export CORE_PEER_LOCALMSPID="${TC_ORG2_STACK}MSP"
						export CORE_PEER_TLS_ROOTCERT_FILE=${TC_ORG2_DATA}/msp/tlscacerts/ca-cert.pem
						export CORE_PEER_MSPCONFIGPATH=$TC_ORG2_ADMINMSP
						export CORE_PEER_ADDRESS=localhost:${port}
						peer channel join -b $gblock  2>&1
					)
					commonVerify $? "failed: $out" "$out"
				done
			}
			commonYN "join $TC_ORG2_STACK peers to $chname?" _joinOrg2

			# endregion: org2
			# region: org3

			_joinOrg3() {
				commonPrintf "joining $TC_ORG3_STACK peers" 
				for port in $TC_ORG3_P1_PORT $TC_ORG3_P2_PORT $TC_ORG3_P3_PORT
				do
					out=$(
						export FABRIC_CFG_PATH="$cfpath"
						export CORE_PEER_TLS_ENABLED=true
						export CORE_PEER_LOCALMSPID="${TC_ORG3_STACK}MSP"
						export CORE_PEER_TLS_ROOTCERT_FILE=${TC_ORG3_DATA}/msp/tlscacerts/ca-cert.pem
						export CORE_PEER_MSPCONFIGPATH=$TC_ORG3_ADMINMSP
						export CORE_PEER_ADDRESS=localhost:${port}
						peer channel join -b $gblock  2>&1
					)
					commonVerify $? "failed: $out" "$out"
				done
			}
			commonYN "join $TC_ORG3_STACK peers to $chname?" _joinOrg3

			# endregion: org3:

		}
		commonYN "join peers to $chname?" _joinPeers

		# endregion: join peers

	done

	# endregion: create channels
	# region: status

	commonPrintf "listing all the channels on orderer1_o1"
	out=$(
		export OSN_TLS_CA_ROOT_CERT=$TC_ORDERER1_O1_ASSETS_TLSCERT
		export ADMIN_TLS_SIGN_CERT=${TC_ORDERER1_ADMINTLSMSP}/signcerts/cert.pem
		export ADMIN_TLS_PRIVATE_KEY=${TC_ORDERER1_ADMINTLSMSP}/keystore/key.pem
		osnadmin channel list -o localhost:${TC_ORDERER1_O1_ADMINPORT} --ca-file $OSN_TLS_CA_ROOT_CERT --client-cert $ADMIN_TLS_SIGN_CERT --client-key $ADMIN_TLS_PRIVATE_KEY  2>&1
	)
	commonVerify $? "failed: $out" "$out"

	commonPrintf "listing all the channels on org1_p1"
	out=$(
		export FABRIC_CFG_PATH="${cfpath}"
		export CORE_PEER_TLS_ENABLED=true
		export CORE_PEER_LOCALMSPID="${TC_ORG1_STACK}MSP"
		export CORE_PEER_TLS_ROOTCERT_FILE=${TC_ORG1_DATA}/msp/tlscacerts/ca-cert.pem
		export CORE_PEER_MSPCONFIGPATH=$TC_ORG1_ADMINMSP
		export CORE_PEER_ADDRESS=localhost:${TC_ORG1_P1_PORT}
		peer channel list  2>&1
	)
	commonVerify $? "failed: $out" "$out"

	for chname in "$TC_CHANNEL1_NAME" "$TC_CHANNEL2_NAME"
	do
		commonPrintf "get info for $chname on org1_p1"
		out=$(
			export FABRIC_CFG_PATH="$cfpath"
			export CORE_PEER_TLS_ENABLED=true
			export CORE_PEER_LOCALMSPID="${TC_ORG1_STACK}MSP"
			export CORE_PEER_TLS_ROOTCERT_FILE=${TC_ORG1_DATA}/msp/tlscacerts/ca-cert.pem
			export CORE_PEER_MSPCONFIGPATH=$TC_ORG1_ADMINMSP
			export CORE_PEER_ADDRESS=localhost:${TC_ORG1_P1_PORT}
			peer channel getinfo -c $chname  2>&1
		)
		commonVerify $? "failed: $out" "$out"
	done

	# endregion: status

}

[[ "$TC_EXEC_DRY" == false ]] && commonYN "create channels?" _channels

# endregion: channels
# region: deploy chaincode

ccVersion=1
# [[ "$TC_EXEC_DRY" == false ]] && commonYN "install te-food-bundles chaincode on endoreser peers?" ${TC_PATH_SCRIPTS}/tcChaincodeInstall.sh "basic" $ccVersion
# [[ "$TC_EXEC_DRY" == false ]] && commonYN "approve te-food-bundles chaincode on ${TC_CHANNEL1_NAME}?" ${TC_PATH_SCRIPTS}/tcChaincodeAprove.sh "basic" "$TC_CHANNEL1_NAME" $ccVersion

[[ "$TC_EXEC_DRY" == false ]] && commonYN "install te-food-bundles chaincode on endoreser peers?" ${TC_PATH_SCRIPTS}/tcChaincodeInstall.sh "te-food-bundles" $ccVersion
[[ "$TC_EXEC_DRY" == false ]] && commonYN "approve te-food-bundles chaincode on ${TC_CHANNEL1_NAME}?" ${TC_PATH_SCRIPTS}/tcChaincodeAprove.sh "te-food-bundles" "$TC_CHANNEL1_NAME" $ccVersion
[[ "$TC_EXEC_DRY" == false ]] && commonYN "approve te-food-bundles chaincode on ${TC_CHANNEL2_NAME}?" ${TC_PATH_SCRIPTS}/tcChaincodeAprove.sh "te-food-bundles" "$TC_CHANNEL2_NAME" $ccVersion
unset ccVersion

# endregion: deploy chaincode
# region: raw api

_buildRaw() {
	local out

	commonPrintf "building raw api"
	commonPP ${TC_PATH_BASE}/rawapi
	out=$( go mod tidy 2>&1 )
	commonVerify $? "failed: $out"
	out=$( CGO_ENABLED=0 go build main.go 2>&1 )
	commonVerify $? "failed: $out"

	commonPrintf "moving binary under $TC_ORG1_G1_ASSETS_DIR"
	out=$( mv main ${TC_ORG1_G1_ASSETS_DIR}/ 2>&1 )
	commonVerify $? "failed: $out"

	commonPrintf "redeploy ${TC_NETWORK_NAME}_${TC_ORG1_STACK}_${TC_ORG1_G1_NAME}"
	out=$( docker service update --replicas 0 ${TC_NETWORK_NAME}_${TC_ORG1_STACK}_${TC_ORG1_G1_NAME} 2>&1 )
	commonVerify $? "failed: $out"
	commonSleep $TC_SWARM_DELAY "waiting for the service to be taken down"
	out=$( docker service update --replicas 1 ${TC_NETWORK_NAME}_${TC_ORG1_STACK}_${TC_ORG1_G1_NAME} 2>&1 )
	commonVerify $? "failed: $out"

	commonPrintf "updating ${TC_NETWORK_NAME}-${TC_ORG1_STACK}_${TC_ORG1_G1_NAME} replica # in stack config"
	out=$( yq -i ".services.${TC_ORG1_G1_NAME}.deploy.replicas=1" ${TC_PATH_SWARM}/*_${TC_ORG1_STACK}.yaml )
	commonVerify $? "failed: $out"
}
commonYN "build raw api?" _buildRaw

# endregion: raw api
# region: closing provisions

_prefix="$COMMON_PREFIX"
COMMON_PREFIX="===>>> "
commonPrintfBold " "
commonPrintfBold "ALL DONE! IF THIS IS FINAL, ISSUE THE FOLLOWING COMMAND: sudo chmod a-x ${TC_PATH_SCRIPTS}/_tcGenesis.sh"
commonPrintfBold " "
COMMON_PREFIX="_prefix"
unset _prefix

# endregion: closing
