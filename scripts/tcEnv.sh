#!/bin/bash

#
# Copyright TE-FOOD International GmbH., All Rights Reserved
#

#
# An example of what environment variables should be set, which are better not to be included in the repo.
#

# region: init

export CGO_ENABLED=0 
export TC_PATH_BASE=/basedirectory/TrustChain
export TC_PATH_RC=${TC_PATH_BASE}/scripts/tcConf.sh
export COMMON_FUNCS=${TC_PATH_BASE}/scripts/commonFuncs.sh

source $TC_PATH_RC

# endregion: init
# region: passwords

# region: common1 - tls ca

export TC_COMMON1_C1_ADMINPW=xxx

# endregion: tls ca
# region: orderer1 ca

export TC_ORDERER1_ADMINPW=xxx

export TC_ORDERER1_C1_ADMINPW=xxx

export TC_ORDERER1_O1_TLS_PW=xxx
export TC_ORDERER1_O1_CA_PW=xxx
export TC_ORDERER1_O2_TLS_PW=xxx
export TC_ORDERER1_O2_CA_PW=xxx
export TC_ORDERER1_O3_TLS_PW=xxx
export TC_ORDERER1_O3_CA_PW=xxx

# endregion: orderer1 ca
# region: org1 ca

export TC_ORG1_ADMINPW=xxx
export TC_ORG1_CLIENTPW=xxx

export TC_ORG1_C1_ADMINPW=xxx

export TC_ORG1_D1_USERPW=xxx
export TC_ORG1_D2_USERPW=xxx
export TC_ORG1_D3_USERPW=xxx

export TC_ORG1_P1_TLS_PW=xxx
export TC_ORG1_P1_CA_PW=xxx
export TC_ORG1_P2_TLS_PW=xxx
export TC_ORG1_P2_CA_PW=xxx
export TC_ORG1_P3_TLS_PW=xxx
export TC_ORG1_P3_CA_PW=xxx

export TC_ORG1_G1_TLS_PW=xxx
export TC_ORG1_G1_CA_PW=xxx

# endregion: org1 ca
# region: org2 ca

export TC_ORG2_ADMINPW=xxx
export TC_ORG2_CLIENTPW=xxx

export TC_ORG2_C1_ADMINPW=xxx

export TC_ORG2_D1_USERPW=xxx
export TC_ORG2_D2_USERPW=xxx
export TC_ORG2_D3_USERPW=xxx

export TC_ORG2_P1_TLS_PW=xxx
export TC_ORG2_P1_CA_PW=xxx
export TC_ORG2_P2_TLS_PW=xxx
export TC_ORG2_P2_CA_PW=xxx
export TC_ORG2_P3_TLS_PW=xxx
export TC_ORG2_P3_CA_PW=xxx

# endregion: org2 ca
# region: org3 ca

export TC_ORG3_ADMINPW=xxx
export TC_ORG3_CLIENTPW=xxx

export TC_ORG3_C1_ADMINPW=xxx

export TC_ORG3_D1_USERPW=xxx
export TC_ORG3_D2_USERPW=xxx
export TC_ORG3_D3_USERPW=xxx

export TC_ORG3_P1_TLS_PW=xxx
export TC_ORG3_P1_CA_PW=xxx
export TC_ORG3_P2_TLS_PW=xxx
export TC_ORG3_P2_CA_PW=xxx
export TC_ORG3_P3_TLS_PW=xxx
export TC_ORG3_P3_CA_PW=xxx

# endregion: org23ca
# region: common2, common2 - metrics, mgmt

export TC_COMMON2_S3_PW=xxx
export TC_COMMON2_S6_PW=xxx

export TC_COMMON3_S4_PW=xxx

# endregion: common

# endregion: passwords
# region: HTTPS

export TC_HTTP_API_KEY=xxx
export TC_HTTPS_CERT=xxx
export TC_HTTPS_KEY=xxx

# endregion: HTTPS
