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

export TC_RAWAPI_LATOR_WHICH=${TC_PATH_BIN}/configtxlator
export TC_RAWAPI_KEY=$TC_HTTP_API_KEY
export TC_RAWAPI_HTTPS_CERT=$TC_HTTPS_CERT
export TC_RAWAPI_HTTPS_KEY=$TC_HTTPS_KEY
export TC_RAWAPI_PEERENDPOINT=localhost:8101

go run ${TC_PATH_RAWAPI}/main.go
