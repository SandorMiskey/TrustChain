#! /bin/bash

#
# local version of tcConf.sh, put your changes here
#

# region: init

export TC_PATH_BASE=/home/smiskey/TrustChain
export TC_PATH_RC=${TC_PATH_BASE}/scripts/tcConf.sh
export COMMON_FUNCS=${TC_PATH_BASE}/scripts/commonFuncs.sh

export TC_EXEC_FORCE=true
export TC_EXEC_SURE=true

export TC_RAWAPI_PEERENDPOINT=localhost:8101

# endregion: init
