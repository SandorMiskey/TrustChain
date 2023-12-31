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
[[ -d "${TC_PATH_CHANNELS}/${channel}" ]] || commonPrintfBold "${channel}: no such directory under $TC_PATH_CHANNELS"
[[ -z "$version" ]] && export version="1" 

commonPrintfBold "chaincode: $chaincode"
commonPrintfBold "channel: $channel"
commonPrintfBold "version: $version"

# endregion: check params

_aprove() {
	local out
	local path=${TC_PATH_CHAINCODE}/${chaincode}
	local certOrderer="${TC_ORDERER1_O1_TLSMSP}/tlscacerts/tls-0-0-0-0-${TC_COMMON1_C1_PORT}.pem" 

	commonPP $path

	# region: package id

	commonPrintf "getting package id"
	packageId=$( cat ${path}/"${chaincode}_${version}.0" )
	commonVerify $? "failed: $packageId" "package id: $packageId"

	# endregion: package id
	# region: approve a chaincode definition

	commonPrintf "approving chaincode definition for $TC_ORG1_STACK"
	out=$(
		export FABRIC_CFG_PATH="${TC_PATH_CHANNELS}"
		export CORE_PEER_TLS_ENABLED=true
		export CORE_PEER_LOCALMSPID="${TC_ORG1_STACK}MSP"
		export CORE_PEER_TLS_ROOTCERT_FILE=${TC_ORG1_DATA}/msp/tlscacerts/ca-cert.pem
		export CORE_PEER_MSPCONFIGPATH=$TC_ORG1_ADMINMSP
		export CORE_PEER_ADDRESS=localhost:${TC_ORG1_P1_PORT}
		peer lifecycle chaincode approveformyorg -o localhost:${TC_ORDERER1_O1_PORT} --ordererTLSHostnameOverride $TC_ORDERER1_O1_NAME --channelID ${channel} --name ${chaincode} --version ${version}.0  --package-id $packageId --sequence $version --tls --cafile "$certOrderer" 2>&1 
	)
	commonVerify $? "failed: $out" "$out"

	if [ "$channel" != "$TC_LEGACY1_NAME" ]; then
		commonPrintf "approving chaincode definition for $TC_ORG2_STACK"
		out=$(
			export FABRIC_CFG_PATH="${TC_PATH_CHANNELS}"
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
			export FABRIC_CFG_PATH="${TC_PATH_CHANNELS}"
			export CORE_PEER_TLS_ENABLED=true
			export CORE_PEER_LOCALMSPID="${TC_ORG3_STACK}MSP"
			export CORE_PEER_TLS_ROOTCERT_FILE=${TC_ORG3_DATA}/msp/tlscacerts/ca-cert.pem
			export CORE_PEER_MSPCONFIGPATH=$TC_ORG3_ADMINMSP
			export CORE_PEER_ADDRESS=localhost:${TC_ORG3_P1_PORT}
			peer lifecycle chaincode approveformyorg -o localhost:${TC_ORDERER1_O1_PORT} --ordererTLSHostnameOverride $TC_ORDERER1_O1_NAME --channelID ${channel} --name ${chaincode} --version ${version}.0 --package-id $packageId --sequence $version --tls --cafile "$certOrderer" 2>&1 
		)
		commonVerify $? "failed: $out" "$out"
	fi

	# endregion: approve a chaincode definition
	# region: commit

	commonSleep 5 "check whether channel members have approved the definition"
	out=$(
		export FABRIC_CFG_PATH="${TC_PATH_CHANNELS}"
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
		export FABRIC_CFG_PATH="${TC_PATH_CHANNELS}"
		export CORE_PEER_TLS_ENABLED=true
		export CORE_PEER_LOCALMSPID="${TC_ORG1_STACK}MSP"
		export CORE_PEER_TLS_ROOTCERT_FILE=${TC_ORG1_DATA}/msp/tlscacerts/ca-cert.pem
		export CORE_PEER_MSPCONFIGPATH=$TC_ORG1_ADMINMSP
		export CORE_PEER_ADDRESS=localhost:${TC_ORG1_P1_PORT}

		if [ "$channel" != "$TC_LEGACY1_NAME" ]; then	
			peer lifecycle chaincode commit -o localhost:${TC_ORDERER1_O1_PORT} --ordererTLSHostnameOverride $TC_ORDERER1_O1_NAME --channelID $channel --name ${chaincode} --version ${version}.0 --sequence $version --tls --cafile "$certOrderer" --peerAddresses localhost:${TC_ORG1_P1_PORT} --tlsRootCertFiles "${TC_ORG1_P1_TLSMSP}/tlscacerts/tls-0-0-0-0-${TC_COMMON1_C1_PORT}.pem" --peerAddresses localhost:${TC_ORG2_P1_PORT} --tlsRootCertFiles "${TC_ORG2_P1_TLSMSP}/tlscacerts/tls-0-0-0-0-${TC_COMMON1_C1_PORT}.pem" 2>&1
		else
			peer lifecycle chaincode commit -o localhost:${TC_ORDERER1_O1_PORT} --ordererTLSHostnameOverride $TC_ORDERER1_O1_NAME --channelID $channel --name ${chaincode} --version ${version}.0 --sequence $version --tls --cafile "$certOrderer" --peerAddresses localhost:${TC_ORG1_P1_PORT} --tlsRootCertFiles "${TC_ORG1_P1_TLSMSP}/tlscacerts/tls-0-0-0-0-${TC_COMMON1_C1_PORT}.pem"  2>&1
		fi
	)
	commonVerify $? "failed: $out" "status: $out"

	commonSleep 5 "check if chaincode definition has been committed"
	out=$(
		export FABRIC_CFG_PATH="${TC_PATH_CHANNELS}"
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
[[ "$TC_EXEC_DRY" == false ]] && _aprove
unset _aprove
