#!/bin/bash

#
# Copyright TE-FOOD International GmbH., All Rights Reserved
#

#
# An example of what environment variables should be set in your .env, which are better not to be included in the repo.
#

# region: init

export CGO_ENABLED=0 

export TC_PATH_BASE=/basedirectory/TrustChain
export TC_PATH_RC=${TC_PATH_BASE}/scripts/tcConf.sh
export TC_NETWORK_NAME=xxx
export TC_NETWORK_DOMAIN=${TC_NETWORK_NAME}.foobar.com

export COMMON_FUNCS=${TC_PATH_BASE}/scripts/commonFuncs.sh

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

export TC_ORG1_GW1_TLS_PW=xxx
export TC_ORG1_GW1_CA_PW=xxx
export TC_ORG1_GW2_TLS_PW=xxx
export TC_ORG1_GW2_CA_PW=xxx
export TC_ORG1_GW3_TLS_PW=xxx
export TC_ORG1_GW3_CA_PW=xxx

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
# region: swarm

declare -A TC_SWARM_MANAGER1=( [node]=tc2-test-manager1 [ip]=1.1.1.1 [gdev]=/dev/nvme1n1p1 [gmnt]=/srv/GlusterData )
declare -A TC_SWARM_MANAGER2=( [node]=tc2-test-manager2 [ip]=2.2.2.2 [gdev]=/dev/nvme1n1p1 [gmnt]=/srv/GlusterData )
declare -A TC_SWARM_MANAGER3=( [node]=tc2-test-manager3 [ip]=3.3.3.3 [gdev]=/dev/nvme1n1p1 [gmnt]=/srv/GlusterData )
export TC_SWARM_MANAGERS=("TC_SWARM_MANAGER1" "TC_SWARM_MANAGER2" "TC_SWARM_MANAGER3")

declare -A TC_SWARM_WORKER1=( [node]=tc2-test-worker1 [ip]=4.4.4.4 [mnt]="/x" )
declare -A TC_SWARM_WORKER2=( [node]=tc2-test-worker2 [ip]=5.5.5.5 [mnt]="/x" )
export TC_SWARM_WORKERS=("TC_SWARM_WORKER1" "TC_SWARM_WORKER2")

export TC_SWARM_PUBLIC=${TC_SWARM_MANAGER1[ip]}
export TC_SWARM_INIT="--advertise-addr ${TC_SWARM_PUBLIC}:2377 --cert-expiry 1000000h0m0s"
export TC_SWARM_MANAGER=${TC_SWARM_MANAGER1[node]}

# endregion: swarm
# region: gluster

export TC_GLUSTER_MANAGERS=("TC_SWARM_MANAGER1" "TC_SWARM_MANAGER2" "TC_SWARM_MANAGER3")
export TC_GLUSTER_MOUNTS=()

declare -A TC_ORG2_MOUNT1=( [node]=${TC_SWARM_WORKER1[node]} [ip]=${TC_SWARM_WORKER1[ip]} [mnt]="$TC_ORG2_DATA" )
declare -A TC_ORG2_MOUNT2=( [node]=${TC_SWARM_WORKER2[node]} [ip]=${TC_SWARM_WORKER2[ip]} [mnt]="$TC_ORG2_DATA" )
TC_GLUSTER_MOUNTS+=("TC_ORG2_MOUNT1")
TC_GLUSTER_MOUNTS+=("TC_ORG2_MOUNT2")

declare -A TC_ORG3_MOUNT1=( [node]=${TC_SWARM_WORKER1[node]} [ip]=${TC_SWARM_WORKER1[ip]} [mnt]="$TC_ORG3_DATA" )
declare -A TC_ORG3_MOUNT2=( [node]=${TC_SWARM_WORKER2[node]} [ip]=${TC_SWARM_WORKER2[ip]} [mnt]="$TC_ORG3_DATA" )
TC_GLUSTER_MOUNTS+=("TC_ORG3_MOUNT1")
TC_GLUSTER_MOUNTS+=("TC_ORG3_MOUNT2")

# endregion: gluster
# region: workers

export TC_COMMON1_REGISTRY_WORKER=${TC_SWARM_MANAGER1[node]}
export TC_COMMON1_C1_WORKER=${TC_SWARM_MANAGER1[node]}

export TC_ORDERER1_C1_WORKER=${TC_SWARM_MANAGER1[node]}
export TC_ORDERER1_O1_WORKER=${TC_SWARM_MANAGER1[node]}
export TC_ORDERER1_O1_WAL=${TC_SWARM_MANAGER1[gmnt]}/WAL
export TC_ORDERER1_O2_WORKER=${TC_SWARM_MANAGER2[node]}
export TC_ORDERER1_O2_WAL=${TC_SWARM_MANAGER2[gmnt]}/WAL
export TC_ORDERER1_O3_WORKER=${TC_SWARM_MANAGER3[node]}
export TC_ORDERER1_O3_WAL=${TC_SWARM_MANAGER3[gmnt]}/WAL

export TC_ORG1_C1_WORKER=${TC_SWARM_MANAGER1[node]}
export TC_ORG1_D1_WORKER=${TC_SWARM_MANAGER1[node]}
export TC_ORG1_D2_WORKER=${TC_SWARM_MANAGER2[node]}
export TC_ORG1_D3_WORKER=${TC_SWARM_MANAGER3[node]}
export TC_ORG1_P1_WORKER=$TC_ORG1_D1_WORKER
export TC_ORG1_P2_WORKER=$TC_ORG1_D2_WORKER
export TC_ORG1_P3_WORKER=$TC_ORG1_D3_WORKER
export TC_ORG1_GW1_WORKER=${TC_SWARM_MANAGER1[node]}
export TC_ORG1_GW2_WORKER=${TC_SWARM_MANAGER2[node]}
export TC_ORG1_GW3_WORKER=${TC_SWARM_MANAGER3[node]}
export TC_ORG1_CLI1_WORKER=${TC_SWARM_MANAGER1[node]}

export TC_ORG2_C1_WORKER=${TC_SWARM_MANAGER1[node]}
export TC_ORG2_D1_WORKER=${TC_SWARM_MANAGER1[node]}
export TC_ORG2_D2_WORKER=${TC_SWARM_WORKER1[node]}
export TC_ORG2_D3_WORKER=${TC_SWARM_WORKER2[node]}
export TC_ORG2_P1_WORKER=$TC_ORG2_D1_WORKER
export TC_ORG2_P2_WORKER=$TC_ORG2_D2_WORKER
export TC_ORG2_P3_WORKER=$TC_ORG2_D3_WORKER
export TC_ORG2_CLI1_WORKER=${TC_SWARM_MANAGER1[node]}

export TC_ORG3_C1_WORKER=${TC_SWARM_MANAGER1[node]}
export TC_ORG3_D1_WORKER=${TC_SWARM_MANAGER1[node]}
export TC_ORG3_D2_WORKER=${TC_SWARM_WORKER1[node]}
export TC_ORG3_D3_WORKER=${TC_SWARM_WORKER2[node]}
export TC_ORG3_P1_WORKER=$TC_ORG3_D1_WORKER
export TC_ORG3_P2_WORKER=$TC_ORG3_D2_WORKER
export TC_ORG3_P3_WORKER=$TC_ORG3_D3_WORKER
export TC_ORG3_CLI1_WORKER=${TC_SWARM_MANAGER1[node]}

export TC_COMMON2_S3_WORKER=${TC_SWARM_MANAGER1[node]}
export TC_COMMON2_S4_WORKER=${TC_SWARM_MANAGER1[node]}
export TC_COMMON2_S5_WORKER=${TC_SWARM_MANAGER1[node]}
export TC_COMMON2_S6_WORKER=${TC_SWARM_MANAGER1[node]}

export TC_COMMON3_WORKER=${TC_SWARM_MANAGER1[node]}
export TC_COMMON3_S1_WORKER=${TC_SWARM_MANAGER1[node]}
export TC_COMMON3_S2_WORKER=${TC_SWARM_MANAGER1[node]}

# endregion: workeres
