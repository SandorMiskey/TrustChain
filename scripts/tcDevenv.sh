#!/opt/homebrew/bin/bash

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

if [[ ${TC_PATH_DEVENV:-"unset"} == "unset" ]]; then
	commonVerify 1 "TC_PATH_DEVENV is unset"
fi
commonPP $TC_PATH_DEVENV

# endregion: config
# region: env

export FABRIC_CFG_PATH=${TC_PATH_DEVENV}/config
export FABRIC_DEVDATA=${TC_PATH_DEVENV}/data
export ORDERER_GENERAL_GENESISPROFILE=SampleDevModeSolo
export CORE_OPERATIONS_LISTENADDRESS=127.0.0.1:9444
# export FABRIC_LOGGING_SPEC=chaincode=debug
export CORE_PEER_CHAINCODELISTENADDRESS=0.0.0.0:7052
# export CORE_CHAINCODE_LOGLEVEL=debug
export CORE_PEER_TLS_ENABLED=false
export CORE_CHAINCODE_ID_NAME=cc:1.0
unset GOOS

# endregion: env
# region: cleaning up the environment

commonPrintfBold "cleaning up the environment"

killall peer
killall orderer
killall chaincode
rm "${FABRIC_CFG_PATH}/genesisblock" 
rm "${FABRIC_CFG_PATH}/ch1.tx" 
rm "${FABRIC_CFG_PATH}/ch1.block"
# rm "${TC_PATH_DEVENV}/cc"
find "${TC_PATH_DEVENV}/data" -mindepth 1 -delete

# endregion: cleaning up the environment
# region: genesis block

commonPrintfBold "genesis block"
# configtxgen -profile SampleDevModeSolo -channelID syschannel -outputBlock genesisblock -configPath $FABRIC_CFG_PATH -outputBlock "${FABRIC_CFG_PATH}/genesisblock"
configtxgen -profile SampleDevModeSolo -channelID syschannel -configPath $FABRIC_CFG_PATH -outputBlock "${FABRIC_CFG_PATH}/genesisblock"

# endregion: genesis block
# region: orderer

commonPrintfBold "orderer"
orderer &
commonSleep 3

# endregion: orderer
# region: peer in devmode

commonPrintfBold "peer in devmode"
peer node start --peer-chaincodedev=true &
commonSleep 3

# endregion: peer in devmode
# region: create channel and join peer

commonPrintfBold "create channel and join peer"
# configtxgen -channelID ch1 -outputCreateChannelTx ${TC_PATH_DEVENV}/data/ch1.tx -profile SampleSingleMSPChannel -configPath $FABRIC_CFG_PATH
# peer channel create -o 127.0.0.1:7050 -c ch1 -f ch1.tx
configtxgen -channelID ch1 -outputCreateChannelTx "${FABRIC_CFG_PATH}/ch1.tx" -profile SampleSingleMSPChannel -configPath $FABRIC_CFG_PATH
peer channel create -o 127.0.0.1:7050 -c ch1 -f "${FABRIC_CFG_PATH}/ch1.tx" --outputBlock "${FABRIC_CFG_PATH}/ch1.block" 
commonSleep 3
peer channel join -b "${FABRIC_CFG_PATH}/ch1.block"
commonSleep 3

# endregion: create channel and join peer
# region: build chaincode

commonPrintfBold "build chaincode"
ln -s ${TC_PATH_CHAINCODE}/te-food-bundles cc
cd cc 
go build -o chaincode

# endregion: build chaincode
# region: start chaincode

commonPrintfBold "start chaincode"
./chaincode -peer.address 127.0.0.1:7052 &
commonSleep 3

# endregion: start chaincode
# region: approve and commit the chaincode definition

commonPrintfBold "approve and commit the chaincode definition"
# peer lifecycle chaincode approveformyorg  -o 127.0.0.1:7050 --channelID ch1 --name cc --version 1.0 --sequence 1 --init-required --signature-policy "OR ('SampleOrg.member')" --package-id cc:1.0
peer lifecycle chaincode approveformyorg  -o 127.0.0.1:7050 --channelID ch1 --name cc --version 1.0 --sequence 1 --signature-policy "OR ('SampleOrg.member')" --package-id cc:1.0
commonSleep 3
# peer lifecycle chaincode checkcommitreadiness -o 127.0.0.1:7050 --channelID ch1 --name cc --version 1.0 --sequence 1 --init-required --signature-policy "OR ('SampleOrg.member')"
peer lifecycle chaincode checkcommitreadiness -o 127.0.0.1:7050 --channelID ch1 --name cc --version 1.0 --sequence 1 --signature-policy "OR ('SampleOrg.member')"
commonSleep 3
# peer lifecycle chaincode commit -o 127.0.0.1:7050 --channelID ch1 --name cc --version 1.0 --sequence 1 --init-required --signature-policy "OR ('SampleOrg.member')" --peerAddresses 127.0.0.1:7051
peer lifecycle chaincode commit -o 127.0.0.1:7050 --channelID ch1 --name cc --version 1.0 --sequence 1 --signature-policy "OR ('SampleOrg.member')" --peerAddresses 127.0.0.1:7051
commonSleep 3

# endregion: approve and commit the chaincode definition
# region: ending provisions

commonPrintfBold "now you can invoke and query the chaincode"
# CORE_PEER_ADDRESS=127.0.0.1:7051 peer chaincode invoke -o 127.0.0.1:7050 -C ch1 -n cc -c '{"Args":["init","a","100","b","200"]}' --isInit
# CORE_PEER_ADDRESS=127.0.0.1:7051 peer chaincode invoke -o 127.0.0.1:7050 -C ch1 -n cc -c '{"Args":["invoke","a","b","10"]}'
# CORE_PEER_ADDRESS=127.0.0.1:7051 peer chaincode invoke -o 127.0.0.1:7050 -C ch1 -n cc -c '{"Args":["query","a"]}'

# endregion: ending
