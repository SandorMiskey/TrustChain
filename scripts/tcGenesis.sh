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

commonPrintfBold "Note that certain environment variables must be set to work correctly."
commonYN "Did you reload the .env file?"

if [[ ${TC_PATH_SCRIPTS:-"unset"} == "unset" ]]; then
	commonVerify 1 "TC_PATH_SCRIPTS is unset"
fi
commonPP $TC_PATH_SCRIPTS

# endregion: config
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
	commonPrintf "removing $TC_PATH_STORAGE"
	err=$( sudo rm -Rf "$TC_PATH_STORAGE" )
	commonVerify $? $err
	err=$( mkdir "$TC_PATH_STORAGE" )
	commonVerify $? $err
}

[[ "$TC_EXEC_DRY" == false ]] && commonYN "wipe persistent data?" _WipePersistent

# endregion: remove config and persistent data
# region: process config templates

_Config() {
	# export DOCKER_NS='$(DOCKER_NS)'
	# export TWO_DIGIT_VERSION='$(TWO_DIGIT_VERSION)'
	commonPrintf "processing templates:"
	for template in $( find $TC_PATH_TEMPLATES/* ! -name '.*' -print ); do
		target=$( commonSetvar $template )
		target=$( echo $target | sed s+$TC_PATH_TEMPLATES+$TC_PATH_STORAGE+ )
		commonPrintf "$template -> $target"
		if [[ -d $template ]]; then
			err=$( mkdir -p "$target" )
			commonVerify $? $err
		elif [[ -f $template ]]; then
			( echo "cat <<EOF" ; cat $template ; echo EOF ) | sh > $target
			commonVerify $? "unable to process $template"
		else
			commonVerify 1 "$template is not valid"
		fi
	done
	unset templates
	unset target
}

[[ "$TC_EXEC_DRY" == false ]] && commonYN "process templates?" _Config

# endregion: process config templates
# region: swarm init

_SwarmLeave() {
	_leave() {
		local status
		status=$( docker swarm leave --force 2>&1 )
		commonVerify $? "$status" "swarm status: $status"
	}

	local force=$COMMON_FORCE
	COMMON_FORCE=$TC_EXEC_SURE
	commonYN "Removing the last manager erases all current state of the swarm. Are you sure?" _leave
	COMMON_FORCE=$force
}

_SwarmInit() {
	local token
	local status
	token=$( docker swarm init ${TC_SWARM_INIT} 2>&1 )
	status=$?
	commonVerify $status "$token"
	if [ $status -eq 0 ]; then
		local token=$( printf "$token" | tr -d '\n' | sed "s/.*--token //" | sed "s/ .*$//" )
		local file=${TC_SWARM_PATH}/swarm-worker-token
		commonPrintf "swarm worker token is $token"
		echo $token > $file
		commonVerify $? "unable to write worker token to $file" "worken token is writen to $file"
	fi
	unset token
	unset status
	unset file
}

_SwarmPrune() {
	_prune() {
		local status
		status=$( docker network prune -f 2>&1 )
		commonVerify $? "$status" "network prune: `echo $status`"
		status=$( docker volume prune -f 2>&1 )
		commonVerify $? "$status" "volume prune: `echo $status`"
		status=$( docker container prune -f 2>&1 )
		commonVerify $? "$status" "container prune: `echo $status`"
		status=$( docker image prune -f 2>&1 )
		commonVerify $? "$status" "image prune: `echo $status`"
	}

	local force=$COMMON_FORCE
	COMMON_FORCE=$TC_EXEC_SURE
	commonYN "This will remove all local stuff not used by at least one container. Are you sure?" _prune
	COMMON_FORCE=$force

	unset status
	unset force
}

if [ "$TC_EXEC_DRY" == false ]; then
	commonYN "leave docker swarm?" _SwarmLeave
	commonYN "init docker swarm?" _SwarmInit
	# commonYN "prune networks/volumes/containers/images?" _SwarmPrune
fi

# endregion: swarm init
# region: tls ca

_EnrollTLSAdmin() (

	local out

	# bootstrap tls ca
	commonPrintf "bootstrapping ${TC_TLSCA1_STACK}"
	${TC_PATH_SCRIPTS}/tcBootstrap.sh -m up -s ${TC_TLSCA1_STACK}
	commonVerify $? "failed!"

	# enroll tls ca admin
	commonPrintf "enrolling ${TC_TLSCA1_C1_ADMIN} with $TC_TLSCA1_C1_FQDN"
	export FABRIC_CA_CLIENT_TLS_CERTFILES=${TC_TLSCA1_C1_HOME}/ca-cert.pem
	export FABRIC_CA_CLIENT_HOME=${TC_TLSCA1_C1_DATA}/${TC_TLSCA1_C1_ADMIN}
	out=$( fabric-ca-client enroll -u https://${TC_TLSCA1_C1_ADMIN}:${TC_TLSCA1_C1_ADMINPW}@0.0.0.0:${TC_TLSCA1_C1_PORT}  2>&1 )
	commonVerify $? "failed to enroll tls admin: $out" "$out"

	# register orderer1 orderers
	commonPrintf "registering $TC_ORDERER1_DOMAIN orderers with $TC_TLSCA1_C1_FQDN" 
	out=$( fabric-ca-client register --id.name $TC_ORDERER1_O1_TLS_NAME --id.secret $TC_ORDERER1_O1_TLS_PW --id.type orderer -u https://0.0.0.0:${TC_TLSCA1_C1_PORT}  2>&1 )
	commonVerify $? "failed to register tls identity: $out" "$out"
	out=$( fabric-ca-client register --id.name $TC_ORDERER1_O2_TLS_NAME --id.secret $TC_ORDERER1_O2_TLS_PW --id.type orderer -u https://0.0.0.0:${TC_TLSCA1_C1_PORT}  2>&1 )
	commonVerify $? "failed to register tls identity: $out" "$out"
	out=$( fabric-ca-client register --id.name $TC_ORDERER1_O3_TLS_NAME --id.secret $TC_ORDERER1_O3_TLS_PW --id.type orderer -u https://0.0.0.0:${TC_TLSCA1_C1_PORT}  2>&1 )
	commonVerify $? "failed to register tls identity: $out" "$out"

	# registering org1 peers
	commonPrintf "registering $TC_ORG1_DOMAIN peers and gw with $TC_TLSCA1_C1_FQDN" 
	out=$( fabric-ca-client register --id.name $TC_ORG1_G1_TLS_NAME --id.secret $TC_ORG1_G1_TLS_PW --id.type client -u https://0.0.0.0:${TC_TLSCA1_C1_PORT}  2>&1 )
	commonVerify $? "failed to register tls identity: $out" "$out"
	out=$( fabric-ca-client register --id.name $TC_ORG1_P1_TLS_NAME --id.secret $TC_ORG1_P1_TLS_PW --id.type peer -u https://0.0.0.0:${TC_TLSCA1_C1_PORT}  2>&1 )
	commonVerify $? "failed to register tls identity: $out" "$out"
	out=$( fabric-ca-client register --id.name $TC_ORG1_P2_TLS_NAME --id.secret $TC_ORG1_P2_TLS_PW --id.type peer -u https://0.0.0.0:${TC_TLSCA1_C1_PORT}  2>&1 )
	commonVerify $? "failed to register tls identity: $out" "$out"
	out=$( fabric-ca-client register --id.name $TC_ORG1_P3_TLS_NAME --id.secret $TC_ORG1_P3_TLS_PW --id.type peer -u https://0.0.0.0:${TC_TLSCA1_C1_PORT}  2>&1 )
	commonVerify $? "failed to register tls identity: $out" "$out"

	# registering org2 peers
	commonPrintf "registering $TC_ORG1_DOMAIN peers with $TC_TLSCA1_C1_FQDN" 
	out=$( fabric-ca-client register --id.name $TC_ORG2_P1_TLS_NAME --id.secret $TC_ORG2_P1_TLS_PW --id.type peer -u https://0.0.0.0:${TC_TLSCA1_C1_PORT}  2>&1 )
	commonVerify $? "failed to register tls identity: $out" "$out"
	out=$( fabric-ca-client register --id.name $TC_ORG2_P2_TLS_NAME --id.secret $TC_ORG2_P2_TLS_PW --id.type peer -u https://0.0.0.0:${TC_TLSCA1_C1_PORT}  2>&1 )
	commonVerify $? "failed to register tls identity: $out" "$out"
	out=$( fabric-ca-client register --id.name $TC_ORG2_P3_TLS_NAME --id.secret $TC_ORG2_P3_TLS_PW --id.type peer -u https://0.0.0.0:${TC_TLSCA1_C1_PORT}  2>&1 )
	commonVerify $? "failed to register tls identity: $out" "$out"

	unset out
)

[[ "$TC_EXEC_DRY" == false ]] && commonYN "bootstrap ${TC_TLSCA1_STACK}, enroll tls ca admin, then register peers and orderers?" _EnrollTLSAdmin

# endregion: tls ca
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
	# region: enroll org1 ca admin

	_enrollAdmin() {
		commonPrintf "enrolling ${TC_ORG1_C1_ADMIN} with $TC_ORG1_C1_FQDN"
		export FABRIC_CA_CLIENT_TLS_CERTFILES=${TC_ORG1_C1_HOME}/ca-cert.pem
		export FABRIC_CA_CLIENT_HOME=${TC_ORG1_C1_DATA}/${TC_ORG1_C1_ADMIN}
		out=$( fabric-ca-client enroll -u https://${TC_ORG1_C1_ADMIN}:${TC_ORG1_C1_ADMINPW}@0.0.0.0:${TC_ORG1_C1_PORT}  2>&1 )
		commonVerify $? "failed to enroll $TC_ORG1_C1_ADMIN: $out" "$out"
	}
	commonYN "enroll ${TC_ORG1_C1_ADMIN} with $TC_ORG1_C1_FQDN?" _enrollAdmin

	# endregion: enroll org1 ca admin
	# region: register org1 admin and users
	
	_registerUsers() {
		commonPrintf "registering ${TC_ORG1_STACK} admin, user and client with $TC_ORG1_C1_FQDN" 
		out=$( fabric-ca-client register --id.name $TC_ORG1_ADMIN --id.secret $TC_ORG1_ADMINPW --id.type admin --id.attrs "$TC_ORG1_ADMINATRS" -u https://0.0.0.0:${TC_ORG1_C1_PORT} 2>&1 )
		commonVerify $? "failed to register ${TC_ORG1_ADMIN}: $out" "$out"
		out=$( fabric-ca-client register --id.name $TC_ORG1_USER --id.secret $TC_ORG1_USERPW --id.type user -u https://0.0.0.0:${TC_ORG1_C1_PORT} 2>&1 )
		commonVerify $? "failed to register ${TC_ORG1_USER}: $out" "$out"
		out=$( fabric-ca-client register --id.name $TC_ORG1_CLIENT --id.secret $TC_ORG1_CLIENTPW --id.type client -u https://0.0.0.0:${TC_ORG1_C1_PORT} 2>&1 )
		commonVerify $? "failed to register ${TC_ORG1_CLIENT}: $out" "$out"
	}
	commonYN "register ${TC_ORG1_STACK} admin, user and client with ${TC_ORG1_C1_FQDN}?" _registerUsers

	# endregion: register org1 users
	# region: register org1 gw and peers

	_registerNodes() {
		commonPrintf "registering ${TC_ORG1_STACK}'s gw and peers with $TC_ORG1_C1_FQDN"
		out=$( fabric-ca-client register --id.name $TC_ORG1_G1_CA_NAME --id.secret $TC_ORG1_G1_CA_PW --id.type orderer -u https://0.0.0.0:${TC_ORG1_C1_PORT} 2>&1 )
		commonVerify $? "failed to register ${TC_ORG1_G1_CA_NAME}: $out" "$out"
		out=$( fabric-ca-client register --id.name $TC_ORG1_P1_CA_NAME --id.secret $TC_ORG1_P1_CA_PW --id.type orderer -u https://0.0.0.0:${TC_ORG1_C1_PORT} 2>&1 )
		commonVerify $? "failed to register ${TC_ORG1_P1_CA_NAME}: $out" "$out"
		out=$( fabric-ca-client register --id.name $TC_ORG1_P2_CA_NAME --id.secret $TC_ORG1_P2_CA_PW --id.type orderer -u https://0.0.0.0:${TC_ORG1_C1_PORT} 2>&1 )
		commonVerify $? "failed to register ${TC_ORG1_P2_CA_NAME}: $out" "$out"
		out=$( fabric-ca-client register --id.name $TC_ORG1_P3_CA_NAME --id.secret $TC_ORG1_P3_CA_PW --id.type orderer -u https://0.0.0.0:${TC_ORG1_C1_PORT} 2>&1 )
		commonVerify $? "failed to register ${TC_ORG1_O3_CA_NAME}: $out" "$out"
	}
	commonYN "register ${TC_ORG1_STACK}'s gw and peers with $TC_ORG1_C1_FQDN?" _registerNodes

	# endregion: register org1's gw and peers
	# region: copy root certs

	_rootCerts() {
		commonPrintf "acquiring root certs"
		local certCA=${TC_ORG1_C1_HOME}/ca-cert.pem
		local tlsCA=${TC_TLSCA1_C1_HOME}/ca-cert.pem
		mkdir -p $( dirname $TC_ORG1_G1_ASSETS_CACERT )
		mkdir -p $( dirname $TC_ORG1_G1_ASSETS_TLSCERT )
		mkdir -p $( dirname $TC_ORG1_P1_ASSETS_CACERT )
		mkdir -p $( dirname $TC_ORG1_P1_ASSETS_TLSCERT )
		mkdir -p $( dirname $TC_ORG1_P2_ASSETS_CACERT )
		mkdir -p $( dirname $TC_ORG1_P2_ASSETS_TLSCERT )
		mkdir -p $( dirname $TC_ORG1_P3_ASSETS_CACERT )
		mkdir -p $( dirname $TC_ORG1_P3_ASSETS_TLSCERT )
		cp $certCA $TC_ORG1_G1_ASSETS_CACERT
		cp $tlsCA $TC_ORG1_G1_ASSETS_TLSCERT
		cp $certCA $TC_ORG1_P1_ASSETS_CACERT
		cp $tlsCA $TC_ORG1_P1_ASSETS_TLSCERT
		cp $certCA $TC_ORG1_P2_ASSETS_CACERT
		cp $tlsCA $TC_ORG1_P2_ASSETS_TLSCERT
		cp $certCA $TC_ORG1_P3_ASSETS_CACERT
		cp $tlsCA $TC_ORG1_P3_ASSETS_TLSCERT
	}
	commonYN "acquire root certs for peers?" _rootCerts

	# endregion: root certs	
	# region: enroll peers

	_enrollPeers() {

		# region: g1

		commonPrintf "enrolling g1 with $TC_ORG1_C1_FQDN" 
		export FABRIC_CA_CLIENT_HOME=${TC_ORG1_G1_DATA}
		export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORG1_G1_ASSETS_CACERT
		export FABRIC_CA_CLIENT_MSPDIR=$TC_ORG1_G1_MSP
		out=$( fabric-ca-client enroll -u https://${TC_ORG1_G1_CA_NAME}:${TC_ORG1_G1_CA_PW}@0.0.0.0:${TC_ORG1_C1_PORT} 2>&1 )
		commonVerify $? "failed: $out" "$out"

		commonPrintf "enrolling g1 with $TC_TLSCA1_C1_FQDN"
		export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORG1_G1_ASSETS_TLSCERT
		export FABRIC_CA_CLIENT_MSPDIR=$TC_ORG1_G1_TLSMSP
		out=$( fabric-ca-client enroll -u https://${TC_ORG1_G1_TLS_NAME}:${TC_ORG1_G1_TLS_PW}@0.0.0.0:${TC_TLSCA1_C1_PORT} --enrollment.profile tls --csr.hosts ${TC_ORG1_G1_FQDN} 2>&1 )
		commonVerify $? "failed: $out" "$out"
		mv ${TC_ORG1_G1_TLSMSP}/keystore/* ${TC_ORG1_G1_TLSMSP}/keystore/key.pem 
		commonVerify $? "failed to rename key.pem: $out" "$out"

		# endregion: g1
		# region: p1

		commonPrintf "enrolling p1 with $TC_ORG1_C1_FQDN" 
		export FABRIC_CA_CLIENT_HOME=${TC_ORG1_P1_DATA}
		export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORG1_P1_ASSETS_CACERT
		export FABRIC_CA_CLIENT_MSPDIR=$TC_ORG1_P1_MSP
		out=$( fabric-ca-client enroll -u https://${TC_ORG1_P1_CA_NAME}:${TC_ORG1_P1_CA_PW}@0.0.0.0:${TC_ORG1_C1_PORT} 2>&1 )
		commonVerify $? "failed: $out" "$out"

		commonPrintf "enrolling with $TC_TLSCA1_C1_FQDN"
		export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORG1_P1_ASSETS_TLSCERT
		export FABRIC_CA_CLIENT_MSPDIR=$TC_ORG1_P1_TLSMSP
		out=$( fabric-ca-client enroll -u https://${TC_ORG1_P1_TLS_NAME}:${TC_ORG1_P1_TLS_PW}@0.0.0.0:${TC_TLSCA1_C1_PORT} --enrollment.profile tls --csr.hosts ${TC_ORG1_P1_FQDN} 2>&1 )
		commonVerify $? "failed: $out" "$out"
		mv ${TC_ORG1_P1_TLSMSP}/keystore/* ${TC_ORG1_P1_TLSMSP}/keystore/key.pem 
		commonVerify $? "failed to rename key.pem: $out" "$out"

		# endregion: p1
		# region: p2

		commonPrintf "enrolling p2 with $TC_ORG1_C1_FQDN" 
		export FABRIC_CA_CLIENT_HOME=${TC_ORG1_P2_DATA}
		export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORG1_P2_ASSETS_CACERT
		export FABRIC_CA_CLIENT_MSPDIR=$TC_ORG1_P2_MSP
		out=$( fabric-ca-client enroll -u https://${TC_ORG1_P2_CA_NAME}:${TC_ORG1_P2_CA_PW}@0.0.0.0:${TC_ORG1_C1_PORT} 2>&1 )
		commonVerify $? "failed: $out" "$out"

		commonPrintf "enrolling with $TC_TLSCA1_C1_FQDN"
		export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORG1_P2_ASSETS_TLSCERT
		export FABRIC_CA_CLIENT_MSPDIR=$TC_ORG1_P2_TLSMSP
		out=$( fabric-ca-client enroll -u https://${TC_ORG1_P2_TLS_NAME}:${TC_ORG1_P2_TLS_PW}@0.0.0.0:${TC_TLSCA1_C1_PORT} --enrollment.profile tls --csr.hosts ${TC_ORG1_P2_FQDN} 2>&1 )
		commonVerify $? "failed: $out" "$out"
		mv ${TC_ORG1_P2_TLSMSP}/keystore/* ${TC_ORG1_P2_TLSMSP}/keystore/key.pem 
		commonVerify $? "failed to rename key.pem: $out" "$out"

		# endregion: p2
		# region: p3

		commonPrintf "enrolling p3 with $TC_ORG1_C1_FQDN" 
		export FABRIC_CA_CLIENT_HOME=${TC_ORG1_P3_DATA}
		export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORG1_P3_ASSETS_CACERT
		export FABRIC_CA_CLIENT_MSPDIR=$TC_ORG1_P3_MSP
		out=$( fabric-ca-client enroll -u https://${TC_ORG1_P3_CA_NAME}:${TC_ORG1_P3_CA_PW}@0.0.0.0:${TC_ORG1_C1_PORT} 2>&1 )
		commonVerify $? "failed: $out" "$out"

		commonPrintf "enrolling with $TC_TLSCA1_C1_FQDN"
		export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORG1_P3_ASSETS_TLSCERT
		export FABRIC_CA_CLIENT_MSPDIR=$TC_ORG1_P3_TLSMSP
		out=$( fabric-ca-client enroll -u https://${TC_ORG1_P3_TLS_NAME}:${TC_ORG1_P3_TLS_PW}@0.0.0.0:${TC_TLSCA1_C1_PORT} --enrollment.profile tls --csr.hosts ${TC_ORG1_P3_FQDN} 2>&1 )
		commonVerify $? "failed: $out" "$out"
		mv ${TC_ORG1_P3_TLSMSP}/keystore/* ${TC_ORG1_P3_TLSMSP}/keystore/key.pem 
		commonVerify $? "failed to rename key.pem: $out" "$out"
		
		# endregion: p3
	
	}
	commonYN "enroll peers?" _enrollPeers

	# endregion: enroll peers
	# region: enroll users

	_enrollUsers() {

		local out

		# region: admin

		commonPrintf "enrolling $TC_ORG1_ADMIN"
		export FABRIC_CA_CLIENT_HOME=$TC_ORG1_ADMINHOME
		export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORG1_P1_ASSETS_CACERT
		export FABRIC_CA_CLIENT_MSPDIR=$TC_ORG1_ADMINMSP
		out=$( fabric-ca-client enroll -u https://${TC_ORG1_ADMIN}:${TC_ORG1_ADMINPW}@0.0.0.0:${TC_ORG1_C1_PORT} 2>&1 )
		commonVerify $? "failed: $out" "$out"

		commonPrintf "disseminating admin signcerts"
		out=$( mkdir ${TC_ORG1_G1_MSP}/admincerts 2>&1 )
		commonVerify $? "failed: $out" "mk admincerts dir suceeded"
		out=$( cp ${TC_ORG1_ADMINMSP}/signcerts/cert.pem ${TC_ORG1_G1_MSP}/admincerts/${TC_ORG1_ADMIN}.pem 2>&1 )
		commonVerify $? "failed: $out" "${TC_ORG1_ADMIN} signcert copied to $TC_ORG1_G1_MSP"

		out=$( mkdir ${TC_ORG1_P1_MSP}/admincerts 2>&1 )
		commonVerify $? "failed: $out" "mk admincerts dir suceeded"
		out=$( cp ${TC_ORG1_ADMINMSP}/signcerts/cert.pem ${TC_ORG1_P1_MSP}/admincerts/${TC_ORG1_ADMIN}.pem 2>&1 )
		commonVerify $? "failed: $out" "${TC_ORG1_ADMIN} signcert copied to $TC_ORG1_P1_MSP"

		out=$( mkdir ${TC_ORG1_P2_MSP}/admincerts 2>&1 )
		commonVerify $? "failed: $out" "mk admincerts dir suceeded"
		out=$( cp ${TC_ORG1_ADMINMSP}/signcerts/cert.pem ${TC_ORG1_P2_MSP}/admincerts/${TC_ORG1_ADMIN}.pem 2>&1 )
		commonVerify $? "failed: $out" "${TC_ORG1_ADMIN} signcert copied to $TC_ORG1_P2_MSP"

		out=$( mkdir ${TC_ORG1_P3_MSP}/admincerts 2>&1 )
		commonVerify $? "failed: $out" "mk admincerts dir suceeded"
		out=$( cp ${TC_ORG1_ADMINMSP}/signcerts/cert.pem ${TC_ORG1_P3_MSP}/admincerts/${TC_ORG1_ADMIN}.pem 2>&1 )
		commonVerify $? "failed: $out" "${TC_ORG1_ADMIN} signcert copied to $TC_ORG1_P3_MSP"

		# endregion: admin
		# region: user

		commonPrintf "enrolling $TC_ORG1_USER"
		export FABRIC_CA_CLIENT_HOME=$( dirname $TC_ORG1_USERMSP )
		export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORG1_P1_ASSETS_CACERT
		export FABRIC_CA_CLIENT_MSPDIR=$TC_ORG1_USERMSP
		out=$( fabric-ca-client enroll -u https://${TC_ORG1_USER}:${TC_ORG1_USERPW}@0.0.0.0:${TC_ORG1_C1_PORT} 2>&1 )
		commonVerify $? "failed: $out" "$out"

		# endregion: user
		# region: client

		commonPrintf "enrolling $TC_ORG1_CLIENT"
		export FABRIC_CA_CLIENT_HOME=$( dirname $TC_ORG1_CLIENTMSP )
		export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORG1_P1_ASSETS_CACERT
		export FABRIC_CA_CLIENT_MSPDIR=$TC_ORG1_CLIENTMSP
		out=$( fabric-ca-client enroll -u https://${TC_ORG1_CLIENT}:${TC_ORG1_CLIENTPW}@0.0.0.0:${TC_ORG1_C1_PORT} 2>&1 )
		commonVerify $? "failed: $out" "$out"

		# endregion: client

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

		commonYN "don't forget to change the number of replicas in the generated docker stack configurations!" commonPrintfBold "I have spoken..."

		unset out
	}
	commonYN "launch ${TC_ORG1_STACK} peers?" _launch

	# endregion: launch peers

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
	# region: enroll org2 ca admin

	_enrollAdmin() {
		commonPrintf "enrolling ${TC_ORG2_C1_ADMIN} with $TC_ORG2_C1_FQDN"
		export FABRIC_CA_CLIENT_TLS_CERTFILES=${TC_ORG2_C1_HOME}/ca-cert.pem
		export FABRIC_CA_CLIENT_HOME=${TC_ORG2_C1_DATA}/${TC_ORG2_C1_ADMIN}
		out=$( fabric-ca-client enroll -u https://${TC_ORG2_C1_ADMIN}:${TC_ORG2_C1_ADMINPW}@0.0.0.0:${TC_ORG2_C1_PORT}  2>&1 )
		commonVerify $? "failed to enroll $TC_ORG2_C1_ADMIN: $out" "$out"
	}
	commonYN "enroll ${TC_ORG2_C1_ADMIN} with $TC_ORG2_C1_FQDN?" _enrollAdmin

	# endregion: enroll org2 ca admin
	# region: register org2 users
	
	_registerUsers() {
		commonPrintf "registering ${TC_ORG2_STACK} admin, user and client with $TC_ORG2_C1_FQDN" 
		out=$( fabric-ca-client register --id.name $TC_ORG2_ADMIN --id.secret $TC_ORG2_ADMINPW --id.type admin --id.attrs "$TC_ORG2_ADMINATRS" -u https://0.0.0.0:${TC_ORG2_C1_PORT} 2>&1 )
		commonVerify $? "failed to register ${TC_ORG2_ADMIN}: $out" "$out"
		# out=$( fabric-ca-client register --id.name $TC_ORG2_USER --id.secret $TC_ORG2_USERPW --id.type user -u https://0.0.0.0:${TC_ORG2_C1_PORT} 2>&1 )
		# commonVerify $? "failed to register ${TC_ORG2_USER}: $out" "$out"
		# out=$( fabric-ca-client register --id.name $TC_ORG2_CLIENT --id.secret $TC_ORG2_CLIENTPW --id.type client -u https://0.0.0.0:${TC_ORG2_C1_PORT} 2>&1 )
		commonVerify $? "failed to register ${TC_ORG2_CLIENT}: $out" "$out"
	}
	commonYN "register ${TC_ORG2_STACK} admin, user and client with ${TC_ORG2_C1_FQDN}?" _registerUsers

	# endregion: register org2 users
	# region: register org2 gw and peers

	_registerNodes() {
		commonPrintf "registering ${TC_ORG2_STACK}'s gw and peers with $TC_ORG2_C1_FQDN"
		# out=$( fabric-ca-client register --id.name $TC_ORG2_G1_CA_NAME --id.secret $TC_ORG2_G1_CA_PW --id.type orderer -u https://0.0.0.0:${TC_ORG2_C1_PORT} 2>&1 )
		# commonVerify $? "failed to register ${TC_ORG2_G1_CA_NAME}: $out" "$out"
		out=$( fabric-ca-client register --id.name $TC_ORG2_P1_CA_NAME --id.secret $TC_ORG2_P1_CA_PW --id.type orderer -u https://0.0.0.0:${TC_ORG2_C1_PORT} 2>&1 )
		commonVerify $? "failed to register ${TC_ORG2_P1_CA_NAME}: $out" "$out"
		out=$( fabric-ca-client register --id.name $TC_ORG2_P2_CA_NAME --id.secret $TC_ORG2_P2_CA_PW --id.type orderer -u https://0.0.0.0:${TC_ORG2_C1_PORT} 2>&1 )
		commonVerify $? "failed to register ${TC_ORG2_P2_CA_NAME}: $out" "$out"
		out=$( fabric-ca-client register --id.name $TC_ORG2_P3_CA_NAME --id.secret $TC_ORG2_P3_CA_PW --id.type orderer -u https://0.0.0.0:${TC_ORG2_C1_PORT} 2>&1 )
		commonVerify $? "failed to register ${TC_ORG2_O3_CA_NAME}: $out" "$out"
	}
	commonYN "register ${TC_ORG2_STACK}'s gw and peers with $TC_ORG2_C1_FQDN?" _registerNodes

	# endregion: register org2's gw and peers
	# region: copy root certs

	_rootCerts() {
		commonPrintf "acquiring root certs"
		local certCA=${TC_ORG2_C1_HOME}/ca-cert.pem
		local tlsCA=${TC_TLSCA1_C1_HOME}/ca-cert.pem
		# mkdir -p $( dirname $TC_ORG2_G1_ASSETS_CACERT )
		# mkdir -p $( dirname $TC_ORG2_G1_ASSETS_TLSCERT )
		mkdir -p $( dirname $TC_ORG2_P1_ASSETS_CACERT )
		mkdir -p $( dirname $TC_ORG2_P1_ASSETS_TLSCERT )
		mkdir -p $( dirname $TC_ORG2_P2_ASSETS_CACERT )
		mkdir -p $( dirname $TC_ORG2_P2_ASSETS_TLSCERT )
		mkdir -p $( dirname $TC_ORG2_P3_ASSETS_CACERT )
		mkdir -p $( dirname $TC_ORG2_P3_ASSETS_TLSCERT )
		# cp $certCA $TC_ORG2_G1_ASSETS_CACERT
		# cp $tlsCA $TC_ORG2_G1_ASSETS_TLSCERT
		cp $certCA $TC_ORG2_P1_ASSETS_CACERT
		cp $tlsCA $TC_ORG2_P1_ASSETS_TLSCERT
		cp $certCA $TC_ORG2_P2_ASSETS_CACERT
		cp $tlsCA $TC_ORG2_P2_ASSETS_TLSCERT
		cp $certCA $TC_ORG2_P3_ASSETS_CACERT
		cp $tlsCA $TC_ORG2_P3_ASSETS_TLSCERT
	}
	commonYN "acquire root certs for peers?" _rootCerts

	# endregion: root certs	
	# region: enroll peers

	_enrollPeers() {

		# region: g1

		# commonPrintf "enrolling g1 with $TC_ORG2_C1_FQDN" 
		# export FABRIC_CA_CLIENT_HOME=${TC_ORG2_G1_DATA}
		# export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORG2_G1_ASSETS_CACERT
		# export FABRIC_CA_CLIENT_MSPDIR=$TC_ORG2_G1_MSP
		# out=$( fabric-ca-client enroll -u https://${TC_ORG2_G1_CA_NAME}:${TC_ORG2_G1_CA_PW}@0.0.0.0:${TC_ORG2_C1_PORT} 2>&1 )
		# commonVerify $? "failed: $out" "$out"

		# commonPrintf "enrolling g1 with $TC_TLSCA1_C1_FQDN"
		# export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORG2_G1_ASSETS_TLSCERT
		# export FABRIC_CA_CLIENT_MSPDIR=$TC_ORG2_G1_TLSMSP
		# out=$( fabric-ca-client enroll -u https://${TC_ORG2_G1_TLS_NAME}:${TC_ORG2_G1_TLS_PW}@0.0.0.0:${TC_TLSCA1_C1_PORT} --enrollment.profile tls --csr.hosts ${TC_ORG2_G1_FQDN} 2>&1 )
		# commonVerify $? "failed: $out" "$out"
		# mv ${TC_ORG2_G1_TLSMSP}/keystore/* ${TC_ORG2_G1_TLSMSP}/keystore/key.pem 
		# commonVerify $? "failed to rename key.pem: $out" "$out"

		# endregion: g1
		# region: p1

		commonPrintf "enrolling p1 with $TC_ORG2_C1_FQDN" 
		export FABRIC_CA_CLIENT_HOME=${TC_ORG2_P1_DATA}
		export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORG2_P1_ASSETS_CACERT
		export FABRIC_CA_CLIENT_MSPDIR=$TC_ORG2_P1_MSP
		out=$( fabric-ca-client enroll -u https://${TC_ORG2_P1_CA_NAME}:${TC_ORG2_P1_CA_PW}@0.0.0.0:${TC_ORG2_C1_PORT} 2>&1 )
		commonVerify $? "failed: $out" "$out"

		commonPrintf "enrolling with $TC_TLSCA1_C1_FQDN"
		export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORG2_P1_ASSETS_TLSCERT
		export FABRIC_CA_CLIENT_MSPDIR=$TC_ORG2_P1_TLSMSP
		out=$( fabric-ca-client enroll -u https://${TC_ORG2_P1_TLS_NAME}:${TC_ORG2_P1_TLS_PW}@0.0.0.0:${TC_TLSCA1_C1_PORT} --enrollment.profile tls --csr.hosts ${TC_ORG2_P1_FQDN} 2>&1 )
		commonVerify $? "failed: $out" "$out"
		mv ${TC_ORG2_P1_TLSMSP}/keystore/* ${TC_ORG2_P1_TLSMSP}/keystore/key.pem 
		commonVerify $? "failed to rename key.pem: $out" "$out"

		# endregion: p1
		# region: p2

		commonPrintf "enrolling p2 with $TC_ORG2_C1_FQDN" 
		export FABRIC_CA_CLIENT_HOME=${TC_ORG2_P2_DATA}
		export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORG2_P2_ASSETS_CACERT
		export FABRIC_CA_CLIENT_MSPDIR=$TC_ORG2_P2_MSP
		out=$( fabric-ca-client enroll -u https://${TC_ORG2_P2_CA_NAME}:${TC_ORG2_P2_CA_PW}@0.0.0.0:${TC_ORG2_C1_PORT} 2>&1 )
		commonVerify $? "failed: $out" "$out"

		commonPrintf "enrolling with $TC_TLSCA1_C1_FQDN"
		export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORG2_P2_ASSETS_TLSCERT
		export FABRIC_CA_CLIENT_MSPDIR=$TC_ORG2_P2_TLSMSP
		out=$( fabric-ca-client enroll -u https://${TC_ORG2_P2_TLS_NAME}:${TC_ORG2_P2_TLS_PW}@0.0.0.0:${TC_TLSCA1_C1_PORT} --enrollment.profile tls --csr.hosts ${TC_ORG2_P2_FQDN} 2>&1 )
		commonVerify $? "failed: $out" "$out"
		mv ${TC_ORG2_P2_TLSMSP}/keystore/* ${TC_ORG2_P2_TLSMSP}/keystore/key.pem 
		commonVerify $? "failed to rename key.pem: $out" "$out"

		# endregion: p2
		# region: p3

		commonPrintf "enrolling p3 with $TC_ORG2_C1_FQDN" 
		export FABRIC_CA_CLIENT_HOME=${TC_ORG2_P3_DATA}
		export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORG2_P3_ASSETS_CACERT
		export FABRIC_CA_CLIENT_MSPDIR=$TC_ORG2_P3_MSP
		out=$( fabric-ca-client enroll -u https://${TC_ORG2_P3_CA_NAME}:${TC_ORG2_P3_CA_PW}@0.0.0.0:${TC_ORG2_C1_PORT} 2>&1 )
		commonVerify $? "failed: $out" "$out"

		commonPrintf "enrolling with $TC_TLSCA1_C1_FQDN"
		export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORG2_P3_ASSETS_TLSCERT
		export FABRIC_CA_CLIENT_MSPDIR=$TC_ORG2_P3_TLSMSP
		out=$( fabric-ca-client enroll -u https://${TC_ORG2_P3_TLS_NAME}:${TC_ORG2_P3_TLS_PW}@0.0.0.0:${TC_TLSCA1_C1_PORT} --enrollment.profile tls --csr.hosts ${TC_ORG2_P3_FQDN} 2>&1 )
		commonVerify $? "failed: $out" "$out"
		mv ${TC_ORG2_P3_TLSMSP}/keystore/* ${TC_ORG2_P3_TLSMSP}/keystore/key.pem 
		commonVerify $? "failed to rename key.pem: $out" "$out"
		
		# endregion: p3
	
	}
	commonYN "enroll peers?" _enrollPeers

	# endregion: enroll peers
	# region: enroll users

	_enrollUsers() {

		local out

		# region: admin

		commonPrintf "enrolling $TC_ORG2_ADMIN"
		export FABRIC_CA_CLIENT_HOME=$TC_ORG2_ADMINHOME
		export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORG2_P1_ASSETS_CACERT
		export FABRIC_CA_CLIENT_MSPDIR=$TC_ORG2_ADMINMSP
		out=$( fabric-ca-client enroll -u https://${TC_ORG2_ADMIN}:${TC_ORG2_ADMINPW}@0.0.0.0:${TC_ORG2_C1_PORT} 2>&1 )
		commonVerify $? "failed: $out" "$out"

		# commonPrintf "disseminating admin signcerts"
		# out=$( mkdir ${TC_ORG2_G1_MSP}/admincerts 2>&1 )
		# commonVerify $? "failed: $out" "mk admincerts dir suceeded"
		# out=$( cp ${TC_ORG2_ADMINMSP}/signcerts/cert.pem ${TC_ORG2_G1_MSP}/admincerts/${TC_ORG2_ADMIN}.pem 2>&1 )
		# commonVerify $? "failed: $out" "${TC_ORG2_ADMIN} signcert copied to $TC_ORG2_G1_MSP"

		out=$( mkdir ${TC_ORG2_P1_MSP}/admincerts 2>&1 )
		commonVerify $? "failed: $out" "mk admincerts dir suceeded"
		out=$( cp ${TC_ORG2_ADMINMSP}/signcerts/cert.pem ${TC_ORG2_P1_MSP}/admincerts/${TC_ORG2_ADMIN}.pem 2>&1 )
		commonVerify $? "failed: $out" "${TC_ORG2_ADMIN} signcert copied to $TC_ORG2_P1_MSP"

		out=$( mkdir ${TC_ORG2_P2_MSP}/admincerts 2>&1 )
		commonVerify $? "failed: $out" "mk admincerts dir suceeded"
		out=$( cp ${TC_ORG2_ADMINMSP}/signcerts/cert.pem ${TC_ORG2_P2_MSP}/admincerts/${TC_ORG2_ADMIN}.pem 2>&1 )
		commonVerify $? "failed: $out" "${TC_ORG2_ADMIN} signcert copied to $TC_ORG2_P2_MSP"

		out=$( mkdir ${TC_ORG2_P3_MSP}/admincerts 2>&1 )
		commonVerify $? "failed: $out" "mk admincerts dir suceeded"
		out=$( cp ${TC_ORG2_ADMINMSP}/signcerts/cert.pem ${TC_ORG2_P3_MSP}/admincerts/${TC_ORG2_ADMIN}.pem 2>&1 )
		commonVerify $? "failed: $out" "${TC_ORG2_ADMIN} signcert copied to $TC_ORG2_P3_MSP"

		# endregion: admin
		# region: user

		# commonPrintf "enrolling $TC_ORG2_USER"
		# export FABRIC_CA_CLIENT_HOME=$( dirname $TC_ORG2_USERMSP )
		# export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORG2_P1_ASSETS_CACERT
		# export FABRIC_CA_CLIENT_MSPDIR=$TC_ORG2_USERMSP
		# out=$( fabric-ca-client enroll -u https://${TC_ORG2_USER}:${TC_ORG2_USERPW}@0.0.0.0:${TC_ORG2_C1_PORT} 2>&1 )
		# commonVerify $? "failed: $out" "$out"

		# endregion: user
		# region: client

		# commonPrintf "enrolling $TC_ORG2_CLIENT"
		# export FABRIC_CA_CLIENT_HOME=$( dirname $TC_ORG2_CLIENTMSP )
		# export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORG2_P1_ASSETS_CACERT
		# export FABRIC_CA_CLIENT_MSPDIR=$TC_ORG2_CLIENTMSP
		# out=$( fabric-ca-client enroll -u https://${TC_ORG2_CLIENT}:${TC_ORG2_CLIENTPW}@0.0.0.0:${TC_ORG2_C1_PORT} 2>&1 )
		# commonVerify $? "failed: $out" "$out"

		# endregion: client

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

		commonYN "don't forget to change the number of replicas in the generated docker stack configurations!" commonPrintfBold "I have spoken..."

		unset out
	}
	commonYN "launch ${TC_ORG2_STACK} peers?" _launch

	# endregion: launch peers

	unset out
}

[[ "$TC_EXEC_DRY" == false ]] && commonYN "bootstrap ${TC_ORG2_STACK}, register and enroll identities?" _Org2

# endregion: org2
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
	# region: enroll ca admin

	_enrollAdmin() {
		commonPrintf "enrolling ${TC_ORDERER1_C1_ADMIN} with $TC_ORDERER1_C1_FQDN"
		export FABRIC_CA_CLIENT_TLS_CERTFILES=${TC_ORDERER1_C1_HOME}/ca-cert.pem
		export FABRIC_CA_CLIENT_HOME=${TC_ORDERER1_C1_DATA}/${TC_ORDERER1_C1_ADMIN}
		out=$( fabric-ca-client enroll -u https://${TC_ORDERER1_C1_ADMIN}:${TC_ORDERER1_C1_ADMINPW}@0.0.0.0:${TC_ORDERER1_C1_PORT}  2>&1 )
		commonVerify $? "failed to enroll $TC_ORDERER1_C1_ADMIN: $out" "$out"
	}
	commonYN "enroll ${TC_ORDERER1_C1_ADMIN} with $TC_ORDERER1_C1_FQDN?" _enrollAdmin

	# endregion: enroll ca admin
	# region: register orderer1 admin
	
	_registerUsers() {
		commonPrintf "registering ${TC_ORDERER1_STACK} admin with $TC_ORDERER1_C1_FQDN" 
		out=$( fabric-ca-client register --id.name $TC_ORDERER1_ADMIN --id.secret $TC_ORDERER1_ADMINPW --id.type admin --id.attrs "$TC_ORDERER1_ADMINATRS" -u https://0.0.0.0:${TC_ORDERER1_C1_PORT} 2>&1 )
		commonVerify $? "failed to register ${TC_ORDERER1_ADMIN}: $out" "$out"
	}
	commonYN "register ${TC_ORDERER1_STACK} admin with ${TC_ORDERER1_C1_FQDN}?" _registerUsers

	# endregion: register orderer1 admin
	# region: register orderer nodes 

	_registerNodes() {
		commonPrintf "registering ${TC_ORDERER1_STACK}'s orderers with $TC_ORDERER1_C1_FQDN"
		out=$( fabric-ca-client register --id.name $TC_ORDERER1_O1_CA_NAME --id.secret $TC_ORDERER1_O1_CA_PW --id.type orderer -u https://0.0.0.0:${TC_ORDERER1_C1_PORT} 2>&1 )
		commonVerify $? "failed to register ${TC_ORDERER1_O1_CA_NAME}: $out" "$out"
		out=$( fabric-ca-client register --id.name $TC_ORDERER1_O2_CA_NAME --id.secret $TC_ORDERER1_O2_CA_PW --id.type orderer -u https://0.0.0.0:${TC_ORDERER1_C1_PORT} 2>&1 )
		commonVerify $? "failed to register ${TC_ORDERER1_O2_CA_NAME}: $out" "$out"
		out=$( fabric-ca-client register --id.name $TC_ORDERER1_O3_CA_NAME --id.secret $TC_ORDERER1_O3_CA_PW --id.type orderer -u https://0.0.0.0:${TC_ORDERER1_C1_PORT} 2>&1 )
		commonVerify $? "failed to register ${TC_ORDERER1_O3_CA_NAME}: $out" "$out"
	}
	commonYN "register ${TC_ORDERER1_STACK}'s orderers with $TC_ORG1_C1_FQDN?" _registerNodes

	# endregion: register orderer nodes
	# region: copy root certs

	_rootCerts() {
		commonPrintf "acquiring root certs"
		local certCA=${TC_ORDERER1_C1_HOME}/ca-cert.pem
		local tlsCA=${TC_TLSCA1_C1_HOME}/ca-cert.pem
		mkdir -p $( dirname $TC_ORDERER1_O1_ASSETS_CACERT )
		mkdir -p $( dirname $TC_ORDERER1_O1_ASSETS_TLSCERT )
		mkdir -p $( dirname $TC_ORDERER1_O2_ASSETS_CACERT )
		mkdir -p $( dirname $TC_ORDERER1_O2_ASSETS_TLSCERT )
		mkdir -p $( dirname $TC_ORDERER1_O3_ASSETS_CACERT )
		mkdir -p $( dirname $TC_ORDERER1_O3_ASSETS_TLSCERT )
		cp $certCA $TC_ORDERER1_O1_ASSETS_CACERT
		cp $tlsCA $TC_ORDERER1_O1_ASSETS_TLSCERT
		cp $certCA $TC_ORDERER1_O2_ASSETS_CACERT
		cp $tlsCA $TC_ORDERER1_O2_ASSETS_TLSCERT
		cp $certCA $TC_ORDERER1_O3_ASSETS_CACERT
		cp $tlsCA $TC_ORDERER1_O3_ASSETS_TLSCERT
	}
	commonYN "acquire root certs for orderers?" _rootCerts

	# endregion: root certs
	# region: enroll orderers

	_enrollOrderers() {

		# region: o1

		commonPrintf "enrolling o1 with $TC_ORDERER1_C1_FQDN" 
		export FABRIC_CA_CLIENT_HOME=${TC_ORDERER1_O1_DATA}
		export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORDERER1_O1_ASSETS_CACERT
		export FABRIC_CA_CLIENT_MSPDIR=$TC_ORDERER1_O1_MSP
		out=$( fabric-ca-client enroll -u https://${TC_ORDERER1_O1_CA_NAME}:${TC_ORDERER1_O1_CA_PW}@0.0.0.0:${TC_ORDERER1_C1_PORT} 2>&1 )
		commonVerify $? "failed: $out" "$out"

		commonPrintf "enrolling with $TC_TLSCA1_C1_FQDN"
		export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORDERER1_O1_ASSETS_TLSCERT
		export FABRIC_CA_CLIENT_MSPDIR=$TC_ORDERER1_O1_TLSMSP
		out=$( fabric-ca-client enroll -u https://${TC_ORDERER1_O1_TLS_NAME}:${TC_ORDERER1_O1_TLS_PW}@0.0.0.0:${TC_TLSCA1_C1_PORT} --enrollment.profile tls --csr.hosts ${TC_ORDERER1_O1_FQDN} 2>&1 )
		commonVerify $? "failed: $out" "$out"
		mv ${TC_ORDERER1_O1_TLSMSP}/keystore/* ${TC_ORDERER1_O1_TLSMSP}/keystore/key.pem 
		commonVerify $? "failed to rename key.pem: $out" "$out"

		# endregion: o1
		# region: o2

		commonPrintf "enrolling o2 with $TC_ORDERER1_C1_FQDN" 
		export FABRIC_CA_CLIENT_HOME=${TC_ORDERER1_O2_DATA}
		export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORDERER1_O2_ASSETS_CACERT
		export FABRIC_CA_CLIENT_MSPDIR=$TC_ORDERER1_O2_MSP
		out=$( fabric-ca-client enroll -u https://${TC_ORDERER1_O2_CA_NAME}:${TC_ORDERER1_O2_CA_PW}@0.0.0.0:${TC_ORDERER1_C1_PORT} 2>&1 )
		commonVerify $? "failed: $out" "$out"

		commonPrintf "enrolling with $TC_TLSCA1_C1_FQDN"
		export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORDERER1_O2_ASSETS_TLSCERT
		export FABRIC_CA_CLIENT_MSPDIR=$TC_ORDERER1_O2_TLSMSP
		out=$( fabric-ca-client enroll -u https://${TC_ORDERER1_O2_TLS_NAME}:${TC_ORDERER1_O2_TLS_PW}@0.0.0.0:${TC_TLSCA1_C1_PORT} --enrollment.profile tls --csr.hosts ${TC_ORDERER1_O2_FQDN} 2>&1 )
		commonVerify $? "failed: $out" "$out"
		mv ${TC_ORDERER1_O2_TLSMSP}/keystore/* ${TC_ORDERER1_O2_TLSMSP}/keystore/key.pem 
		commonVerify $? "failed to rename key.pem: $out" "$out"

		# endregion: o2
		# region: p3

		commonPrintf "enrolling o3 with $TC_ORDERER1_C1_FQDN" 
		export FABRIC_CA_CLIENT_HOME=${TC_ORDERER1_O3_DATA}
		export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORDERER1_O3_ASSETS_CACERT
		export FABRIC_CA_CLIENT_MSPDIR=$TC_ORDERER1_O3_MSP
		out=$( fabric-ca-client enroll -u https://${TC_ORDERER1_O3_CA_NAME}:${TC_ORDERER1_O3_CA_PW}@0.0.0.0:${TC_ORDERER1_C1_PORT} 2>&1 )
		commonVerify $? "failed: $out" "$out"

		commonPrintf "enrolling with $TC_TLSCA1_C1_FQDN"
		export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORDERER1_O3_ASSETS_TLSCERT
		export FABRIC_CA_CLIENT_MSPDIR=$TC_ORDERER1_O3_TLSMSP
		out=$( fabric-ca-client enroll -u https://${TC_ORDERER1_O3_TLS_NAME}:${TC_ORDERER1_O3_TLS_PW}@0.0.0.0:${TC_TLSCA1_C1_PORT} --enrollment.profile tls --csr.hosts ${TC_ORDERER1_O3_FQDN} 2>&1 )
		commonVerify $? "failed: $out" "$out"
		mv ${TC_ORDERER1_O3_TLSMSP}/keystore/* ${TC_ORDERER1_O3_TLSMSP}/keystore/key.pem 
		commonVerify $? "failed to rename key.pem: $out" "$out"
		
		# endregion: o3
	
	}
	commonYN "enroll peers?" _enrollOrderers

	# endregion: enroll orderers
	# region: enroll users

	_enrollAdmin() {

		local out

		commonPrintf "enrolling $TC_ORDERER1_ADMIN"
		export FABRIC_CA_CLIENT_HOME=$TC_ORDERER1_ADMINHOME
		export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORDERER1_O1_ASSETS_CACERT
		export FABRIC_CA_CLIENT_MSPDIR=$TC_ORDERER1_ADMINMSP
		out=$( fabric-ca-client enroll -u https://${TC_ORDERER1_ADMIN}:${TC_ORDERER1_ADMINPW}@0.0.0.0:${TC_ORDERER1_C1_PORT} 2>&1 )
		commonVerify $? "failed: $out" "$out"

		commonPrintf "disseminating admin signcerts"

		out=$( mkdir ${TC_ORDERER1_O1_MSP}/admincerts 2>&1 )
		commonVerify $? "failed: $out" "mk admincerts dir suceeded"
		out=$( cp ${TC_ORDERER1_ADMINMSP}/signcerts/cert.pem ${TC_ORDERER1_O1_MSP}/admincerts/${TC_ORDERER1_ADMIN}.pem 2>&1 )
		commonVerify $? "failed: $out" "${TC_ORDERER1_ADMIN} signcert copied to $TC_ORDERER1_O1_MSP"

		out=$( mkdir ${TC_ORDERER1_O2_MSP}/admincerts 2>&1 )
		commonVerify $? "failed: $out" "mk admincerts dir suceeded"
		out=$( cp ${TC_ORDERER1_ADMINMSP}/signcerts/cert.pem ${TC_ORDERER1_O2_MSP}/admincerts/${TC_ORDERER1_ADMIN}.pem 2>&1 )
		commonVerify $? "failed: $out" "${TC_ORDERER1_ADMIN} signcert copied to $TC_ORDERER1_O2_MSP"

		out=$( mkdir ${TC_ORDERER1_O3_MSP}/admincerts 2>&1 )
		commonVerify $? "failed: $out" "mk admincerts dir suceeded"
		out=$( cp ${TC_ORDERER1_ADMINMSP}/signcerts/cert.pem ${TC_ORDERER1_O3_MSP}/admincerts/${TC_ORDERER1_ADMIN}.pem 2>&1 )
		commonVerify $? "failed: $out" "${TC_ORDERER1_ADMIN} signcert copied to $TC_ORDERER1_O3_MSP"

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
		docker service update --replicas 1 ${TC_NETWORK_NAME}_${TC_ORG1_STACK}_${TC_ORG1_P1_NAME}
		commonVerify $? "failed"
		docker service update --replicas 1 ${TC_NETWORK_NAME}_${TC_ORG1_STACK}_${TC_ORG1_P2_NAME}
		commonVerify $? "failed"
		docker service update --replicas 1 ${TC_NETWORK_NAME}_${TC_ORG1_STACK}_${TC_ORG1_P3_NAME}
		commonVerify $? "failed"

		commonYN "don't forget to change the number of replicas in the generated docker stack configurations!" commonPrintfBold "I have spoken..."

		unset out
	}
	# commonYN "launch ${TC_ORG1_STACK} peers?" _launch

	# endregion: launch peers

	unset out

}

[[ "$TC_EXEC_DRY" == false ]] && commonYN "bootstrap ${TC_ORDERER1_STACK}, enroll ca admin, and register identities?" _Orderer1

# endregion: orderer1
