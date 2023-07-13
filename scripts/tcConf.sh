#!/bin/bash

#
# Copyright TE-FOOD International GmbH., All Rights Reserved
#

# region: load .env if any

# [[ -f .env ]] && source .env

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
export TC_PATH_DATASUB=organizations
export TC_PATH_DATA=${TC_PATH_STORAGE}/${TC_PATH_DATASUB}

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
export TC_EXEC_SILENT=false
export TC_EXEC_VERBOSE=true

# endregion: exec contorl
# region: versions and deps

export TC_DEPS_CA=1.5.6
export TC_DEPS_FABRIC=2.5.3
export TC_DEPS_COUCHDB=3.3.1
export TC_DEPS_BINS=('awk' 'bash' 'curl' 'git' 'go' 'jq' 'configtxgen' 'yq')

# endregion: versions and deps
# region: network and channel

export TC_NETWORK_NAME=trustchain-test
export TC_NETWORK_DOMAIN=${TC_NETWORK_NAME}.te-food.com

export TC_CHANNEL_PROFILE="DefaultProfile"
export TC_CHANNEL1_NAME=trustchain-test
export TC_CHANNEL2_NAME=trustchain

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

export TC_TLSCA_STACK=tls

export TC_TLSCA_C1_NAME=ca1
export TC_TLSCA_C1_FQDN=${TC_TLSCA_C1_NAME}.${TC_TLSCA_STACK}.${TC_NETWORK_DOMAIN}
export TC_TLSCA_C1_PORT=6001
export TC_TLSCA_C1_ADMIN=${TC_TLSCA_STACK}-${TC_TLSCA_C1_NAME}-admin1
export TC_TLSCA_C1_ADMINPW=$TC_TLSCA_C1_ADMINPW
export TC_TLSCA_C1_WORKER=$TC_SWARM_MANAGER
export TC_TLSCA_C1_DATA=${TC_PATH_STORAGE}/${TC_TLSCA_STACK}/${TC_TLSCA_C1_NAME}
# export TC_TLSCA_C1_DATA=${TC_PATH_DATA}/${TC_TLSCA_STACK}/${TC_TLSCA_C1_NAME}
# export TC_TLSCA_C1_SUBHOME=crypto
# export TC_TLSCA_C1_HOME=${TC_TLSCA_C1_DATA}/${TC_TLSCA_C1_SUBHOME}
export TC_TLSCA_C1_HOME=${TC_TLSCA_C1_DATA}
export TC_TLSCA_C1_DEBUG=false

# endregion: tls ca
# region: orgs

	# region: orderer1

		# region: orderer1 all stack

		export TC_ORDERER1_STACK=te-food-orderers
		export TC_ORDERER1_DATA=${TC_PATH_DATA}/ordererOrganizations/${TC_ORDERER1_STACK}
		export TC_ORDERER1_DOMAIN=${TC_ORDERER1_STACK}.${TC_NETWORK_DOMAIN}
		export TC_ORDERER1_LOGLEVEL=info

		export TC_ORDERER1_ADMIN=${TC_ORDERER1_STACK}-admin1
		export TC_ORDERER1_ADMINPW=$TC_ORDERER1_ADMINPW
		export TC_ORDERER1_ADMINATRS="hf.Registrar.Roles=client,hf.Registrar.Attributes=*,hf.Revoker=true,hf.GenCRL=true,admin=true:ecert,abac.init=true:ecert"
		export TC_ORDERER1_ADMINHOME=${TC_ORDERER1_DATA}/users/${TC_ORDERER1_ADMIN}
		export TC_ORDERER1_ADMINMSP=${TC_ORDERER1_ADMINHOME}/msp
		export TC_ORDERER1_ADMINTLSMSP=${TC_ORDERER1_ADMINHOME}/tls-msp

		# endregion: orderer1 all stack
		# region: orderer1 c1

		export TC_ORDERER1_C1_NAME=ca1
		export TC_ORDERER1_C1_FQDN=${TC_ORDERER1_C1_NAME}.${TC_ORDERER1_DOMAIN}
		export TC_ORDERER1_C1_PORT=7001
		export TC_ORDERER1_C1_DEBUG=false
		export TC_ORDERER1_C1_LOGLEVEL=$TC_ORDERER1_LOGLEVEL
		export TC_ORDERER1_C1_WORKER=$TC_SWARM_MANAGER
		export TC_ORDERER1_C1_DATA=${TC_ORDERER1_DATA}/${TC_ORDERER1_C1_NAME}
		# export TC_ORDERER1_C1_SUBHOME=crypto
		# export TC_ORDERER1_C1_HOME=${TC_ORDERER1_C1_DATA}/${TC_ORDERER1_C1_SUBHOME}	
		export TC_ORDERER1_C1_HOME=${TC_ORDERER1_C1_DATA}	

		export TC_ORDERER1_C1_ADMIN=${TC_ORDERER1_STACK}-${TC_ORDERER1_C1_NAME}-admin1
		export TC_ORDERER1_C1_ADMINPW=$TC_ORDERER1_C1_ADMINPW

		# export TC_ORDERER1_C1_TLS_NAME=$TC_ORDERER1_C1_NAME-$TC_ORDERER1_STACK
		# export TC_ORDERER1_C1_TLS_PW=$TC_ORDERER1_C1_TLS_PW

		# endregion: orderer1 c1
		# region: orderer1 o1

		export TC_ORDERER1_O1_NAME=orderer1
		export TC_ORDERER1_O1_FQDN=${TC_ORDERER1_O1_NAME}.${TC_ORDERER1_DOMAIN}
		export TC_ORDERER1_O1_PORT=7201
		export TC_ORDERER1_O1_ADMINPORT=7202
		export TC_ORDERER1_O1_OPPORT=7203
		export TC_ORDERER1_O1_WORKER=$TC_SWARM_MANAGER
		export TC_ORDERER1_O1_LOGLEVEL=$TC_ORDERER1_LOGLEVEL

		export TC_ORDERER1_O1_TLS_NAME=$TC_ORDERER1_STACK-$TC_ORDERER1_O1_NAME
		export TC_ORDERER1_O1_TLS_PW=$TC_ORDERER1_O1_TLS_PW
		export TC_ORDERER1_O1_CA_NAME=${TC_ORDERER1_O1_NAME}-${TC_ORDERER1_STACK}
		export TC_ORDERER1_O1_CA_PW=$TC_ORDERER1_O1_CA_PW

		export TC_ORDERER1_O1_DATA=${TC_ORDERER1_DATA}/orderers/${TC_ORDERER1_O1_NAME}
		export TC_ORDERER1_O1_MSP=${TC_ORDERER1_O1_DATA}/msp
		export TC_ORDERER1_O1_TLSMSP=${TC_ORDERER1_O1_DATA}/tls-msp
		export TC_ORDERER1_O1_ASSETS_SUBDIR=assets
		export TC_ORDERER1_O1_ASSETS_DIR=${TC_ORDERER1_O1_DATA}/${TC_ORDERER1_O1_ASSETS_SUBDIR}
		export TC_ORDERER1_O1_ASSETS_CACERT=${TC_ORDERER1_O1_ASSETS_DIR}/${TC_ORDERER1_C1_FQDN}/ca-cert.pem
		export TC_ORDERER1_O1_ASSETS_TLSCERT=${TC_ORDERER1_O1_ASSETS_DIR}/${TC_TLSCA_C1_FQDN}/ca-cert.pem	

		# endregion: orderer1 o1
		# region: orderer1 o2

		export TC_ORDERER1_O2_NAME=orderer2
		export TC_ORDERER1_O2_FQDN=${TC_ORDERER1_O2_NAME}.${TC_ORDERER1_DOMAIN}
		export TC_ORDERER1_O2_PORT=7301
		export TC_ORDERER1_O2_ADMINPORT=7302
		export TC_ORDERER1_O2_OPPORT=7303
		export TC_ORDERER1_O2_WORKER=$TC_SWARM_MANAGER
		export TC_ORDERER1_O2_LOGLEVEL=$TC_ORDERER1_LOGLEVEL

		export TC_ORDERER1_O2_TLS_NAME=$TC_ORDERER1_STACK-$TC_ORDERER1_O2_NAME
		export TC_ORDERER1_O2_TLS_PW=$TC_ORDERER1_O2_TLS_PW
		export TC_ORDERER1_O2_CA_NAME=${TC_ORDERER1_O2_NAME}-${TC_ORDERER1_STACK}
		export TC_ORDERER1_O2_CA_PW=$TC_ORDERER1_O2_CA_PW

		export TC_ORDERER1_O2_DATA=${TC_ORDERER1_DATA}/orderers/${TC_ORDERER1_O2_NAME}
		export TC_ORDERER1_O2_MSP=${TC_ORDERER1_O2_DATA}/msp
		export TC_ORDERER1_O2_TLSMSP=${TC_ORDERER1_O2_DATA}/tls-msp
		export TC_ORDERER1_O2_ASSETS_SUBDIR=assets
		export TC_ORDERER1_O2_ASSETS_DIR=${TC_ORDERER1_O2_DATA}/${TC_ORDERER1_O2_ASSETS_SUBDIR}
		export TC_ORDERER1_O2_ASSETS_CACERT=${TC_ORDERER1_O2_ASSETS_DIR}/${TC_ORDERER1_C1_FQDN}/ca-cert.pem
		export TC_ORDERER1_O2_ASSETS_TLSCERT=${TC_ORDERER1_O2_ASSETS_DIR}/${TC_TLSCA_C1_FQDN}/ca-cert.pem	

		# endregion: orderer1 o2
		# region: orderer1 o3

		export TC_ORDERER1_O3_NAME=orderer3
		export TC_ORDERER1_O3_FQDN=${TC_ORDERER1_O3_NAME}.${TC_ORDERER1_DOMAIN}
		export TC_ORDERER1_O3_PORT=7101
		export TC_ORDERER1_O3_ADMINPORT=7102
		export TC_ORDERER1_O3_OPPORT=7103
		export TC_ORDERER1_O3_WORKER=$TC_SWARM_MANAGER
		export TC_ORDERER1_O3_LOGLEVEL=$TC_ORDERER1_LOGLEVEL

		export TC_ORDERER1_O3_TLS_NAME=$TC_ORDERER1_STACK-$TC_ORDERER1_O3_NAME
		export TC_ORDERER1_O3_TLS_PW=$TC_ORDERER1_O3_TLS_PW
		export TC_ORDERER1_O3_CA_NAME=${TC_ORDERER1_O3_NAME}-${TC_ORDERER1_STACK}
		export TC_ORDERER1_O3_CA_PW=$TC_ORDERER1_O3_CA_PW

		export TC_ORDERER1_O3_DATA=${TC_ORDERER1_DATA}/orderers/${TC_ORDERER1_O3_NAME}
		export TC_ORDERER1_O3_MSP=${TC_ORDERER1_O3_DATA}/msp
		export TC_ORDERER1_O3_TLSMSP=${TC_ORDERER1_O3_DATA}/tls-msp
		export TC_ORDERER1_O3_ASSETS_SUBDIR=assets
		export TC_ORDERER1_O3_ASSETS_DIR=${TC_ORDERER1_O3_DATA}/${TC_ORDERER1_O3_ASSETS_SUBDIR}
		export TC_ORDERER1_O3_ASSETS_CACERT=${TC_ORDERER1_O3_ASSETS_DIR}/${TC_ORDERER1_C1_FQDN}/ca-cert.pem
		export TC_ORDERER1_O3_ASSETS_TLSCERT=${TC_ORDERER1_O3_ASSETS_DIR}/${TC_TLSCA_C1_FQDN}/ca-cert.pem

		# endregion: orderer1 o3

	# endregion: orderer1
	# region: org1

		# region: org1 all stack

		export TC_ORG1_STACK=te-food-endorsers
		export TC_ORG1_DATA=${TC_PATH_DATA}/peerOrganizations/${TC_ORG1_STACK}
		export TC_ORG1_DOMAIN=${TC_ORG1_STACK}.${TC_NETWORK_DOMAIN}
		export TC_ORG1_LOGLEVEL=info

		export TC_ORG1_ADMIN=${TC_ORG1_STACK}-admin1
		export TC_ORG1_ADMINPW=$TC_ORG1_ADMINPW
		export TC_ORG1_ADMINATRS="hf.Registrar.Roles=client,hf.Registrar.Attributes=*,hf.Revoker=true,hf.GenCRL=true,admin=true:ecert,abac.init=true:ecert"
		export TC_ORG1_ADMINHOME=${TC_ORG1_DATA}/users/${TC_ORG1_ADMIN}
		export TC_ORG1_ADMINMSP=${TC_ORG1_ADMINHOME}/msp
		export TC_ORG1_USER=${TC_ORG1_STACK}-user1
		export TC_ORG1_USERPW=$TC_ORG1_USERPW
		export TC_ORG1_USERMSP=${TC_ORG1_DATA}/users/${TC_ORG1_USER}/msp
		export TC_ORG1_CLIENT=${TC_ORG1_STACK}-client1
		export TC_ORG1_CLIENTPW=$TC_ORG1_CLIENTPW
		export TC_ORG1_CLIENTMSP=${TC_ORG1_DATA}/users/${TC_ORG1_CLIENT}/msp

		# endregion: org1 all stack
		# region: org1 c1

		export TC_ORG1_C1_NAME=ca1
		export TC_ORG1_C1_FQDN=${TC_ORG1_C1_NAME}.${TC_ORG1_DOMAIN}
		export TC_ORG1_C1_PORT=8001
		export TC_ORG1_C1_DEBUG=false
		export TC_ORG1_C1_LOGLEVEL=$TC_ORG1_LOGLEVEL
		export TC_ORG1_C1_WORKER=$TC_SWARM_MANAGER
		export TC_ORG1_C1_DATA=${TC_ORG1_DATA}/${TC_ORG1_C1_NAME}
		# export TC_ORG1_C1_SUBHOME=crypto
		# export TC_ORG1_C1_HOME=${TC_ORG1_C1_DATA}/${TC_ORG1_C1_SUBHOME}
		export TC_ORG1_C1_HOME=${TC_ORG1_C1_DATA}

		export TC_ORG1_C1_ADMIN=${TC_ORG1_STACK}-${TC_ORG1_C1_NAME}-admin1
		export TC_ORG1_C1_ADMINPW=$TC_ORG1_C1_ADMINPW

		# endregion: org1 c1
		# region: org1 state dbs

		export TC_ORG1_D1_NAME=db1
		export TC_ORG1_D1_USER=${TC_ORG1_D1_NAME}-${TC_ORG1_STACK}
		export TC_ORG1_D1_USERPW=$TC_ORG1_D1_USERPW
		export TC_ORG1_D1_WORKER=$TC_SWARM_MANAGER
		export TC_ORG1_D1_FQDN=${TC_ORG1_D1_NAME}.${TC_ORG1_DOMAIN}
		export TC_ORG1_D1_PORT=5801
		export TC_ORG1_D1_DATA=${TC_ORG1_DATA}/dbs/${TC_ORG1_D1_NAME}

		export TC_ORG1_D2_NAME=db2
		export TC_ORG1_D2_USER=${TC_ORG1_D2_NAME}-${TC_ORG1_STACK}
		export TC_ORG1_D2_USERPW=$TC_ORG1_D2_USERPW
		export TC_ORG1_D2_WORKER=$TC_SWARM_MANAGER
		export TC_ORG1_D2_FQDN=${TC_ORG1_D2_NAME}.${TC_ORG1_DOMAIN}
		export TC_ORG1_D2_PORT=5802
		export TC_ORG1_D2_DATA=${TC_ORG1_DATA}/dbs/${TC_ORG1_D2_NAME}

		export TC_ORG1_D3_NAME=db3
		export TC_ORG1_D3_USER=${TC_ORG1_D3_NAME}-${TC_ORG1_STACK}
		export TC_ORG1_D3_USERPW=$TC_ORG1_D3_USERPW
		export TC_ORG1_D3_WORKER=$TC_SWARM_MANAGER
		export TC_ORG1_D3_FQDN=${TC_ORG1_D3_NAME}.${TC_ORG1_DOMAIN}
		export TC_ORG1_D3_PORT=5803
		export TC_ORG1_D3_DATA=${TC_ORG1_DATA}/dbs/${TC_ORG1_D3_NAME}

		# endregion: org1 state dbs
		# region: org1 peers

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
		export TC_ORG1_P1_CA_NAME=${TC_ORG1_P1_NAME}-${TC_ORG1_STACK}
		export TC_ORG1_P1_CA_PW=$TC_ORG1_P1_CA_PW

		export TC_ORG1_P1_DATA=${TC_ORG1_DATA}/peers/${TC_ORG1_P1_NAME}
		export TC_ORG1_P1_MSP=${TC_ORG1_P1_DATA}/msp
		export TC_ORG1_P1_TLSMSP=${TC_ORG1_P1_DATA}/tls-msp
		export TC_ORG1_P1_ASSETS_SUBDIR=assets
		export TC_ORG1_P1_ASSETS_DIR=${TC_ORG1_P1_DATA}/${TC_ORG1_P1_ASSETS_SUBDIR}
		export TC_ORG1_P1_ASSETS_CHAINSUBDIR=chaincode
		export TC_ORG1_P1_ASSETS_CHAINCODE=${TC_ORG1_P1_ASSETS_DIR}/${TC_ORG1_P1_ASSETS_CHAINSUBDIR}
		export TC_ORG1_P1_ASSETS_CACERT=${TC_ORG1_P1_ASSETS_DIR}/${TC_ORG1_C1_FQDN}/ca-cert.pem
		export TC_ORG1_P1_ASSETS_TLSCERT=${TC_ORG1_P1_ASSETS_DIR}/${TC_TLSCA_C1_FQDN}/ca-cert.pem

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
		export TC_ORG1_P2_CA_NAME=${TC_ORG1_P2_NAME}-${TC_ORG1_STACK}
		export TC_ORG1_P2_CA_PW=$TC_ORG1_P2_CA_PW

		export TC_ORG1_P2_DATA=${TC_ORG1_DATA}/peers/${TC_ORG1_P2_NAME}
		export TC_ORG1_P2_MSP=${TC_ORG1_P2_DATA}/msp
		export TC_ORG1_P2_TLSMSP=${TC_ORG1_P2_DATA}/tls-msp
		export TC_ORG1_P2_ASSETS_CACERT=${TC_ORG1_P2_DATA}/assets/${TC_ORG1_C1_FQDN}/ca-cert.pem
		export TC_ORG1_P2_ASSETS_TLSCERT=${TC_ORG1_P2_DATA}/assets/${TC_TLSCA_C1_FQDN}/ca-cert.pem

		# endregion: org1 p2
		# region: org1 p3
		
		export TC_ORG1_P3_NAME=peer3
		export TC_ORG1_P3_FQDN=${TC_ORG1_P3_NAME}.${TC_ORG1_DOMAIN}
		export TC_ORG1_P3_PORT=8301
		export TC_ORG1_P3_CHPORT=8302
		export TC_ORG1_P3_OPPORT=8303
		export TC_ORG1_P3_WORKER=$TC_SWARM_MANAGER
		export TC_ORG1_P3_LOGLEVEL=$TC_ORG1_LOGLEVEL

		export TC_ORG1_P3_TLS_NAME=$TC_ORG1_STACK-$TC_ORG1_P3_NAME
		export TC_ORG1_P3_TLS_PW=$TC_ORG1_P3_TLS_PW
		export TC_ORG1_P3_CA_NAME=${TC_ORG1_P3_NAME}-${TC_ORG1_STACK}
		export TC_ORG1_P3_CA_PW=$TC_ORG1_P3_CA_PW

		export TC_ORG1_P3_DATA=${TC_ORG1_DATA}/peers/${TC_ORG1_P3_NAME}
		export TC_ORG1_P3_MSP=${TC_ORG1_P3_DATA}/msp
		export TC_ORG1_P3_TLSMSP=${TC_ORG1_P3_DATA}/tls-msp
		export TC_ORG1_P3_ASSETS_CACERT=${TC_ORG1_P3_DATA}/assets/${TC_ORG1_C1_FQDN}/ca-cert.pem
		export TC_ORG1_P3_ASSETS_TLSCERT=${TC_ORG1_P3_DATA}/assets/${TC_TLSCA_C1_FQDN}/ca-cert.pem

		# endregion: org1 p3
		
		# endregion: org1 peers
		# region: org1 g1

		export TC_ORG1_G1_NAME=gw1
		export TC_ORG1_G1_FQDN=${TC_ORG1_G1_NAME}.${TC_ORG1_DOMAIN}
		export TC_ORG1_G1_PEER_ADDRESS=${TC_ORG1_P1_FQDN}:${TC_ORG1_P1_PORT}
		export TC_ORG1_G1_PEER_ID=$TC_ORG1_P1_CA_NAME
		export TC_ORG1_G1_WORKER=$TC_SWARM_MANAGER
		export TC_ORG1_G1_LOGLEVEL=$TC_ORG1_LOGLEVEL

		export TC_ORG1_G1_TLS_NAME=$TC_ORG1_STACK-$TC_ORG1_G1_NAME
		export TC_ORG1_G1_TLS_PW=$TC_ORG1_G1_TLS_PW
		export TC_ORG1_G1_CA_NAME=${TC_ORG1_G1_NAME}-${TC_ORG1_STACK}
		export TC_ORG1_G1_CA_PW=$TC_ORG1_G1_CA_PW

		export TC_ORG1_G1_API=5800
		export TC_ORG1_G1_PORT=$TC_ORG1_P1_PORT
		# export TC_ORG1_G1_CHPORT=$TC_ORG1_P1_CHPORT
		# export TC_ORG1_G1_OPPORT=$TC_ORG1_P1_OPPORT

		export TC_ORG1_G1_DATA=${TC_ORG1_DATA}/${TC_ORG1_G1_NAME}
		export TC_ORG1_G1_MSP=${TC_ORG1_G1_DATA}/msp
		export TC_ORG1_G1_TLSMSP=${TC_ORG1_G1_DATA}/tls-msp
		export TC_ORG1_G1_ASSETS_SUBDIR=assets
		export TC_ORG1_G1_ASSETS_DIR=${TC_ORG1_G1_DATA}/${TC_ORG1_G1_ASSETS_SUBDIR}
		export TC_ORG1_G1_ASSETS_CHAINSUBDIR=chaincode
		export TC_ORG1_G1_ASSETS_CHAINCODE=${TC_ORG1_G1_ASSETS_DIR}/${TC_ORG1_G1_ASSETS_CHAINSUBDIR}
		export TC_ORG1_G1_ASSETS_CACERT=${TC_ORG1_G1_ASSETS_DIR}/${TC_ORG1_C1_FQDN}/ca-cert.pem
		export TC_ORG1_G1_ASSETS_TLSCERT=${TC_ORG1_G1_ASSETS_DIR}/${TC_TLSCA_C1_FQDN}/ca-cert.pem

		# endregion: org1 g1
		# region: org1 cli
		
		export TC_ORG1_CLI1_NAME=cli1
		export TC_ORG1_CLI1_FQDN=${TC_ORG1_CLI1_NAME}.${TC_ORG1_DOMAIN}
		export TC_ORG1_CLI1_PEER_ADDRESS=${TC_ORG1_P1_FQDN}:${TC_ORG1_P1_PORT}
		export TC_ORG1_CLI1_PEER_ID=$TC_ORG1_P1_CA_NAME
		export TC_ORG1_CLI1_PORT=$TC_ORG1_P1_PORT
		export TC_ORG1_CLI1_CHPORT=$TC_ORG1_P1_CHPORT
		export TC_ORG1_CLI1_OPPORT=$TC_ORG1_P1_OPPORT
		export TC_ORG1_CLI1_WORKER=$TC_SWARM_MANAGER
		export TC_ORG1_CLI1_LOGLEVEL=$TC_ORG1_LOGLEVEL

		export TC_ORG1_CLI1_DATA=$TC_ORG1_P1_DATA
		export TC_ORG1_CLI1_MSP=$TC_ORG1_P1_MSP
		export TC_ORG1_CLI1_TLSMSP=$TC_ORG1_P1_TLSMSP
		export TC_ORG1_CLI1_ASSETS_CACERT=$TC_ORG1_P1_ASSETS_CACERT
		export TC_ORG1_CLI1_ASSETS_TLSCERT=$TC_ORG1_P1_ASSETS_TLSCERT
		export TC_ORG1_CLI1_ASSETS_CHAINCODE=$TC_ORG1_P1_ASSETS_CHAINCODE

		# endregion: org1 cli

	# endregion: org1
	# region: org2

		# region: org2 all stack

		export TC_ORG2_STACK=masternodes
		export TC_ORG2_DATA=${TC_PATH_DATA}/peerOrganizations/${TC_ORG2_STACK}
		export TC_ORG2_DOMAIN=${TC_ORG2_STACK}.${TC_NETWORK_DOMAIN}
		export TC_ORG2_LOGLEVEL=info

		export TC_ORG2_ADMIN=${TC_ORG2_STACK}-admin1
		export TC_ORG2_ADMINPW=$TC_ORG2_ADMINPW
		export TC_ORG2_ADMINATRS="hf.Registrar.Roles=client,hf.Registrar.Attributes=*,hf.Revoker=true,hf.GenCRL=true,admin=true:ecert,abac.init=true:ecert"
		export TC_ORG2_ADMINHOME=${TC_ORG2_DATA}/users/${TC_ORG2_ADMIN}
		export TC_ORG2_ADMINMSP=${TC_ORG2_ADMINHOME}/msp

		# endregion: org2 all stack
		# region: org2 c1

		export TC_ORG2_C1_NAME=ca1
		export TC_ORG2_C1_FQDN=${TC_ORG2_C1_NAME}.${TC_ORG2_DOMAIN}
		export TC_ORG2_C1_PORT=9001
		export TC_ORG2_C1_DEBUG=false
		export TC_ORG2_C1_LOGLEVEL=$TC_ORG2_LOGLEVEL
		export TC_ORG2_C1_WORKER=$TC_SWARM_MANAGER
		export TC_ORG2_C1_DATA=${TC_ORG2_DATA}/${TC_ORG2_C1_NAME}
		# export TC_ORG2_C1_SUBHOME=crypto
		# export TC_ORG2_C1_HOME=${TC_ORG2_C1_DATA}/${TC_ORG2_C1_SUBHOME}
		export TC_ORG2_C1_HOME=${TC_ORG2_C1_DATA}

		export TC_ORG2_C1_ADMIN=${TC_ORG2_STACK}-${TC_ORG2_C1_NAME}-admin1
		export TC_ORG2_C1_ADMINPW=$TC_ORG2_C1_ADMINPW

		# endregion: org2 c1
		# region: org2 state dbs

		export TC_ORG2_D1_NAME=db1
		export TC_ORG2_D1_USER=${TC_ORG2_D1_NAME}-${TC_ORG2_STACK}
		export TC_ORG2_D1_USERPW=$TC_ORG2_D1_USERPW
		export TC_ORG2_D1_WORKER=$TC_SWARM_MANAGER
		export TC_ORG2_D1_FQDN=${TC_ORG2_D1_NAME}.${TC_ORG2_DOMAIN}
		export TC_ORG2_D1_PORT=5901
		export TC_ORG2_D1_DATA=${TC_ORG2_DATA}/dbs/${TC_ORG2_D1_NAME}

		export TC_ORG2_D2_NAME=db2
		export TC_ORG2_D2_USER=${TC_ORG2_D2_NAME}-${TC_ORG2_STACK}
		export TC_ORG2_D2_USERPW=$TC_ORG2_D2_USERPW
		export TC_ORG2_D2_WORKER=$TC_SWARM_MANAGER
		export TC_ORG2_D2_FQDN=${TC_ORG2_D2_NAME}.${TC_ORG2_DOMAIN}
		export TC_ORG2_D2_PORT=5902
		export TC_ORG2_D2_DATA=${TC_ORG2_DATA}/dbs/${TC_ORG2_D2_NAME}

		export TC_ORG2_D3_NAME=db3
		export TC_ORG2_D3_USER=${TC_ORG2_D3_NAME}-${TC_ORG2_STACK}
		export TC_ORG2_D3_USERPW=$TC_ORG2_D3_USERPW
		export TC_ORG2_D3_WORKER=$TC_SWARM_MANAGER
		export TC_ORG2_D3_FQDN=${TC_ORG2_D3_NAME}.${TC_ORG2_DOMAIN}
		export TC_ORG2_D3_PORT=5903
		export TC_ORG2_D3_DATA=${TC_ORG2_DATA}/dbs/${TC_ORG2_D3_NAME}

		# endregion: org2 state dbs
		# region: org2 peers

		# region: org2 p1
		
		export TC_ORG2_P1_NAME=peer1
		export TC_ORG2_P1_FQDN=${TC_ORG2_P1_NAME}.${TC_ORG2_DOMAIN}
		export TC_ORG2_P1_PORT=9101
		export TC_ORG2_P1_CHPORT=9102
		export TC_ORG2_P1_OPPORT=9103
		export TC_ORG2_P1_WORKER=$TC_SWARM_MANAGER
		export TC_ORG2_P1_LOGLEVEL=$TC_ORG2_LOGLEVEL

		export TC_ORG2_P1_TLS_NAME=$TC_ORG2_STACK-$TC_ORG2_P1_NAME
		export TC_ORG2_P1_TLS_PW=$TC_ORG2_P1_TLS_PW
		export TC_ORG2_P1_CA_NAME=${TC_ORG2_P1_NAME}-${TC_ORG2_STACK}
		export TC_ORG2_P1_CA_PW=$TC_ORG2_P1_CA_PW

		export TC_ORG2_P1_DATA=${TC_ORG2_DATA}/peers/${TC_ORG2_P1_NAME}
		export TC_ORG2_P1_MSP=${TC_ORG2_P1_DATA}/msp
		export TC_ORG2_P1_TLSMSP=${TC_ORG2_P1_DATA}/tls-msp
		export TC_ORG2_P1_ASSETS_SUBDIR=assets
		export TC_ORG2_P1_ASSETS_DIR=${TC_ORG2_P1_DATA}/${TC_ORG2_P1_ASSETS_SUBDIR}
		export TC_ORG2_P1_ASSETS_CHAINSUBDIR=chaincode
		export TC_ORG2_P1_ASSETS_CHAINCODE=${TC_ORG2_P1_ASSETS_DIR}/${TC_ORG2_P1_ASSETS_CHAINSUBDIR}
		export TC_ORG2_P1_ASSETS_CACERT=${TC_ORG2_P1_ASSETS_DIR}/${TC_ORG2_C1_FQDN}/ca-cert.pem
		export TC_ORG2_P1_ASSETS_TLSCERT=${TC_ORG2_P1_ASSETS_DIR}/${TC_TLSCA_C1_FQDN}/ca-cert.pem

		# endregion: org2 p1
		# region: org2 p2
		
		export TC_ORG2_P2_NAME=peer2
		export TC_ORG2_P2_FQDN=${TC_ORG2_P2_NAME}.${TC_ORG2_DOMAIN}
		export TC_ORG2_P2_PORT=9201
		export TC_ORG2_P2_CHPORT=9202
		export TC_ORG2_P2_OPPORT=9203
		export TC_ORG2_P2_WORKER=$TC_SWARM_MANAGER
		export TC_ORG2_P2_LOGLEVEL=$TC_ORG2_LOGLEVEL

		export TC_ORG2_P2_TLS_NAME=$TC_ORG2_STACK-$TC_ORG2_P2_NAME
		export TC_ORG2_P2_TLS_PW=$TC_ORG2_P2_TLS_PW
		export TC_ORG2_P2_CA_NAME=${TC_ORG2_P2_NAME}-${TC_ORG2_STACK}
		export TC_ORG2_P2_CA_PW=$TC_ORG2_P2_CA_PW

		export TC_ORG2_P2_DATA=${TC_ORG2_DATA}/peers/${TC_ORG2_P2_NAME}
		export TC_ORG2_P2_MSP=${TC_ORG2_P2_DATA}/msp
		export TC_ORG2_P2_TLSMSP=${TC_ORG2_P2_DATA}/tls-msp
		export TC_ORG2_P2_ASSETS_CACERT=${TC_ORG2_P2_DATA}/assets/${TC_ORG2_C1_FQDN}/ca-cert.pem
		export TC_ORG2_P2_ASSETS_TLSCERT=${TC_ORG2_P2_DATA}/assets/${TC_TLSCA_C1_FQDN}/ca-cert.pem

		# endregion: org2 p2
		# region: org2 p3
		
		export TC_ORG2_P3_NAME=peer3
		export TC_ORG2_P3_FQDN=${TC_ORG2_P3_NAME}.${TC_ORG2_DOMAIN}
		export TC_ORG2_P3_PORT=9301
		export TC_ORG2_P3_CHPORT=9302
		export TC_ORG2_P3_OPPORT=9303
		export TC_ORG2_P3_WORKER=$TC_SWARM_MANAGER
		export TC_ORG2_P3_LOGLEVEL=$TC_ORG2_LOGLEVEL

		export TC_ORG2_P3_TLS_NAME=$TC_ORG2_STACK-$TC_ORG2_P3_NAME
		export TC_ORG2_P3_TLS_PW=$TC_ORG2_P3_TLS_PW
		export TC_ORG2_P3_CA_NAME=${TC_ORG2_P3_NAME}-${TC_ORG2_STACK}
		export TC_ORG2_P3_CA_PW=$TC_ORG2_P3_CA_PW

		export TC_ORG2_P3_DATA=${TC_ORG2_DATA}/peers/${TC_ORG2_P3_NAME}
		export TC_ORG2_P3_MSP=${TC_ORG2_P3_DATA}/msp
		export TC_ORG2_P3_TLSMSP=${TC_ORG2_P3_DATA}/tls-msp
		export TC_ORG2_P3_ASSETS_CACERT=${TC_ORG2_P3_DATA}/assets/${TC_ORG2_C1_FQDN}/ca-cert.pem
		export TC_ORG2_P3_ASSETS_TLSCERT=${TC_ORG2_P3_DATA}/assets/${TC_TLSCA_C1_FQDN}/ca-cert.pem

		# endregion: org2 p3

		# endregion: org2 peers
		# region: org2 cli

		export TC_ORG2_CLI1_NAME=cli1
		export TC_ORG2_CLI1_FQDN=${TC_ORG2_CLI1_NAME}.${TC_ORG2_DOMAIN}
		export TC_ORG2_CLI1_PEER_FQDN=$TC_ORG2_P1_FQDN
		export TC_ORG2_CLI1_PEER_NAME=$TC_ORG2_P1_NAME
		export TC_ORG2_CLI1_PORT=$TC_ORG2_P1_PORT
		export TC_ORG2_CLI1_CHPORT=$TC_ORG2_P1_CHPORT
		export TC_ORG2_CLI1_OPPORT=$TC_ORG2_P1_OPPORT
		export TC_ORG2_CLI1_WORKER=$TC_SWARM_MANAGER
		export TC_ORG2_CLI1_LOGLEVEL=$TC_ORG2_LOGLEVEL

		export TC_ORG2_CLI1_DATA=$TC_ORG2_P1_DATA
		export TC_ORG2_CLI1_MSP=$TC_ORG2_P1_MSP
		export TC_ORG2_CLI1_TLSMSP=$TC_ORG2_P1_TLSMSP
		export TC_ORG2_CLI1_ASSETS_CACERT=$TC_ORG2_P1_ASSETS_CACERT
		export TC_ORG2_CLI1_ASSETS_TLSCERT=$TC_ORG2_P1_ASSETS_TLSCERT
		export TC_ORG2_CLI1_ASSETS_CHAINCODE=$TC_ORG2_P1_ASSETS_CHAINCODE

	# endregion: org2 cli

	# endregion: org2

# endregion: orgs
# region: common services

	# region: common1

	export TC_COMMON1_STACK=metrics
	export TC_COMMON1_DATASUB=${TC_COMMON1_STACK}
	export TC_COMMOM1_DATA=${TC_PATH_STORAGE}/${TC_COMMON1_STACK}
	export TC_COMMON1_UID=$( id -u )
	export TC_COMMON1_GID=$( id -g )
	
	export TC_COMMON1_S1_NAME=visualizer
	export TC_COMMON1_S1_PORT=5101
	export TC_COMMON1_S2_NAME=logspout
	export TC_COMMON1_S2_PORT=5102
	export TC_COMMON1_S3_NAME=prometheus
	export TC_COMMON1_S3_DATA=${TC_COMMOM1_DATA}/${TC_COMMON1_S3_NAME}
	export TC_COMMON1_S3_PORT=5103
	export TC_COMMON1_S3_WORKER=$TC_SWARM_MANAGER
	export TC_COMMON1_S4_NAME=cadvisor
	export TC_COMMON1_S4_PORT=5104
	export TC_COMMON1_S4_WORKER=$TC_SWARM_MANAGER
	export TC_COMMON1_S5_NAME=node-exporter
	export TC_COMMON1_S5_PORT=5105
	export TC_COMMON1_S5_WORKER=$TC_SWARM_MANAGER
	export TC_COMMON1_S6_NAME=grafana
	export TC_COMMON1_S6_PORT=5106
	export TC_COMMON1_S6_WORKER=$TC_SWARM_MANAGER
	export TC_COMMON1_S6_DATA=${TC_COMMOM1_DATA}/${TC_COMMON1_S6_NAME}

	# endregion: common1
	# region: common2

	export TC_COMMON2_STACK=mgmt
	export TC_COMMON2_DATASUB=${TC_COMMON2_STACK}
	export TC_COMMOM2_DATA=${TC_PATH_STORAGE}/${TC_COMMON2_STACK}

	export TC_COMMON2_S1_NAME=busybox
	export TC_COMMON2_S1_WORKER=$TC_SWARM_MANAGER
	export TC_COMMON2_S2_NAME=netshoot
	export TC_COMMON2_S2_WORKER=$TC_SWARM_MANAGER
	export TC_COMMON2_S3_NAME=portainer-agent
	export TC_COMMON2_S4_NAME=portainer
	export TC_COMMON2_S4_PORT=5204
	export TC_COMMON2_S4_DATA=${TC_COMMOM2_DATA}/${TC_COMMON2_S4_NAME}

	# endregion: common2

# endregion: common services
# region: common funcs

 [[ -f "$TC_PATH_COMMON" ]] && source "$TC_PATH_COMMON"

export COMMON_FORCE=$TC_EXEC_FORCE
export COMMON_PANIC=$TC_EXEC_PANIC
export COMMON_PREREQS=("${TC_DEPS_BINS[@]}")
export COMMON_SILENT=$TC_EXEC_SILENT
export COMMON_VERBOSE=$TC_EXEC_VERBOSE
export COMMON_FUNCS=$TC_PATH_COMMOM

# endregion: common funcs
