#! /bin/bash

# region: load config

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

# endregion: config

export TC_RAWAPI_KEY=$TC_HTTP_API_KEY
# export TC_RAWAPI_HTTP_ENABLED=true
# export TC_RAWAPI_HTTP_NAME="TrustChain backend"
# export TC_RAWAPI_HTTP_PORT=5088
# export TC_RAWAPI_HTTP_STATIC_ENABLED=true
# export TC_RAWAPI_HTTP_STATIC_ROOT=/srv/TrustChain/organizations/peerOrganizations/backbone/gw1/assets/docs
# export TC_RAWAPI_HTTP_STATIC_INDEX="index.html"
# export TC_RAWAPI_HTTP_STATIC_ERROR="index.html"
# export TC_RAWAPI_HTTPS_ENABLED=true
# export TC_RAWAPI_HTTPS_PORT=5089
export TC_RAWAPI_HTTPS_CERT=$TC_HTTPS_CERT
# export TC_RAWAPI_HTTPS_CERT_FILE=/run/secrets/tc_https_cert
export TC_RAWAPI_HTTPS_KEY=$TC_HTTPS_KEY
# export TC_RAWAPI_HTTPS_KEY_FILE=/run/secrets/tc_https_key
# export TC_RAWAPI_LOGALLERRORS=true
# export TC_RAWAPI_MAXREQUESTBODYSIZE=4194304
# export TC_RAWAPI_NETWORKPROTO="tcp"
# export TC_RAWAPI_LOGLEVEL=7
# export TC_RAWAPI_ORGNAME=backbone
# export TC_RAWAPI_MSPID=backboneMSP
# export TC_RAWAPI_CERTPATH=/srv/TrustChain/organizations/peerOrganizations/backbone/users/backbone-client1/msp/signcerts/cert.pem
# export TC_RAWAPI_KEYPATH=/srv/TrustChain/organizations/peerOrganizations/backbone/users/backbone-client1/msp/keystore/
# export TC_RAWAPI_TLSCERTPATH=/srv/TrustChain/organizations/peerOrganizations/backbone/gw1/tls-msp/tlscacerts/tls-0-0-0-0-6001.pem
export TC_RAWAPI_PEERENDPOINT=localhost:8101
# export TC_RAWAPI_GATEWAYPEER=peer1.backbone.trustchain-test.te-food.com

go run ${TC_PATH_RAWAPI}/main.go
