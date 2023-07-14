#!/bin/bash

#
# Copyright TE-FOOD International GmbH., All Rights Reserved
#

#
# An example of what environment variables should be set, which are better not to be included in the repo.
#

# region: passwords

# region: tls ca

export TC_COMMON1_C1_ADMINPW=TC_COMMON1_C1_ADMINPW

# endregion: tls ca
# region: orderer1 ca

export TC_ORDERER1_ADMINPW=TC_ORDERER1_ADMINPW

export TC_ORDERER1_C1_ADMINPW=TC_ORDERER1_C1_ADMINPW

export TC_ORDERER1_O1_TLS_PW=TC_ORDERER1_O1_TLS_PW
export TC_ORDERER1_O1_CA_PW=TC_ORDERER1_O1_CAPW
export TC_ORDERER1_O2_TLS_PW=TC_ORDERER1_O2_TLS_PW
export TC_ORDERER1_O2_CA_PW=TC_ORDERER1_O2_CAPW
export TC_ORDERER1_O3_TLS_PW=TC_ORDERER1_O3_TLS_PW
export TC_ORDERER1_O3_CA_PW=TC_ORDERER1_O3_CAPW

# endregion: orderer1 ca
# region: org1 ca

export TC_ORG1_ADMINPW=TC_ORG1_ADMINPW
export TC_ORG1_CLIENTPW=TC_ORG1_CLIENT1PW

export TC_ORG1_C1_ADMINPW=TC_ORG1_C1_ADMINPW

export TC_ORG1_D1_USERPW=TC_ORG1_D1_USERPW
export TC_ORG1_D2_USERPW=TC_ORG1_D2_USERPW
export TC_ORG1_D3_USERPW=TC_ORG1_D3_USERPW

export TC_ORG1_P1_TLS_PW=TC_ORG1_P1_TLS_PW
export TC_ORG1_P1_CA_PW=TC_ORG1_P1_CA_PW
export TC_ORG1_P2_TLS_PW=TC_ORG1_P2_TLS_PW
export TC_ORG1_P2_CA_PW=TC_ORG1_P2_CA_PW
export TC_ORG1_P3_TLS_PW=TC_ORG1_P3_TLS_PW
export TC_ORG1_P3_CA_PW=TC_ORG1_P3_CA_PW

export TC_ORG1_G1_TLS_PW=TC_ORG1_G1_TLS_PW
export TC_ORG1_G1_CA_PW=TC_ORG1_G1_CA_PW

# endregion: org1 ca
# region: org2 ca

export TC_ORG2_ADMINPW=TC_ORG2_ADMINPW
export TC_ORG2_CLIENTPW=TC_ORG2_CLIENT1PW

export TC_ORG2_C1_ADMINPW=TC_ORG2_C1_ADMINPW

export TC_ORG2_D1_USERPW=TC_ORG2_D1_USERPW
export TC_ORG2_D2_USERPW=TC_ORG2_D2_USERPW
export TC_ORG2_D3_USERPW=TC_ORG2_D3_USERPW

export TC_ORG2_P1_TLS_PW=TC_ORG2_P1_TLS_PW
export TC_ORG2_P1_CA_PW=TC_ORG2_P1_CA_PW
export TC_ORG2_P2_TLS_PW=TC_ORG2_P2_TLS_PW
export TC_ORG2_P2_CA_PW=TC_ORG2_P2_CA_PW
export TC_ORG2_P3_TLS_PW=TC_ORG2_P3_TLS_PW
export TC_ORG2_P3_CA_PW=TC_ORG2_P3_CA_PW

# endregion: org2 ca
# region: common

export TC_COMMON2_S3_PW=TC_COMMON2_S3_PW
export TC_COMMON2_S6_PW=TC_COMMON2_S6_PW
export TC_COMMON3_S4_PW=TC_COMMON3_S4_PW

# endregion: common

# endregion: passwords
# region: init

export TC_PATH_BASE=/srv/TrustChain
export TC_PATH_RC=${TC_PATH_BASE}/scripts/tcConf.sh
export COMMON_FUNCS=${TC_PATH_BASE}/scripts/commonFuncs.sh

source $TC_PATH_RC

# endregion: init
