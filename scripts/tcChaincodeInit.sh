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
export channel=$2
export version=$3

[[ -d "${TC_PATH_CHAINCODE}/${chaincode}" ]] || commonVerify 1 "${chaincode}: no such directory under $TC_PATH_CHAINCODE"
[[ -d "${TC_PATH_CHANNELS}/${channel}" ]] || commonVerify 1 "${channel}: no such directory under $TC_PATH_CHANNELS"
[[ -z "$version" ]] && export version="1" 

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
		export FABRIC_CFG_PATH="${TC_PATH_CHANNELS}/${channel}"
		peer lifecycle chaincode package ${chaincode}.tar.gz --path $path --lang golang --label "${chaincode}_${version}.0" 2>&1
	)
	commonVerify $? "failed: $out"

	# endregion: packing
	# region: installing

	commonPrintf "install chaincode on $TC_ORG1_STACK peers"
	for port in $TC_ORG1_P1_PORT $TC_ORG1_P2_PORT $TC_ORG1_P3_PORT
	do
		commonPrintf "targeting localhost:${port}"
		out=$(
			export FABRIC_CFG_PATH="${TC_PATH_CHANNELS}/${channel}"
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
	for port in $TC_ORG2_P1_PORT $TC_ORG2_P2_PORT $TC_ORG2_P3_PORT
	do
		commonPrintf "targeting localhost:${port}"
		out=$(
			export FABRIC_CFG_PATH="${TC_PATH_CHANNELS}/${channel}"
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
	for port in $TC_ORG3_P1_PORT $TC_ORG3_P2_PORT $TC_ORG3_P3_PORT
	do
		commonPrintf "targeting localhost:${port}"
		out=$(
			export FABRIC_CFG_PATH="${TC_PATH_CHANNELS}/${channel}"
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
	# region: approve a chaincode definition

	commonPrintf "getting package id"
	out=$(
		export FABRIC_CFG_PATH="${TC_PATH_CHANNELS}/${channel}"
		export CORE_PEER_TLS_ENABLED=true
		export CORE_PEER_LOCALMSPID="${TC_ORG1_STACK}MSP"
		export CORE_PEER_TLS_ROOTCERT_FILE=${TC_ORG1_DATA}/msp/tlscacerts/ca-cert.pem
		export CORE_PEER_MSPCONFIGPATH=$TC_ORG1_ADMINMSP
		export CORE_PEER_ADDRESS=localhost:${TC_ORG1_P1_PORT}
		peer lifecycle chaincode queryinstalled -O json  2>&1
	)
	commonVerify $? "failed: $out" "$out"
	# local packageId=$( echo $out | jq ".installed_chaincodes[-1].package_id" | sed s/\"//g  2>&1 )
	local packageId=$( echo $out | jq -r ".installed_chaincodes[].package_id" | while read -r pkgid; do [[ "$pkgid" == "${chaincode}_${version}"* ]] && echo $pkgid ; done )
	commonVerify $? "failed: $packageId" "package id: $packageId"
	unset pkgid

	commonPrintf "approving chaincode definition for $TC_ORG1_STACK"
	out=$(
		export FABRIC_CFG_PATH="${TC_PATH_CHANNELS}/${channel}"
		export CORE_PEER_TLS_ENABLED=true
		export CORE_PEER_LOCALMSPID="${TC_ORG1_STACK}MSP"
		export CORE_PEER_TLS_ROOTCERT_FILE=${TC_ORG1_DATA}/msp/tlscacerts/ca-cert.pem
		export CORE_PEER_MSPCONFIGPATH=$TC_ORG1_ADMINMSP
		export CORE_PEER_ADDRESS=localhost:${TC_ORG1_P1_PORT}
		peer lifecycle chaincode approveformyorg -o localhost:${TC_ORDERER1_O1_PORT} --ordererTLSHostnameOverride $TC_ORDERER1_O1_NAME --channelID ${channel} --name ${chaincode} --version ${version}.0  --package-id $packageId --sequence $version --tls --cafile "$certOrderer" 2>&1 
	)
	commonVerify $? "failed: $out" "$out"

	commonPrintf "approving chaincode definition for $TC_ORG2_STACK"
	out=$(
		export FABRIC_CFG_PATH="${TC_PATH_CHANNELS}/${channel}"
		export CORE_PEER_TLS_ENABLED=true
		export CORE_PEER_LOCALMSPID="${TC_ORG2_STACK}MSP"
		export CORE_PEER_TLS_ROOTCERT_FILE=${TC_ORG2_DATA}/msp/tlscacerts/ca-cert.pem
		export CORE_PEER_MSPCONFIGPATH=$TC_ORG2_ADMINMSP
		export CORE_PEER_ADDRESS=localhost:${TC_ORG2_P1_PORT}
		peer lifecycle chaincode approveformyorg -o localhost:${TC_ORDERER1_O1_PORT} --ordererTLSHostnameOverride $TC_ORDERER1_O1_NAME --channelID ${channel} --name ${chaincode} --version ${version}.0 --package-id $packageId --sequence $version --tls --cafile "$certOrderer" 2>&1 
	)
	commonVerify $? "failed: $out" "$out"

	commonPrintf "approving chaincode definition for $TC_ORG3_STACK"
	out=$(
		export FABRIC_CFG_PATH="${TC_PATH_CHANNELS}/${channel}"
		export CORE_PEER_TLS_ENABLED=true
		export CORE_PEER_LOCALMSPID="${TC_ORG3_STACK}MSP"
		export CORE_PEER_TLS_ROOTCERT_FILE=${TC_ORG3_DATA}/msp/tlscacerts/ca-cert.pem
		export CORE_PEER_MSPCONFIGPATH=$TC_ORG3_ADMINMSP
		export CORE_PEER_ADDRESS=localhost:${TC_ORG3_P1_PORT}
		peer lifecycle chaincode approveformyorg -o localhost:${TC_ORDERER1_O1_PORT} --ordererTLSHostnameOverride $TC_ORDERER1_O1_NAME --channelID ${channel} --name ${chaincode} --version ${version}.0 --package-id $packageId --sequence $version --tls --cafile "$certOrderer" 2>&1 
	)
	commonVerify $? "failed: $out" "$out"

	# endregion: approve a chaincode definition
	# region: commit

	commonSleep 5 "check whether channel members have approved the definition"
	out=$(
		export FABRIC_CFG_PATH="${TC_PATH_CHANNELS}/${channel}"
		export CORE_PEER_TLS_ENABLED=true
		export CORE_PEER_LOCALMSPID="${TC_ORG1_STACK}MSP"
		export CORE_PEER_TLS_ROOTCERT_FILE=${TC_ORG1_DATA}/msp/tlscacerts/ca-cert.pem
		export CORE_PEER_MSPCONFIGPATH=$TC_ORG1_ADMINMSP
		export CORE_PEER_ADDRESS=localhost:${TC_ORG1_P1_PORT}
		peer lifecycle chaincode checkcommitreadiness --channelID $channel --name ${chaincode} --version ${version}.0 --sequence $version --tls --cafile "$certOrderer" --output json 2>&1 
	)
	commonVerify $? "failed: $out" "status: $out"

	commonPrintf "commiting chaincode"
	out=$(
		export FABRIC_CFG_PATH="${TC_PATH_CHANNELS}/${channel}"
		export CORE_PEER_TLS_ENABLED=true
		export CORE_PEER_LOCALMSPID="${TC_ORG1_STACK}MSP"
		export CORE_PEER_TLS_ROOTCERT_FILE=${TC_ORG1_DATA}/msp/tlscacerts/ca-cert.pem
		export CORE_PEER_MSPCONFIGPATH=$TC_ORG1_ADMINMSP
		export CORE_PEER_ADDRESS=localhost:${TC_ORG1_P1_PORT}
		peer lifecycle chaincode commit -o localhost:${TC_ORDERER1_O1_PORT} --ordererTLSHostnameOverride $TC_ORDERER1_O1_NAME --channelID $channel --name ${chaincode} --version ${version}.0 --sequence $version --tls --cafile "$certOrderer" --peerAddresses localhost:${TC_ORG1_P1_PORT} --tlsRootCertFiles "${TC_ORG1_P1_TLSMSP}/tlscacerts/tls-0-0-0-0-${TC_COMMON1_C1_PORT}.pem" --peerAddresses localhost:${TC_ORG2_P1_PORT} --tlsRootCertFiles "${TC_ORG2_P1_TLSMSP}/tlscacerts/tls-0-0-0-0-${TC_COMMON1_C1_PORT}.pem" 2>&1 
	)
	commonVerify $? "failed: $out" "status: $out"

	commonSleep 5 "check if chaincode definition has been committed"
	out=$(
		export FABRIC_CFG_PATH="${TC_PATH_CHANNELS}/${channel}"
		export CORE_PEER_TLS_ENABLED=true
		export CORE_PEER_LOCALMSPID="${TC_ORG1_STACK}MSP"
		export CORE_PEER_TLS_ROOTCERT_FILE=${TC_ORG1_DATA}/msp/tlscacerts/ca-cert.pem
		export CORE_PEER_MSPCONFIGPATH=$TC_ORG1_ADMINMSP
		export CORE_PEER_ADDRESS=localhost:${TC_ORG1_P1_PORT}
		peer lifecycle chaincode querycommitted --channelID $channel --name ${chaincode} --cafile "$certOrderer" 2>&1 
	)
	commonVerify $? "failed: $out" "status: $out"

	# endregion: commit

}
[[ "$TC_EXEC_DRY" == false ]] && _deploy
