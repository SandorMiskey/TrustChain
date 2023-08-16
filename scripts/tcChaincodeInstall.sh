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
# region: check params

export chaincode=$1
export version=$2

[[ -d "${TC_PATH_CHAINCODE}/${chaincode}" ]] || commonVerify 1 "${chaincode}: no such directory under $TC_PATH_CHAINCODE"
[[ -z "$version" ]] && export version="1" 

commonPrintfBold "chaincode: $chaincode"
commonPrintfBold "version: $version"

# endregion: check params

_deploy() {
	local out
	local path=${TC_PATH_CHAINCODE}/${chaincode}
	local certOrderer="${TC_ORDERER1_O1_TLSMSP}/tlscacerts/tls-0-0-0-0-${TC_COMMON1_C1_PORT}.pem" 

	commonPP $path

	# region: vendoring

	commonPrintf "vendoring modules"
	out=$( GO111MODULE=on go mod vendor  2>&1 )
	commonVerify $? "failed: $out"

	# endregion: vendoring
	# region: packing

	commonPrintf "packaging chaincode"
	out=$(
		export FABRIC_CFG_PATH="${TC_PATH_CHANNELS}"
		peer lifecycle chaincode package ${chaincode}.tar.gz --path $path --lang golang --label "${chaincode}_${version}.0" 2>&1
	)
	commonVerify $? "failed: $out"

	# endregion: packing
	# region: installing

	commonPrintf "install chaincode on $TC_ORG1_STACK peers"
	# for port in $TC_ORG1_P1_PORT
	for port in $TC_ORG1_P1_PORT $TC_ORG1_P2_PORT $TC_ORG1_P3_PORT
	do
		commonPrintf "targeting localhost:${port}"
		out=$(
			export FABRIC_CFG_PATH="${TC_PATH_CHANNELS}"
			export CORE_PEER_TLS_ENABLED=true
			export CORE_PEER_LOCALMSPID="${TC_ORG1_STACK}MSP"
			export CORE_PEER_TLS_ROOTCERT_FILE=${TC_ORG1_DATA}/msp/tlscacerts/ca-cert.pem
			export CORE_PEER_MSPCONFIGPATH=$TC_ORG1_ADMINMSP
			export CORE_PEER_ADDRESS=localhost:${port}
			peer lifecycle chaincode install ${chaincode}.tar.gz 2>&1
		)
		commonVerify $? "failed: $out" "$out"
	done

	commonPrintf "install chaincode on $TC_ORG2_STACK peers"
	# for port in $TC_ORG2_P1_PORT
	for port in $TC_ORG2_P1_PORT $TC_ORG2_P2_PORT $TC_ORG2_P3_PORT
	do
		commonPrintf "targeting localhost:${port}"
		out=$(
			export FABRIC_CFG_PATH="${TC_PATH_CHANNELS}"
			export CORE_PEER_TLS_ENABLED=true
			export CORE_PEER_LOCALMSPID="${TC_ORG2_STACK}MSP"
			export CORE_PEER_TLS_ROOTCERT_FILE=${TC_ORG2_DATA}/msp/tlscacerts/ca-cert.pem
			export CORE_PEER_MSPCONFIGPATH=$TC_ORG2_ADMINMSP
			export CORE_PEER_ADDRESS=localhost:${port}
			peer lifecycle chaincode install ${chaincode}.tar.gz 2>&1
		)
		commonVerify $? "failed: $out" "$out"
	done

	commonPrintf "install chaincode on $TC_ORG3_STACK peers"
	# for port in $TC_ORG3_P1_PORT
	for port in $TC_ORG3_P1_PORT $TC_ORG3_P2_PORT $TC_ORG3_P3_PORT
	do
		commonPrintf "targeting localhost:${port}"
		out=$(
			export FABRIC_CFG_PATH="${TC_PATH_CHANNELS}"
			export CORE_PEER_TLS_ENABLED=true
			export CORE_PEER_LOCALMSPID="${TC_ORG3_STACK}MSP"
			export CORE_PEER_TLS_ROOTCERT_FILE=${TC_ORG3_DATA}/msp/tlscacerts/ca-cert.pem
			export CORE_PEER_MSPCONFIGPATH=$TC_ORG3_ADMINMSP
			export CORE_PEER_ADDRESS=localhost:${port}
			peer lifecycle chaincode install ${chaincode}.tar.gz 2>&1
		)
		commonVerify $? "failed: $out" "$out"
	done

	# endregion: installing
	# region: packge id 

	commonPrintf "getting package id"
	out=$(
		export FABRIC_CFG_PATH="${TC_PATH_CHANNELS}"
		export CORE_PEER_TLS_ENABLED=true
		export CORE_PEER_LOCALMSPID="${TC_ORG1_STACK}MSP"
		export CORE_PEER_TLS_ROOTCERT_FILE=${TC_ORG1_DATA}/msp/tlscacerts/ca-cert.pem
		export CORE_PEER_MSPCONFIGPATH=$TC_ORG1_ADMINMSP
		export CORE_PEER_ADDRESS=localhost:${TC_ORG1_P1_PORT}
		peer lifecycle chaincode queryinstalled -O json  2>&1
	)
	commonVerify $? "failed: $out" "$out"
	local packageId=$( echo $out | jq -r ".installed_chaincodes[].package_id" | while read -r pkgid; do [[ "$pkgid" == "${chaincode}_${version}"* ]] && echo $pkgid ; done )
	commonVerify $? "failed: $packageId" "package id: $packageId"
	out=$( echo $packageId > ${path}/"${chaincode}_${version}.0" )
	commonVerify $? "failed: $out"
	unset packageId

	# endregion: package id

}
[[ "$TC_EXEC_DRY" == false ]] && _deploy
unset _deploy
