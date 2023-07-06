#!/bin/bash

#
# Copyright TE-FOOD International GmbH., All Rights Reserved
#

# region: load .env if anya

[[ -f .env ]] && source .env

# endregion: .env
# region: base paths

# get them from .env 
export TC_PATH_BASE=$TC_PATH_BASE
export TC_PATH_RC=$TC_PATH_RC

# dirs under base
export TC_PATH_BIN=${TC_PATH_BASE}/bin
export TC_PATH_SCRIPTS=${TC_PATH_BASE}/scripts
export TC_PATH_TEMPLATES=${TC_PATH_BASE}/templates
export TC_PATH_STORAGE=${TC_PATH_BASE}/storage

# dirs under storage
export TC_PATH_SWARM=${TC_PATH_STORAGE}/swarm
export TC_PATH_DATA=${TC_PATH_STORAGE}/data

# trustchain independent common functions
export TC_PATH_COMMON=${TC_PATH_SCRIPTS}/commonFuncs.sh

# add scripts and bins to PATH
export PATH=${TC_PATH_BIN}:${TC_PATH_SCRIPTS}:$PATH

# endregion: base paths
# region: exec control

export TC_EXEC_DRY=false
export TC_EXEC_FORCE=true
export TC_EXEC_PANIC=true
export TC_EXEC_SURE=true

# endregion: exec contorl
# region: versions and deps

export TC_DEPS_CA=1.5.6
export TC_DEPS_FABRIC=2.5.3
export TC_DEPS_COUCHDB=3.3.1
export TC_DEPS_BINS=('awk' 'bash' 'curl' 'git' 'go' 'jq' 'configtxgen')

# endregion: versions and deps
# region: network and channel

export TC_NETWORK_NAME=trustchain-test
export TC_NETWORK_DOMAIN=${TC_NETWORK_NAME}.te-food.com

# export TC_CHANNEL_PROFILE=TwoOrgsApplicationGenesis
# export TC_CHANNEL_NAME=('test' 'foodchain')

# endregion: network and channel
# region: swarm

export TC_SWARM_PATH=$TC_PATH_SWARM
export TC_SWARM_INIT="--advertise-addr 35.158.186.93:2377 --listen-addr 0.0.0.0:2377 --cert-expiry 1000000h0m0s"
export TC_SWARM_MANAGER=ip-10-97-85-63
export TC_SWARM_NETNAME=$TC_NETWORK_NAME
export TC_SWARM_NETINIT="--attachable --driver overlay --subnet 10.96.0.0/24 $TC_SWARM_NETNAME"
export TC_SWARM_DELAY=5

# endregion: swarm
# region: tls ca

export TC_TLSCA1_STACK=tls1

export TC_TLSCA1_C1_NAME=ca1
export TC_TLSCA1_C1_FQDN=${TC_TLSCA1_C1_NAME}.${TC_TLSCA1_STACK}.${TC_NETWORK_DOMAIN}
export TC_TLSCA1_C1_PORT=6001
export TC_TLSCA1_C1_ADMIN=${TC_TLSCA1_STACK}-${TC_TLSCA1_C1_NAME}-admin1
export TC_TLSCA1_C1_ADMINPW=$TC_TLSCA1_C1_ADMINPW
export TC_TLSCA1_C1_WORKER=$TC_SWARM_MANAGER
export TC_TLSCA1_C1_DATA=${TC_PATH_DATA}/${TC_TLSCA1_STACK}/${TC_TLSCA1_C1_NAME}
export TC_TLSCA1_C1_SUBHOME=crypto
export TC_TLSCA1_C1_HOME=${TC_TLSCA1_C1_DATA}/${TC_TLSCA1_C1_SUBHOME}
export TC_TLSCA1_C1_DEBUG=false

# endregion: tls ca
# region: orgs

	# region: orderer1

	# region: orderer1 all stack

	export TC_ORDERER1_STACK=te-food-orderers
	export TC_ORDERER1_DATA=${TC_PATH_DATA}/${TC_ORDERER1_STACK}
	export TC_ORDERER1_DOMAIN=${TC_ORDERER1_STACK}.${TC_NETWORK_DOMAIN}
	export TC_ORDERER1_LOGLEVEL=info

	export TC_ORDERER1_ADMIN=${TC_ORDERER1_STACK}-admin1
	export TC_ORDERER1_ADMINPW=$TC_ORDERER1_ADMINPW
	export TC_ORDERER1_ADMINATRS="hf.Registrar.Roles=client,hf.Registrar.Attributes=*,hf.Revoker=true,hf.GenCRL=true,admin=true:ecert,abac.init=true:ecert"

	# endregion: orderer1 all stack
	# region: orderer1 c1

	export TC_ORDERER1_C1_NAME=ca1
	export TC_ORDERER1_C1_FQDN=${TC_ORDERER1_C1_NAME}.${TC_ORDERER1_DOMAIN}
	export TC_ORDERER1_C1_PORT=7001
	export TC_ORDERER1_C1_DEBUG=false
	export TC_ORDERER1_C1_LOGLEVEL=$TC_ORDERER1_LOGLEVEL
	export TC_ORDERER1_C1_WORKER=$TC_SWARM_MANAGER
	export TC_ORDERER1_C1_DATA=${TC_ORDERER1_DATA}/${TC_ORDERER1_C1_NAME}
	export TC_ORDERER1_C1_SUBHOME=crypto
	export TC_ORDERER1_C1_HOME=${TC_ORDERER1_C1_DATA}/${TC_ORDERER1_C1_SUBHOME}	

	export TC_ORDERER1_C1_ADMIN=${TC_ORDERER1_STACK}-${TC_ORDERER1_C1_NAME}-admin1
	export TC_ORDERER1_C1_ADMINPW=$TC_ORDERER1_C1_ADMINPW

	# export TC_ORDERER1_C1_TLS_NAME=$TC_ORDERER1_C1_NAME-$TC_ORDERER1_STACK
	# export TC_ORDERER1_C1_TLS_PW=$TC_ORDERER1_C1_TLS_PW

	# endregion: orderer1 c1
	# region: orderer1 o1

	export TC_ORDERER1_O1_NAME=orderer1
	export TC_ORDERER1_O1_FQDN=${TC_ORDERER1_O1_NAME}.${TC_ORDERER1_DOMAIN}
	export TC_ORDERER1_O1_TLS_NAME=$TC_ORDERER1_STACK-$TC_ORDERER1_O1_NAME
	export TC_ORDERER1_O1_TLS_PW=$TC_ORDERER1_O1_TLS_PW
	export TC_ORDERER1_O1_CA_NAME=${TC_ORDERER1_STACK}-${TC_ORDERER1_O1_NAME}
	export TC_ORDERER1_O1_CA_PW=$TC_ORDERER1_O1_CA_PW
	# export TC_ORDERER1_O1_PORT=5910
	# export TC_ORDERER1_O1_ADMINPORT=5911
	# export TC_ORDERER1_O1_OPPORT=5912
	# export TC_ORDERER1_O1_WORKER=$SC_SWARM_MANAGER

	# endregion: orderer1 o1
	# region: orderer1 o2

	export TC_ORDERER1_O2_NAME=orderer2
	export TC_ORDERER1_O2_FQDN=${TC_ORDERER1_O2_NAME}.${TC_ORDERER1_DOMAIN}
	export TC_ORDERER1_O2_TLS_NAME=$TC_ORDERER1_STACK-$TC_ORDERER1_O2_NAME
	export TC_ORDERER1_O2_TLS_PW=$TC_ORDERER1_O2_TLS_PW
	export TC_ORDERER1_O2_CA_NAME=${TC_ORDERER1_STACK}-${TC_ORDERER1_O2_NAME}
	export TC_ORDERER1_O2_CA_PW=$TC_ORDERER1_O2_CA_PW

	# endregion: orderer1 o2
	# region: orderer1 o3

	export TC_ORDERER1_O3_NAME=orderer3
	export TC_ORDERER1_O3_FQDN=${TC_ORDERER1_O3_NAME}.${TC_ORDERER1_DOMAIN}
	export TC_ORDERER1_O3_TLS_NAME=$TC_ORDERER1_STACK-$TC_ORDERER1_O3_NAME
	export TC_ORDERER1_O3_TLS_PW=$TC_ORDERER1_O3_TLS_PW
	export TC_ORDERER1_O3_CA_NAME=${TC_ORDERER1_STACK}-${TC_ORDERER1_O3_NAME}
	export TC_ORDERER1_O3_CA_PW=$TC_ORDERER1_O3_CA_PW

	# endregion: orderer1 o3

	# endregion: orderer1
	# region: org1

	# region: org1 all stack

	export TC_ORG1_STACK=te-food-endorsers
	export TC_ORG1_DATA=${TC_PATH_DATA}/${TC_ORG1_STACK}
	export TC_ORG1_DOMAIN=${TC_ORG1_STACK}.${TC_NETWORK_DOMAIN}
	export TC_ORG1_LOGLEVEL=info

	export TC_ORG1_ADMIN=${TC_ORG1_STACK}-admin1
	export TC_ORG1_ADMINPW=$TC_ORG1_ADMINPW
	export TC_ORG1_ADMINATRS="hf.Registrar.Roles=client,hf.Registrar.Attributes=*,hf.Revoker=true,hf.GenCRL=true,admin=true:ecert,abac.init=true:ecert"
	export TC_ORG1_ADMINMSP=${TC_ORG1_DATA}/${TC_ORG1_ADMIN}/msp
	export TC_ORG1_USER=${TC_ORG1_STACK}-user1
	export TC_ORG1_USERPW=$TC_ORG1_USERPW
	export TC_ORG1_USERMSP=${TC_ORG1_DATA}/${TC_ORG1_USER}/msp
	export TC_ORG1_CLIENT=${TC_ORG1_STACK}-client1
	export TC_ORG1_CLIENTPW=$TC_ORG1_CLIENTPW
	export TC_ORG1_CLIENTMSP=${TC_ORG1_DATA}/${TC_ORG1_CLIENT}/msp

	# endregion: org1 all stack
	# region: org1 c1

	export TC_ORG1_C1_NAME=ca1
	export TC_ORG1_C1_FQDN=${TC_ORG1_C1_NAME}.${TC_ORG1_DOMAIN}
	export TC_ORG1_C1_PORT=8001
	export TC_ORG1_C1_DEBUG=false
	export TC_ORG1_C1_LOGLEVEL=$TC_ORG1_LOGLEVEL
	export TC_ORG1_C1_WORKER=$TC_SWARM_MANAGER
	export TC_ORG1_C1_DATA=${TC_ORG1_DATA}/${TC_ORG1_C1_NAME}
	export TC_ORG1_C1_SUBHOME=crypto
	export TC_ORG1_C1_HOME=${TC_ORG1_C1_DATA}/${TC_ORG1_C1_SUBHOME}

	export TC_ORG1_C1_ADMIN=${TC_ORG1_STACK}-${TC_ORG1_C1_NAME}-admin1
	export TC_ORG1_C1_ADMINPW=$TC_ORG1_C1_ADMINPW

	# endregion: org1 c1
	# region: org1 g1

	export TC_ORG1_G1_NAME=gw1
	export TC_ORG1_G1_FQDN=${TC_ORG1_G1_NAME}.${TC_ORG1_DOMAIN}

	export TC_ORG1_G1_TLS_NAME=$TC_ORG1_STACK-$TC_ORG1_G1_NAME
	export TC_ORG1_G1_TLS_PW=$TC_ORG1_G1_TLS_PW
	export TC_ORG1_G1_CA_NAME=${TC_ORG1_STACK}-${TC_ORG1_G1_NAME}
	export TC_ORG1_G1_CA_PW=$TC_ORG1_G1_CA_PW

	export TC_ORG1_G1_DATA=${TC_ORG1_DATA}/${TC_ORG1_G1_NAME}
	export TC_ORG1_G1_MSP=${TC_ORG1_G1_DATA}/msp
	export TC_ORG1_G1_TLSMSP=${TC_ORG1_G1_DATA}/tls-msp
	export TC_ORG1_G1_ASSETS_CACERT=${TC_ORG1_G1_DATA}/assets/${TC_ORG1_C1_FQDN}/ca-cert.pem
	export TC_ORG1_G1_ASSETS_TLSCERT=${TC_ORG1_G1_DATA}/assets/${TC_TLSCA1_C1_FQDN}/ca-cert.pem

	# endregion: org1 g1
	# region: org1 p1
	
	export TC_ORG1_P1_NAME=peer1
	export TC_ORG1_P1_FQDN=${TC_ORG1_P1_NAME}.${TC_ORG1_DOMAIN}
	export TC_ORG1_P1_PORT=8101
	export TC_ORG1_P1_CHPORT=8102
	export TC_ORG1_P1_OPPORT=8103
	export TC_ORG1_P1_WORKER=$TC_SWARM_MANAGER
	export TC_ORG1_P1_LOGLEVEL=$TC_ORG1_LOGLEVEL

	export TC_ORG1_P1_TLS_NAME=$TC_ORG1_STACK-$TC_ORG1_P1_NAME
	export TC_ORG1_P1_TLS_PW=$TC_ORG1_P1_TLS_PW
	export TC_ORG1_P1_CA_NAME=${TC_ORG1_STACK}-${TC_ORG1_P1_NAME}
	export TC_ORG1_P1_CA_PW=$TC_ORG1_P1_CA_PW

	export TC_ORG1_P1_DATA=${TC_ORG1_DATA}/${TC_ORG1_P1_NAME}
	export TC_ORG1_P1_MSP=${TC_ORG1_P1_DATA}/msp
	export TC_ORG1_P1_TLSMSP=${TC_ORG1_P1_DATA}/tls-msp
	export TC_ORG1_P1_ASSETS_CACERT=${TC_ORG1_P1_DATA}/assets/${TC_ORG1_C1_FQDN}/ca-cert.pem
	export TC_ORG1_P1_ASSETS_TLSCERT=${TC_ORG1_P1_DATA}/assets/${TC_TLSCA1_C1_FQDN}/ca-cert.pem

	# endregion: org1 p1
	# region: org1 p2
	
	export TC_ORG1_P2_NAME=peer2
	export TC_ORG1_P2_FQDN=${TC_ORG1_P2_NAME}.${TC_ORG1_DOMAIN}
	export TC_ORG1_P2_PORT=8201
	export TC_ORG1_P2_CHPORT=8202
	export TC_ORG1_P2_OPPORT=8203
	export TC_ORG1_P2_WORKER=$TC_SWARM_MANAGER
	export TC_ORG1_P2_LOGLEVEL=$TC_ORG1_LOGLEVEL

	export TC_ORG1_P2_TLS_NAME=$TC_ORG1_STACK-$TC_ORG1_P2_NAME
	export TC_ORG1_P2_TLS_PW=$TC_ORG1_P2_TLS_PW
	export TC_ORG1_P2_CA_NAME=${TC_ORG1_STACK}-${TC_ORG1_P2_NAME}
	export TC_ORG1_P2_CA_PW=$TC_ORG1_P2_CA_PW

	export TC_ORG1_P2_DATA=${TC_ORG1_DATA}/${TC_ORG1_P2_NAME}
	export TC_ORG1_P2_MSP=${TC_ORG1_P2_DATA}/msp
	export TC_ORG1_P2_TLSMSP=${TC_ORG1_P2_DATA}/tls-msp
	export TC_ORG1_P2_ASSETS_CACERT=${TC_ORG1_P2_DATA}/assets/${TC_ORG1_C1_FQDN}/ca-cert.pem
	export TC_ORG1_P2_ASSETS_TLSCERT=${TC_ORG1_P2_DATA}/assets/${TC_TLSCA1_C1_FQDN}/ca-cert.pem

	# endregion: org1 p2
	# region: org1 p3
	
	export TC_ORG1_P3_NAME=peer3
	export TC_ORG1_P3_FQDN=${TC_ORG1_P3_NAME}.${TC_ORG1_DOMAIN}
	export TC_ORG1_P3_PORT=8101
	export TC_ORG1_P3_CHPORT=8102
	export TC_ORG1_P3_OPPORT=8103
	export TC_ORG1_P3_WORKER=$TC_SWARM_MANAGER
	export TC_ORG1_P3_LOGLEVEL=$TC_ORG1_LOGLEVEL

	export TC_ORG1_P3_TLS_NAME=$TC_ORG1_STACK-$TC_ORG1_P3_NAME
	export TC_ORG1_P3_TLS_PW=$TC_ORG1_P3_TLS_PW
	export TC_ORG1_P3_CA_NAME=${TC_ORG1_STACK}-${TC_ORG1_P3_NAME}
	export TC_ORG1_P3_CA_PW=$TC_ORG1_P3_CA_PW

	export TC_ORG1_P3_DATA=${TC_ORG1_DATA}/${TC_ORG1_P3_NAME}
	export TC_ORG1_P3_MSP=${TC_ORG1_P3_DATA}/msp
	export TC_ORG1_P3_TLSMSP=${TC_ORG1_P3_DATA}/tls-msp
	export TC_ORG1_P3_ASSETS_CACERT=${TC_ORG1_P3_DATA}/assets/${TC_ORG1_C1_FQDN}/ca-cert.pem
	export TC_ORG1_P3_ASSETS_TLSCERT=${TC_ORG1_P3_DATA}/assets/${TC_TLSCA1_C1_FQDN}/ca-cert.pem

	# endregion: org1 p3
	
	# endregion: org1
	# region: org2

	# region: org2 all stack

	export TC_ORG2_STACK=masternodes
	export TC_ORG2_DOMAIN=${TC_ORG2_STACK}.${TC_NETWORK_DOMAIN}
	export TC_ORG2_ADMIN=${TC_ORG2_STACK}-admin1
	export TC_ORG2_ADMINPW=$TC_ORG2_ADMINPW
	export TC_ORG2_ADMINATRS="hf.Registrar.Roles=client,hf.Registrar.Attributes=*,hf.Revoker=true,hf.GenCRL=true,admin=true:ecert,abac.init=true:ecert"
	# export TC_ORG2_USER=${TC_ORG2_STACK}-user1
	# export TC_ORG2_USERPW=$TC_ORG2_USERPW
	# export TC_ORG2_CLIENT=${TC_ORG2_STACK}-client1
	# export TC_ORG2_CLIENTPW=$TC_ORG2_CLIENTPW

	# endregion: org2 all stack
	# region: org2 c1

	export TC_ORG2_C1_NAME=ca1
	export TC_ORG2_C1_FQDN=${TC_ORG2_C1_NAME}.${TC_ORG2_DOMAIN}
	export TC_ORG2_C1_PORT=9001
	export TC_ORG2_C1_ADMIN=${TC_ORG2_STACK}-${TC_ORG2_C1_NAME}-admin1
	export TC_ORG2_C1_ADMINPW=$TC_ORG2_C1_ADMINPW
	export TC_ORG2_C1_WORKER=$TC_SWARM_MANAGER
	export TC_ORG2_C1_DATA=${TC_PATH_DATA}/${TC_ORG2_STACK}/${TC_ORG2_C1_NAME}
	export TC_ORG2_C1_SUBHOME=crypto
	export TC_ORG2_C1_HOME=${TC_ORG2_C1_DATA}/${TC_ORG2_C1_SUBHOME}
	export TC_ORG2_C1_DEBUG=false

	# endregion: org2 c1
	# region: org2 g1

	# export TC_ORG2_G1_NAME=gw1
	# export TC_ORG2_G1_FQDN=${TC_ORG2_G1_NAME}.${TC_ORG2_DOMAIN}
	# export TC_ORG2_G1_TLS_NAME=$TC_ORG2_STACK-$TC_ORG2_G1_NAME
	# export TC_ORG2_G1_TLS_PW=$TC_ORG2_G1_TLS_PW
	# export TC_ORG2_G1_CA_NAME=${TC_ORG2_STACK}-${TC_ORG2_G1_NAME}
	# export TC_ORG2_G1_CA_PW=$TC_ORG2_G1_CA_PW

	# endregion: org2 g1
	# region: org2 p1
	
	export TC_ORG2_P1_NAME=peer1
	export TC_ORG2_P1_FQDN=${TC_ORG2_P1_NAME}.${TC_ORG2_DOMAIN}
	export TC_ORG2_P1_TLS_NAME=$TC_ORG2_STACK-$TC_ORG2_P1_NAME
	export TC_ORG2_P1_TLS_PW=$TC_ORG2_P1_TLS_PW
	export TC_ORG2_P1_CA_NAME=${TC_ORG2_STACK}-${TC_ORG2_P1_NAME}
	export TC_ORG2_P1_CA_PW=$TC_ORG2_P1_CA_PW

	# endregion: org2 p1
	# region: org2 p2
	
	export TC_ORG2_P2_NAME=peer2
	export TC_ORG2_P2_FQDN=${TC_ORG2_P2_NAME}.${TC_ORG2_DOMAIN}
	export TC_ORG2_P2_TLS_NAME=$TC_ORG2_STACK-$TC_ORG2_P2_NAME
	export TC_ORG2_P2_TLS_PW=$TC_ORG2_P2_TLS_PW
	export TC_ORG2_P2_CA_NAME=${TC_ORG2_STACK}-${TC_ORG2_P2_NAME}
	export TC_ORG2_P2_CA_PW=$TC_ORG2_P2_CA_PW

	# endregion: org2 p2
	# region: org2 p3
	
	export TC_ORG2_P3_NAME=peer3
	export TC_ORG2_P3_FQDN=${TC_ORG2_P3_NAME}.${TC_ORG2_DOMAIN}
	export TC_ORG2_P3_TLS_NAME=$TC_ORG2_STACK-$TC_ORG2_P3_NAME
	export TC_ORG2_P3_TLS_PW=$TC_ORG2_P3_TLS_PW
	export TC_ORG2_P3_CA_NAME=${TC_ORG2_STACK}-${TC_ORG2_P3_NAME}
	export TC_ORG2_P3_CA_PW=$TC_ORG2_P3_CA_PW

	# endregion: org2 p3
	
	# endregion: org2

# endregion: orgs
# region: common funcs

 [[ -f "$TC_PATH_COMMON" ]] && source "$TC_PATH_COMMON"

export COMMON_FORCE=$TC_EXEC_FORCE
export COMMON_PANIC=$TC_EXEC_PANIC
export COMMON_PREREQS=("${TC_DEPS_BINS[@]}")
export COMMON_SILENT=false
export COMMON_VERBOSE=true

# endregion: common funcs
