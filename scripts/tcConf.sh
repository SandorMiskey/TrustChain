#!/bin/bash

#
# Copyright TE-FOOD International GmbH., All Rights Reserved
#

# region: base paths

# get them from .env 
export TC_PATH_BASE=$TC_PATH_BASE
export TC_PATH_RC=$TC_PATH_RC

# dirs under base
export TC_PATH_BIN=${TC_PATH_BASE}/bin
export TC_PATH_SCRIPTS=${TC_PATH_BASE}/scripts
export TC_PATH_TEMPLATES=${TC_PATH_BASE}/templates
export TC_PATH_LOCALWORKBENCH=${TC_PATH_BASE}/workbench

# trustchain independent common functions
export TC_PATH_COMMON=${TC_PATH_SCRIPTS}/commonFuncs.sh

# add scripts and bins to PATH
export PATH=${TC_PATH_BIN}:${TC_PATH_SCRIPTS}:$PATH

# dirs under workbench
export TC_PATH_WORKBENCH=/srv/TrustChain
export TC_PATH_SWARM=${TC_PATH_WORKBENCH}/swarm
export TC_PATH_ORGS=${TC_PATH_WORKBENCH}/organizations
export TC_PATH_CHANNELS=${TC_PATH_WORKBENCH}/channels
export TC_PATH_CHAINCODE=${TC_PATH_WORKBENCH}/chaincode

# endregion: base paths
# region: exec control

export TC_EXEC_DRY=false
export TC_EXEC_FORCE=false
export TC_EXEC_SURE=false
export TC_EXEC_PANIC=true
export TC_EXEC_SILENT=false
export TC_EXEC_VERBOSE=true

# endregion: exec contorl
# region: versions and deps

export TC_DEPS_CA=1.5.6
export TC_DEPS_FABRIC=2.5.4
export TC_DEPS_COUCHDB=3.3.1
export TC_DEPS_BINS=('awk' 'bash' 'curl' 'git' 'go' 'jq' 'configtxgen' 'yq')

# endregion: versions and deps
# region: environment

# export TC_USER_NAME="trustchain"
# export TC_USER_UID=12345
# export TC_USER_GROUP="trustchain"
# export TC_USER_GID=12345

# endregion: environment
# region: network and channel

export TC_NETWORK_NAME=trustchain-test
export TC_NETWORK_DOMAIN=${TC_NETWORK_NAME}.te-food.com

export TC_CHANNEL_PROFILE="DefaultProfile"
export TC_CHANNEL1_NAME=trustchain-test
export TC_CHANNEL2_NAME=trustchain

# endregion: network and channel
# region: swarm

# 3.77.27.176		tc2-test-manager1
# 3.125.250.181		tc2-test-manager2
# 54.93.194.71		tc2-test-manager3
# 3.77.143.132		tc2-test-worker1
# 185.187.73.203	tc2-test-worker2
# 18.197.74.200		tc2-test-worker3

declare -A TC_SWARM_MANAGER1=( [node]=tc2-test-manager1 [ip]=3.77.27.176 [gdev]=/dev/nvme1n1p1 [gmnt]=/srv/GlusterData )
declare -A TC_SWARM_MANAGER2=( [node]=tc2-test-manager2 [ip]=3.125.250.181 [gdev]=/dev/nvme1n1p1 [gmnt]=/srv/GlusterData )
declare -A TC_SWARM_MANAGER3=( [node]=tc2-test-manager3 [ip]=54.93.194.71 [gdev]=/dev/nvme1n1p1 [gmnt]=/srv/GlusterData )
TC_SWARM_MANAGERS=("TC_SWARM_MANAGER1" "TC_SWARM_MANAGER2" "TC_SWARM_MANAGER3")

declare -A TC_SWARM_WORKER1=( [node]=tc2-test-worker1 [ip]=3.77.143.132 )
declare -A TC_SWARM_WORKER2=( [node]=tc2-test-worker2 [ip]=185.187.73.203 )
declare -A TC_SWARM_WORKER3=( [node]=tc2-test-worker3 [ip]=18.197.74.200 )
TC_SWARM_WORKERS=("TC_SWARM_WORKER1" "TC_SWARM_WORKER2" "TC_SWARM_WORKER3")
# TC_SWARM_WORKERS=("TC_SWARM_WORKER1")

export TC_SWARM_PATH=$TC_PATH_SWARM
export TC_SWARM_PUBLIC=${TC_SWARM_MANAGER1[ip]}
export TC_SWARM_INIT="--advertise-addr ${TC_SWARM_PUBLIC}:2377 --cert-expiry 1000000h0m0s"
export TC_SWARM_MANAGER=${TC_SWARM_MANAGER1[node]}
export TC_SWARM_NETNAME=$TC_NETWORK_NAME
export TC_SWARM_NETINIT="--attachable --driver overlay --subnet 10.96.0.0/24 $TC_SWARM_NETNAME"
export TC_SWARM_DELAY=20

export TC_SWARM_IMG_COUCHDB=localhost:6000/trustchain-couchdb
export TC_SWARM_IMG_CA=localhost:6000/trustchain-fabric-ca
export TC_SWARM_IMG_ORDERER=localhost:6000/trustchain-fabric-orderer
export TC_SWARM_IMG_PEER=localhost:6000/trustchain-fabric-peer
export TC_SWARM_IMG_TOOLS=localhost:6000/trustchain-fabric-tools
export TC_SWARM_IMG_VISUALIZER=localhost:6000/trustchain-visualizer
export TC_SWARM_IMG_LOGSPOUT=localhost:6000/trustchain-logspout
export TC_SWARM_IMG_PROMETHEUS=localhost:6000/trustchain-prometheus
export TC_SWARM_IMG_CADVISOR=localhost:6000/trustchain-cadvisor
export TC_SWARM_IMG_NODEEXPORTER=localhost:6000/trustchain-node-exporter
export TC_SWARM_IMG_GRAFANA=localhost:6000/trustchain-grafana
export TC_SWARM_IMG_BUSYBOX=localhost:6000/trustchain-busybox
export TC_SWARM_IMG_NETSHOOT=localhost:6000/trustchain-netshoot
export TC_SWARM_IMG_PORTAINERAGENT=localhost:6000/trustchain-portainer-agent
export TC_SWARM_IMG_PORTAINER=localhost:6000/trustchain-portainer
export TC_SWARM_IMG_CCENV=localhost:6000/trustchain-fabric-ccenv
export TC_SWARM_IMG_BASEOS=localhost:6000/trustchain-fabric-baseos
export TC_SWARM_IMG_NODEENV=localhost:6000/trustchain-fabric-nodeenv

# endregion: swarm
# region: gluster

TC_GLUSTER_BRICK=TrustChain
TC_GLUSTER_NODES=("TC_SWARM_MANAGER1" "TC_SWARM_MANAGER2" "TC_SWARM_MANAGER3")
TC_GLUSTER_DISPERSE=3
TC_GLUSTER_REDUNDANCY=1

# endregion: gluster
# region: infra

export TC_COMMON1_STACK=infra
export TC_COMMON1_DOMAIN=${TC_COMMON1_STACK}.${TC_NETWORK_DOMAIN}


export TC_COMMON1_REGISTRY_NAME=registriy
export TC_COMMON1_REGISTRY_FQDN=${TC_COMMON1_REGISTRY_NAME}.${TC_COMMON1_DOMAIN}
export TC_COMMON1_REGISTRY_PORT=6000
export TC_COMMON1_REGISTRY_DATA=${TC_PATH_WORKBENCH}/${TC_COMMON1_STACK}/${TC_COMMON1_REGISTRY_NAME}
export TC_COMMON1_REGISTRY_WORKER=${TC_SWARM_MANAGER1[node]}

export TC_COMMON1_C1_NAME=ca1
export TC_COMMON1_C1_FQDN=${TC_COMMON1_C1_NAME}.${TC_COMMON1_DOMAIN}
export TC_COMMON1_C1_PORT=6001
export TC_COMMON1_C1_ADMIN=${TC_COMMON1_STACK}-${TC_COMMON1_C1_NAME}-admin1
export TC_COMMON1_C1_ADMINPW=$TC_COMMON1_C1_ADMINPW
export TC_COMMON1_C1_WORKER=${TC_SWARM_MANAGER1[node]}
export TC_COMMON1_C1_DATA=${TC_PATH_WORKBENCH}/${TC_COMMON1_STACK}/${TC_COMMON1_C1_NAME}
# export TC_COMMON1_C1_DATA=${TC_PATH_ORGS}/${TC_COMMON1_STACK}/${TC_COMMON1_C1_NAME}
# export TC_COMMON1_C1_SUBHOME=crypto
# export TC_COMMON1_C1_HOME=${TC_COMMON1_C1_DATA}/${TC_COMMON1_C1_SUBHOME}
export TC_COMMON1_C1_HOME=${TC_COMMON1_C1_DATA}
export TC_COMMON1_C1_DEBUG=false
export TC_COMMON1_C1_EXP=3153600000



# endregion: tls ca
# region: orgs

	# region: orderer1

		# region: orderer1 all stack

		export TC_ORDERER1_STACK=orderers
		export TC_ORDERER1_DATA=${TC_PATH_ORGS}/ordererOrganizations/${TC_ORDERER1_STACK}
		export TC_ORDERER1_DOMAIN=${TC_ORDERER1_STACK}.${TC_NETWORK_DOMAIN}
		export TC_ORDERER1_LOGLEVEL=info
		export TC_ORDERER1_WORKER=${TC_SWARM_MANAGER1[node]}

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
		export TC_ORDERER1_C1_WORKER=$TC_ORDERER1_WORKER
		export TC_ORDERER1_C1_DATA=${TC_ORDERER1_DATA}/${TC_ORDERER1_C1_NAME}
		# export TC_ORDERER1_C1_SUBHOME=crypto
		# export TC_ORDERER1_C1_HOME=${TC_ORDERER1_C1_DATA}/${TC_ORDERER1_C1_SUBHOME}	
		export TC_ORDERER1_C1_HOME=${TC_ORDERER1_C1_DATA}
		export TC_ORDERER1_C1_IMAGE=localhost:6000/trustchain-fabric-ca

		export TC_ORDERER1_C1_EXP=3153600000
		export TC_ORDERER1_C1_ADMIN=${TC_ORDERER1_STACK}-${TC_ORDERER1_C1_NAME}-admin1
		export TC_ORDERER1_C1_ADMINPW=$TC_ORDERER1_C1_ADMINPW

		# export TC_ORDERER1_C1_TLS_NAME=$TC_ORDERER1_C1_NAME-$TC_ORDERER1_STACK
		# export TC_ORDERER1_C1_TLS_PW=$TC_ORDERER1_C1_TLS_PW

		# endregion: orderer1 c1
		# region: orderer1 o1

		export TC_ORDERER1_O1_NAME=orderer1
		export TC_ORDERER1_O1_FQDN=${TC_ORDERER1_O1_NAME}.${TC_ORDERER1_DOMAIN}
		export TC_ORDERER1_O1_PORT=7101
		export TC_ORDERER1_O1_ADMINPORT=7102
		export TC_ORDERER1_O1_OPPORT=7103
		export TC_ORDERER1_O1_WORKER=$TC_ORDERER1_WORKER
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
		export TC_ORDERER1_O1_ASSETS_TLSCERT=${TC_ORDERER1_O1_ASSETS_DIR}/${TC_COMMON1_C1_FQDN}/ca-cert.pem	

		# endregion: orderer1 o1
		# region: orderer1 o2

		export TC_ORDERER1_O2_NAME=orderer2
		export TC_ORDERER1_O2_FQDN=${TC_ORDERER1_O2_NAME}.${TC_ORDERER1_DOMAIN}
		export TC_ORDERER1_O2_PORT=7201
		export TC_ORDERER1_O2_ADMINPORT=7202
		export TC_ORDERER1_O2_OPPORT=7203
		export TC_ORDERER1_O2_WORKER=$TC_ORDERER1_WORKER
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
		export TC_ORDERER1_O2_ASSETS_TLSCERT=${TC_ORDERER1_O2_ASSETS_DIR}/${TC_COMMON1_C1_FQDN}/ca-cert.pem	

		# endregion: orderer1 o2
		# region: orderer1 o3

		export TC_ORDERER1_O3_NAME=orderer3
		export TC_ORDERER1_O3_FQDN=${TC_ORDERER1_O3_NAME}.${TC_ORDERER1_DOMAIN}
		export TC_ORDERER1_O3_PORT=7301
		export TC_ORDERER1_O3_ADMINPORT=7302
		export TC_ORDERER1_O3_OPPORT=7303
		export TC_ORDERER1_O3_WORKER=$TC_ORDERER1_WORKER
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
		export TC_ORDERER1_O3_ASSETS_TLSCERT=${TC_ORDERER1_O3_ASSETS_DIR}/${TC_COMMON1_C1_FQDN}/ca-cert.pem

		# endregion: orderer1 o3

	# endregion: orderer1
	# region: org1

		# region: org1 all stack

		export TC_ORG1_STACK=backbone
		export TC_ORG1_DATA=${TC_PATH_ORGS}/peerOrganizations/${TC_ORG1_STACK}
		export TC_ORG1_DOMAIN=${TC_ORG1_STACK}.${TC_NETWORK_DOMAIN}
		export TC_ORG1_LOGLEVEL=info
		export TC_ORG1_WORKER=${TC_SWARM_MANAGER1[node]}

		export TC_ORG1_ADMIN=${TC_ORG1_STACK}-admin1
		export TC_ORG1_ADMINPW=$TC_ORG1_ADMINPW
		export TC_ORG1_ADMINATRS="hf.Registrar.Roles=client,hf.Registrar.Attributes=*,hf.Revoker=true,hf.GenCRL=true,admin=true:ecert,abac.init=true:ecert"
		export TC_ORG1_ADMINHOME=${TC_ORG1_DATA}/users/${TC_ORG1_ADMIN}
		export TC_ORG1_ADMINMSP=${TC_ORG1_ADMINHOME}/msp
		# export TC_ORG1_USER=${TC_ORG1_STACK}-user1
		# export TC_ORG1_USERPW=$TC_ORG1_USERPW
		# export TC_ORG1_USERMSP=${TC_ORG1_DATA}/users/${TC_ORG1_USER}/msp
		export TC_ORG1_CLIENT=${TC_ORG1_STACK}-client1
		export TC_ORG1_CLIENTPW=$TC_ORG1_CLIENTPW
		export TC_ORG1_CLIENTHOME=${TC_ORG1_DATA}/users/${TC_ORG1_CLIENT}
		export TC_ORG1_CLIENTMSP=${TC_ORG1_CLIENTHOME}/msp

		# endregion: org1 all stack
		# region: org1 c1

		export TC_ORG1_C1_NAME=ca1
		export TC_ORG1_C1_FQDN=${TC_ORG1_C1_NAME}.${TC_ORG1_DOMAIN}
		export TC_ORG1_C1_PORT=8001
		export TC_ORG1_C1_DEBUG=false
		export TC_ORG1_C1_LOGLEVEL=$TC_ORG1_LOGLEVEL
		export TC_ORG1_C1_WORKER=$TC_ORG1_WORKER
		export TC_ORG1_C1_DATA=${TC_ORG1_DATA}/${TC_ORG1_C1_NAME}
		# export TC_ORG1_C1_SUBHOME=crypto
		# export TC_ORG1_C1_HOME=${TC_ORG1_C1_DATA}/${TC_ORG1_C1_SUBHOME}
		export TC_ORG1_C1_HOME=${TC_ORG1_C1_DATA}
		export TC_ORG1_C1_EXP=3153600000

		export TC_ORG1_C1_ADMIN=${TC_ORG1_STACK}-${TC_ORG1_C1_NAME}-admin1
		export TC_ORG1_C1_ADMINPW=$TC_ORG1_C1_ADMINPW

		# endregion: org1 c1
		# region: org1 state dbs

		export TC_ORG1_D1_NAME=db1
		export TC_ORG1_D1_USER=${TC_ORG1_D1_NAME}-${TC_ORG1_STACK}
		export TC_ORG1_D1_USERPW=$TC_ORG1_D1_USERPW
		export TC_ORG1_D1_WORKER=$TC_ORG1_WORKER
		export TC_ORG1_D1_FQDN=${TC_ORG1_D1_NAME}.${TC_ORG1_DOMAIN}
		export TC_ORG1_D1_PORT=5081
		export TC_ORG1_D1_DATA=${TC_ORG1_DATA}/dbs/${TC_ORG1_D1_NAME}

		export TC_ORG1_D2_NAME=db2
		export TC_ORG1_D2_USER=${TC_ORG1_D2_NAME}-${TC_ORG1_STACK}
		export TC_ORG1_D2_USERPW=$TC_ORG1_D2_USERPW
		export TC_ORG1_D2_WORKER=$TC_ORG1_WORKER
		export TC_ORG1_D2_FQDN=${TC_ORG1_D2_NAME}.${TC_ORG1_DOMAIN}
		export TC_ORG1_D2_PORT=5082
		export TC_ORG1_D2_DATA=${TC_ORG1_DATA}/dbs/${TC_ORG1_D2_NAME}

		export TC_ORG1_D3_NAME=db3
		export TC_ORG1_D3_USER=${TC_ORG1_D3_NAME}-${TC_ORG1_STACK}
		export TC_ORG1_D3_USERPW=$TC_ORG1_D3_USERPW
		export TC_ORG1_D3_WORKER=$TC_ORG1_WORKER
		export TC_ORG1_D3_FQDN=${TC_ORG1_D3_NAME}.${TC_ORG1_DOMAIN}
		export TC_ORG1_D3_PORT=5083
		export TC_ORG1_D3_DATA=${TC_ORG1_DATA}/dbs/${TC_ORG1_D3_NAME}

		# endregion: org1 state dbs
		# region: org1 peers

		# region: org1 p1
		
		export TC_ORG1_P1_NAME=peer1
		export TC_ORG1_P1_FQDN=${TC_ORG1_P1_NAME}.${TC_ORG1_DOMAIN}
		export TC_ORG1_P1_PORT=8101
		export TC_ORG1_P1_CHPORT=8102
		export TC_ORG1_P1_OPPORT=8103
		export TC_ORG1_P1_WORKER=$TC_ORG1_D1_WORKER
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
		# export TC_ORG1_P1_ASSETS_CHAINSUBDIR=chaincode
		# export TC_ORG1_P1_ASSETS_CHAINCODE=${TC_ORG1_P1_ASSETS_DIR}/${TC_ORG1_P1_ASSETS_CHAINSUBDIR}
		export TC_ORG1_P1_ASSETS_CACERT=${TC_ORG1_P1_ASSETS_DIR}/${TC_ORG1_C1_FQDN}/ca-cert.pem
		export TC_ORG1_P1_ASSETS_TLSCERT=${TC_ORG1_P1_ASSETS_DIR}/${TC_COMMON1_C1_FQDN}/ca-cert.pem

		# endregion: org1 p1
		# region: org1 p2
		
		export TC_ORG1_P2_NAME=peer2
		export TC_ORG1_P2_FQDN=${TC_ORG1_P2_NAME}.${TC_ORG1_DOMAIN}
		export TC_ORG1_P2_PORT=8201
		export TC_ORG1_P2_CHPORT=8202
		export TC_ORG1_P2_OPPORT=8203
		export TC_ORG1_P2_WORKER=$TC_ORG1_D2_WORKER
		export TC_ORG1_P2_LOGLEVEL=$TC_ORG1_LOGLEVEL

		export TC_ORG1_P2_TLS_NAME=$TC_ORG1_STACK-$TC_ORG1_P2_NAME
		export TC_ORG1_P2_TLS_PW=$TC_ORG1_P2_TLS_PW
		export TC_ORG1_P2_CA_NAME=${TC_ORG1_P2_NAME}-${TC_ORG1_STACK}
		export TC_ORG1_P2_CA_PW=$TC_ORG1_P2_CA_PW

		export TC_ORG1_P2_DATA=${TC_ORG1_DATA}/peers/${TC_ORG1_P2_NAME}
		export TC_ORG1_P2_MSP=${TC_ORG1_P2_DATA}/msp
		export TC_ORG1_P2_TLSMSP=${TC_ORG1_P2_DATA}/tls-msp
		export TC_ORG1_P2_ASSETS_CACERT=${TC_ORG1_P2_DATA}/assets/${TC_ORG1_C1_FQDN}/ca-cert.pem
		export TC_ORG1_P2_ASSETS_TLSCERT=${TC_ORG1_P2_DATA}/assets/${TC_COMMON1_C1_FQDN}/ca-cert.pem

		# endregion: org1 p2
		# region: org1 p3
		
		export TC_ORG1_P3_NAME=peer3
		export TC_ORG1_P3_FQDN=${TC_ORG1_P3_NAME}.${TC_ORG1_DOMAIN}
		export TC_ORG1_P3_PORT=8301
		export TC_ORG1_P3_CHPORT=8302
		export TC_ORG1_P3_OPPORT=8303
		export TC_ORG1_P3_WORKER=$TC_ORG1_D3_WORKER
		export TC_ORG1_P3_LOGLEVEL=$TC_ORG1_LOGLEVEL

		export TC_ORG1_P3_TLS_NAME=$TC_ORG1_STACK-$TC_ORG1_P3_NAME
		export TC_ORG1_P3_TLS_PW=$TC_ORG1_P3_TLS_PW
		export TC_ORG1_P3_CA_NAME=${TC_ORG1_P3_NAME}-${TC_ORG1_STACK}
		export TC_ORG1_P3_CA_PW=$TC_ORG1_P3_CA_PW

		export TC_ORG1_P3_DATA=${TC_ORG1_DATA}/peers/${TC_ORG1_P3_NAME}
		export TC_ORG1_P3_MSP=${TC_ORG1_P3_DATA}/msp
		export TC_ORG1_P3_TLSMSP=${TC_ORG1_P3_DATA}/tls-msp
		export TC_ORG1_P3_ASSETS_CACERT=${TC_ORG1_P3_DATA}/assets/${TC_ORG1_C1_FQDN}/ca-cert.pem
		export TC_ORG1_P3_ASSETS_TLSCERT=${TC_ORG1_P3_DATA}/assets/${TC_COMMON1_C1_FQDN}/ca-cert.pem

		# endregion: org1 p3
		
		# endregion: org1 peers
		# region: org1 g1

		export TC_ORG1_G1_NAME=gw1
		export TC_ORG1_G1_FQDN=${TC_ORG1_G1_NAME}.${TC_ORG1_DOMAIN}
		export TC_ORG1_G1_WORKER=$TC_ORG1_WORKER
		export TC_ORG1_G1_PORT1=5088
		export TC_ORG1_G1_PORT2=5089
		export TC_ORG1_G1_DATA=${TC_ORG1_DATA}/${TC_ORG1_G1_NAME}

		export TC_ORG1_G1_TLS_NAME=$TC_ORG1_STACK-$TC_ORG1_G1_NAME
		export TC_ORG1_G1_TLS_PW=$TC_ORG1_G1_TLS_PW
		export TC_ORG1_G1_CA_NAME=${TC_ORG1_G1_NAME}-${TC_ORG1_STACK}
		export TC_ORG1_G1_CA_PW=$TC_ORG1_G1_CA_PW

		export TC_ORG1_G1_MSP=${TC_ORG1_G1_DATA}/msp
		export TC_ORG1_G1_TLSMSP=${TC_ORG1_G1_DATA}/tls-msp
		export TC_ORG1_G1_ASSETS_DIR=${TC_ORG1_G1_DATA}/assets
		export TC_ORG1_G1_ASSETS_STATIC=${TC_ORG1_G1_ASSETS_DIR}/docs
		export TC_ORG1_G1_ASSETS_CACERT=${TC_ORG1_G1_ASSETS_DIR}/${TC_ORG1_C1_FQDN}/ca-cert.pem
		export TC_ORG1_G1_ASSETS_TLSCERT=${TC_ORG1_G1_ASSETS_DIR}/${TC_COMMON1_C1_FQDN}/ca-cert.pem
		# export TC_ORG1_G1_ASSETS_CHAINSUBDIR=chaincode
		# export TC_ORG1_G1_ASSETS_CHAINCODE=${TC_ORG1_G1_ASSETS_DIR}/${TC_ORG1_G1_ASSETS_CHAINSUBDIR}

		# endregion: org1 g1
		# region: org1 cli
		
		export TC_ORG1_CLI1_NAME=cli1
		export TC_ORG1_CLI1_FQDN=${TC_ORG1_CLI1_NAME}.${TC_ORG1_DOMAIN}
		export TC_ORG1_CLI1_PEER_ADDRESS=${TC_ORG1_P1_FQDN}:${TC_ORG1_P1_PORT}
		export TC_ORG1_CLI1_PEER_ID=$TC_ORG1_P1_CA_NAME
		export TC_ORG1_CLI1_PORT=$TC_ORG1_P1_PORT
		export TC_ORG1_CLI1_CHPORT=$TC_ORG1_P1_CHPORT
		export TC_ORG1_CLI1_OPPORT=$TC_ORG1_P1_OPPORT
		export TC_ORG1_CLI1_WORKER=$TC_ORG1_WORKER
		export TC_ORG1_CLI1_LOGLEVEL=$TC_ORG1_LOGLEVEL

		export TC_ORG1_CLI1_DATA=$TC_ORG1_P1_DATA
		export TC_ORG1_CLI1_MSP=$TC_ORG1_P1_MSP
		export TC_ORG1_CLI1_TLSMSP=$TC_ORG1_P1_TLSMSP
		export TC_ORG1_CLI1_ASSETS_CACERT=$TC_ORG1_P1_ASSETS_CACERT
		export TC_ORG1_CLI1_ASSETS_TLSCERT=$TC_ORG1_P1_ASSETS_TLSCERT
		# export TC_ORG1_CLI1_ASSETS_CHAINCODE=$TC_ORG1_P1_ASSETS_CHAINCODE

		# endregion: org1 cli

	# endregion: org1
	# region: org2

		# region: org2 all stack

		export TC_ORG2_STACK=supernodes
		export TC_ORG2_DATA=${TC_PATH_ORGS}/peerOrganizations/${TC_ORG2_STACK}
		export TC_ORG2_DOMAIN=${TC_ORG2_STACK}.${TC_NETWORK_DOMAIN}
		export TC_ORG2_LOGLEVEL=info
		export TC_ORG2_WORKER=${TC_SWARM_MANAGER1[node]}

		export TC_ORG2_ADMIN=${TC_ORG2_STACK}-admin1
		export TC_ORG2_ADMINPW=$TC_ORG2_ADMINPW
		export TC_ORG2_ADMINATRS="hf.Registrar.Roles=client,hf.Registrar.Attributes=*,hf.Revoker=true,hf.GenCRL=true,admin=true:ecert,abac.init=true:ecert"
		export TC_ORG2_ADMINHOME=${TC_ORG2_DATA}/users/${TC_ORG2_ADMIN}
		export TC_ORG2_ADMINMSP=${TC_ORG2_ADMINHOME}/msp
		export TC_ORG2_CLIENT=${TC_ORG2_STACK}-client1
		export TC_ORG2_CLIENTPW=$TC_ORG2_CLIENTPW
		export TC_ORG2_CLIENTMSP=${TC_ORG2_DATA}/users/${TC_ORG2_CLIENT}/msp

		# endregion: org2 all stack
		# region: org2 c1

		export TC_ORG2_C1_NAME=ca1
		export TC_ORG2_C1_FQDN=${TC_ORG2_C1_NAME}.${TC_ORG2_DOMAIN}
		export TC_ORG2_C1_PORT=9001
		export TC_ORG2_C1_DEBUG=false
		export TC_ORG2_C1_LOGLEVEL=$TC_ORG2_LOGLEVEL
		export TC_ORG2_C1_WORKER=$TC_ORG2_WORKER
		export TC_ORG2_C1_DATA=${TC_ORG2_DATA}/${TC_ORG2_C1_NAME}
		# export TC_ORG2_C1_SUBHOME=crypto
		# export TC_ORG2_C1_HOME=${TC_ORG2_C1_DATA}/${TC_ORG2_C1_SUBHOME}
		export TC_ORG2_C1_HOME=${TC_ORG2_C1_DATA}
		export TC_ORG2_C1_EXP=3153600000

		export TC_ORG2_C1_ADMIN=${TC_ORG2_STACK}-${TC_ORG2_C1_NAME}-admin1
		export TC_ORG2_C1_ADMINPW=$TC_ORG2_C1_ADMINPW

		# endregion: org2 c1
		# region: org2 state dbs

		export TC_ORG2_D1_NAME=db1
		export TC_ORG2_D1_USER=${TC_ORG2_D1_NAME}-${TC_ORG2_STACK}
		export TC_ORG2_D1_USERPW=$TC_ORG2_D1_USERPW
		export TC_ORG2_D1_WORKER=$TC_ORG2_WORKER
		export TC_ORG2_D1_FQDN=${TC_ORG2_D1_NAME}.${TC_ORG2_DOMAIN}
		export TC_ORG2_D1_PORT=5091
		export TC_ORG2_D1_DATA=${TC_ORG2_DATA}/dbs/${TC_ORG2_D1_NAME}

		export TC_ORG2_D2_NAME=db2
		export TC_ORG2_D2_USER=${TC_ORG2_D2_NAME}-${TC_ORG2_STACK}
		export TC_ORG2_D2_USERPW=$TC_ORG2_D2_USERPW
		export TC_ORG2_D2_WORKER=$TC_ORG2_WORKER
		export TC_ORG2_D2_FQDN=${TC_ORG2_D2_NAME}.${TC_ORG2_DOMAIN}
		export TC_ORG2_D2_PORT=5092
		export TC_ORG2_D2_DATA=${TC_ORG2_DATA}/dbs/${TC_ORG2_D2_NAME}

		export TC_ORG2_D3_NAME=db3
		export TC_ORG2_D3_USER=${TC_ORG2_D3_NAME}-${TC_ORG2_STACK}
		export TC_ORG2_D3_USERPW=$TC_ORG2_D3_USERPW
		export TC_ORG2_D3_WORKER=$TC_ORG2_WORKER
		export TC_ORG2_D3_FQDN=${TC_ORG2_D3_NAME}.${TC_ORG2_DOMAIN}
		export TC_ORG2_D3_PORT=5093
		export TC_ORG2_D3_DATA=${TC_ORG2_DATA}/dbs/${TC_ORG2_D3_NAME}

		# endregion: org2 state dbs
		# region: org2 peers

		# region: org2 p1
		
		export TC_ORG2_P1_NAME=peer1
		export TC_ORG2_P1_FQDN=${TC_ORG2_P1_NAME}.${TC_ORG2_DOMAIN}
		export TC_ORG2_P1_PORT=9101
		export TC_ORG2_P1_CHPORT=9102
		export TC_ORG2_P1_OPPORT=9103
		export TC_ORG2_P1_WORKER=$TC_ORG2_D1_WORKER
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
		# export TC_ORG2_P1_ASSETS_CHAINSUBDIR=chaincode
		# export TC_ORG2_P1_ASSETS_CHAINCODE=${TC_ORG2_P1_ASSETS_DIR}/${TC_ORG2_P1_ASSETS_CHAINSUBDIR}
		export TC_ORG2_P1_ASSETS_CACERT=${TC_ORG2_P1_ASSETS_DIR}/${TC_ORG2_C1_FQDN}/ca-cert.pem
		export TC_ORG2_P1_ASSETS_TLSCERT=${TC_ORG2_P1_ASSETS_DIR}/${TC_COMMON1_C1_FQDN}/ca-cert.pem

		# endregion: org2 p1
		# region: org2 p2
		
		export TC_ORG2_P2_NAME=peer2
		export TC_ORG2_P2_FQDN=${TC_ORG2_P2_NAME}.${TC_ORG2_DOMAIN}
		export TC_ORG2_P2_PORT=9201
		export TC_ORG2_P2_CHPORT=9202
		export TC_ORG2_P2_OPPORT=9203
		export TC_ORG2_P2_WORKER=$TC_ORG2_D2_WORKER
		export TC_ORG2_P2_LOGLEVEL=$TC_ORG2_LOGLEVEL

		export TC_ORG2_P2_TLS_NAME=$TC_ORG2_STACK-$TC_ORG2_P2_NAME
		export TC_ORG2_P2_TLS_PW=$TC_ORG2_P2_TLS_PW
		export TC_ORG2_P2_CA_NAME=${TC_ORG2_P2_NAME}-${TC_ORG2_STACK}
		export TC_ORG2_P2_CA_PW=$TC_ORG2_P2_CA_PW

		export TC_ORG2_P2_DATA=${TC_ORG2_DATA}/peers/${TC_ORG2_P2_NAME}
		export TC_ORG2_P2_MSP=${TC_ORG2_P2_DATA}/msp
		export TC_ORG2_P2_TLSMSP=${TC_ORG2_P2_DATA}/tls-msp
		export TC_ORG2_P2_ASSETS_CACERT=${TC_ORG2_P2_DATA}/assets/${TC_ORG2_C1_FQDN}/ca-cert.pem
		export TC_ORG2_P2_ASSETS_TLSCERT=${TC_ORG2_P2_DATA}/assets/${TC_COMMON1_C1_FQDN}/ca-cert.pem

		# endregion: org2 p2
		# region: org2 p3
		
		export TC_ORG2_P3_NAME=peer3
		export TC_ORG2_P3_FQDN=${TC_ORG2_P3_NAME}.${TC_ORG2_DOMAIN}
		export TC_ORG2_P3_PORT=9301
		export TC_ORG2_P3_CHPORT=9302
		export TC_ORG2_P3_OPPORT=9303
		export TC_ORG2_P3_WORKER=$TC_ORG2_D3_WORKER
		export TC_ORG2_P3_LOGLEVEL=$TC_ORG2_LOGLEVEL

		export TC_ORG2_P3_TLS_NAME=$TC_ORG2_STACK-$TC_ORG2_P3_NAME
		export TC_ORG2_P3_TLS_PW=$TC_ORG2_P3_TLS_PW
		export TC_ORG2_P3_CA_NAME=${TC_ORG2_P3_NAME}-${TC_ORG2_STACK}
		export TC_ORG2_P3_CA_PW=$TC_ORG2_P3_CA_PW

		export TC_ORG2_P3_DATA=${TC_ORG2_DATA}/peers/${TC_ORG2_P3_NAME}
		export TC_ORG2_P3_MSP=${TC_ORG2_P3_DATA}/msp
		export TC_ORG2_P3_TLSMSP=${TC_ORG2_P3_DATA}/tls-msp
		export TC_ORG2_P3_ASSETS_CACERT=${TC_ORG2_P3_DATA}/assets/${TC_ORG2_C1_FQDN}/ca-cert.pem
		export TC_ORG2_P3_ASSETS_TLSCERT=${TC_ORG2_P3_DATA}/assets/${TC_COMMON1_C1_FQDN}/ca-cert.pem

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
		export TC_ORG2_CLI1_WORKER=$TC_ORG2_WORKER
		export TC_ORG2_CLI1_LOGLEVEL=$TC_ORG2_LOGLEVEL

		export TC_ORG2_CLI1_DATA=$TC_ORG2_P1_DATA
		export TC_ORG2_CLI1_MSP=$TC_ORG2_P1_MSP
		export TC_ORG2_CLI1_TLSMSP=$TC_ORG2_P1_TLSMSP
		export TC_ORG2_CLI1_ASSETS_CACERT=$TC_ORG2_P1_ASSETS_CACERT
		export TC_ORG2_CLI1_ASSETS_TLSCERT=$TC_ORG2_P1_ASSETS_TLSCERT
		# export TC_ORG2_CLI1_ASSETS_CHAINCODE=$TC_ORG2_P1_ASSETS_CHAINCODE

	# endregion: org2 cli

	# endregion: org2
	# region: org3

		# region: org3 all stack

		export TC_ORG3_STACK=masternodes
		export TC_ORG3_DATA=${TC_PATH_ORGS}/peerOrganizations/${TC_ORG3_STACK}
		export TC_ORG3_DOMAIN=${TC_ORG3_STACK}.${TC_NETWORK_DOMAIN}
		export TC_ORG3_LOGLEVEL=info
		export TC_ORG3_WORKER=${TC_SWARM_MANAGER1[node]}

		export TC_ORG3_ADMIN=${TC_ORG3_STACK}-admin1
		export TC_ORG3_ADMINPW=$TC_ORG3_ADMINPW
		export TC_ORG3_ADMINATRS="hf.Registrar.Roles=client,hf.Registrar.Attributes=*,hf.Revoker=true,hf.GenCRL=true,admin=true:ecert,abac.init=true:ecert"
		export TC_ORG3_ADMINHOME=${TC_ORG3_DATA}/users/${TC_ORG3_ADMIN}
		export TC_ORG3_ADMINMSP=${TC_ORG3_ADMINHOME}/msp
		export TC_ORG3_CLIENT=${TC_ORG3_STACK}-client1
		export TC_ORG3_CLIENTPW=$TC_ORG3_CLIENTPW
		export TC_ORG3_CLIENTMSP=${TC_ORG3_DATA}/users/${TC_ORG3_CLIENT}/msp

		# endregion: org3 all stack
		# region: org3 c1

		export TC_ORG3_C1_NAME=ca1
		export TC_ORG3_C1_FQDN=${TC_ORG3_C1_NAME}.${TC_ORG3_DOMAIN}
		export TC_ORG3_C1_PORT=10001
		export TC_ORG3_C1_DEBUG=false
		export TC_ORG3_C1_LOGLEVEL=$TC_ORG3_LOGLEVEL
		export TC_ORG3_C1_WORKER=$TC_ORG3_WORKER
		export TC_ORG3_C1_DATA=${TC_ORG3_DATA}/${TC_ORG3_C1_NAME}
		# export TC_ORG3_C1_SUBHOME=crypto
		# export TC_ORG3_C1_HOME=${TC_ORG3_C1_DATA}/${TC_ORG3_C1_SUBHOME}
		export TC_ORG3_C1_HOME=${TC_ORG3_C1_DATA}
		export TC_ORG3_C1_EXP=3153600000

		export TC_ORG3_C1_ADMIN=${TC_ORG3_STACK}-${TC_ORG3_C1_NAME}-admin1
		export TC_ORG3_C1_ADMINPW=$TC_ORG3_C1_ADMINPW

		# endregion: org3 c1
		# region: org3 state dbs

		export TC_ORG3_D1_NAME=db1
		export TC_ORG3_D1_USER=${TC_ORG3_D1_NAME}-${TC_ORG3_STACK}
		export TC_ORG3_D1_USERPW=$TC_ORG3_D1_USERPW
		export TC_ORG3_D1_WORKER=$TC_ORG3_WORKER
		export TC_ORG3_D1_FQDN=${TC_ORG3_D1_NAME}.${TC_ORG3_DOMAIN}
		export TC_ORG3_D1_PORT=5101
		export TC_ORG3_D1_DATA=${TC_ORG3_DATA}/dbs/${TC_ORG3_D1_NAME}

		export TC_ORG3_D2_NAME=db2
		export TC_ORG3_D2_USER=${TC_ORG3_D2_NAME}-${TC_ORG3_STACK}
		export TC_ORG3_D2_USERPW=$TC_ORG3_D2_USERPW
		export TC_ORG3_D2_WORKER=$TC_ORG3_WORKER
		export TC_ORG3_D2_FQDN=${TC_ORG3_D2_NAME}.${TC_ORG3_DOMAIN}
		export TC_ORG3_D2_PORT=5102
		export TC_ORG3_D2_DATA=${TC_ORG3_DATA}/dbs/${TC_ORG3_D2_NAME}

		export TC_ORG3_D3_NAME=db3
		export TC_ORG3_D3_USER=${TC_ORG3_D3_NAME}-${TC_ORG3_STACK}
		export TC_ORG3_D3_USERPW=$TC_ORG3_D3_USERPW
		export TC_ORG3_D3_WORKER=$TC_ORG3_WORKER
		export TC_ORG3_D3_FQDN=${TC_ORG3_D3_NAME}.${TC_ORG3_DOMAIN}
		export TC_ORG3_D3_PORT=5103
		export TC_ORG3_D3_DATA=${TC_ORG3_DATA}/dbs/${TC_ORG3_D3_NAME}

		# endregion: org3 state dbs
		# region: org3 peers

		# region: org3 p1
		
		export TC_ORG3_P1_NAME=peer1
		export TC_ORG3_P1_FQDN=${TC_ORG3_P1_NAME}.${TC_ORG3_DOMAIN}
		export TC_ORG3_P1_PORT=10101
		export TC_ORG3_P1_CHPORT=10102
		export TC_ORG3_P1_OPPORT=10103
		export TC_ORG3_P1_WORKER=$TC_ORG3_D1_WORKER
		export TC_ORG3_P1_LOGLEVEL=$TC_ORG3_LOGLEVEL

		export TC_ORG3_P1_TLS_NAME=$TC_ORG3_STACK-$TC_ORG3_P1_NAME
		export TC_ORG3_P1_TLS_PW=$TC_ORG3_P1_TLS_PW
		export TC_ORG3_P1_CA_NAME=${TC_ORG3_P1_NAME}-${TC_ORG3_STACK}
		export TC_ORG3_P1_CA_PW=$TC_ORG3_P1_CA_PW

		export TC_ORG3_P1_DATA=${TC_ORG3_DATA}/peers/${TC_ORG3_P1_NAME}
		export TC_ORG3_P1_MSP=${TC_ORG3_P1_DATA}/msp
		export TC_ORG3_P1_TLSMSP=${TC_ORG3_P1_DATA}/tls-msp
		export TC_ORG3_P1_ASSETS_SUBDIR=assets
		export TC_ORG3_P1_ASSETS_DIR=${TC_ORG3_P1_DATA}/${TC_ORG3_P1_ASSETS_SUBDIR}
		# export TC_ORG3_P1_ASSETS_CHAINSUBDIR=chaincode
		# export TC_ORG3_P1_ASSETS_CHAINCODE=${TC_ORG3_P1_ASSETS_DIR}/${TC_ORG3_P1_ASSETS_CHAINSUBDIR}
		export TC_ORG3_P1_ASSETS_CACERT=${TC_ORG3_P1_ASSETS_DIR}/${TC_ORG3_C1_FQDN}/ca-cert.pem
		export TC_ORG3_P1_ASSETS_TLSCERT=${TC_ORG3_P1_ASSETS_DIR}/${TC_COMMON1_C1_FQDN}/ca-cert.pem

		# endregion: org3 p1
		# region: org3 p2
		
		export TC_ORG3_P2_NAME=peer2
		export TC_ORG3_P2_FQDN=${TC_ORG3_P2_NAME}.${TC_ORG3_DOMAIN}
		export TC_ORG3_P2_PORT=10201
		export TC_ORG3_P2_CHPORT=10202
		export TC_ORG3_P2_OPPORT=10203
		export TC_ORG3_P2_WORKER=$TC_ORG3_D2_WORKER
		export TC_ORG3_P2_LOGLEVEL=$TC_ORG3_LOGLEVEL

		export TC_ORG3_P2_TLS_NAME=$TC_ORG3_STACK-$TC_ORG3_P2_NAME
		export TC_ORG3_P2_TLS_PW=$TC_ORG3_P2_TLS_PW
		export TC_ORG3_P2_CA_NAME=${TC_ORG3_P2_NAME}-${TC_ORG3_STACK}
		export TC_ORG3_P2_CA_PW=$TC_ORG3_P2_CA_PW

		export TC_ORG3_P2_DATA=${TC_ORG3_DATA}/peers/${TC_ORG3_P2_NAME}
		export TC_ORG3_P2_MSP=${TC_ORG3_P2_DATA}/msp
		export TC_ORG3_P2_TLSMSP=${TC_ORG3_P2_DATA}/tls-msp
		export TC_ORG3_P2_ASSETS_CACERT=${TC_ORG3_P2_DATA}/assets/${TC_ORG3_C1_FQDN}/ca-cert.pem
		export TC_ORG3_P2_ASSETS_TLSCERT=${TC_ORG3_P2_DATA}/assets/${TC_COMMON1_C1_FQDN}/ca-cert.pem

		# endregion: org3 p2
		# region: org3 p3
		
		export TC_ORG3_P3_NAME=peer3
		export TC_ORG3_P3_FQDN=${TC_ORG3_P3_NAME}.${TC_ORG3_DOMAIN}
		export TC_ORG3_P3_PORT=10301
		export TC_ORG3_P3_CHPORT=10302
		export TC_ORG3_P3_OPPORT=10303
		export TC_ORG3_P3_WORKER=$TC_ORG3_D3_WORKER
		export TC_ORG3_P3_LOGLEVEL=$TC_ORG3_LOGLEVEL

		export TC_ORG3_P3_TLS_NAME=$TC_ORG3_STACK-$TC_ORG3_P3_NAME
		export TC_ORG3_P3_TLS_PW=$TC_ORG3_P3_TLS_PW
		export TC_ORG3_P3_CA_NAME=${TC_ORG3_P3_NAME}-${TC_ORG3_STACK}
		export TC_ORG3_P3_CA_PW=$TC_ORG3_P3_CA_PW

		export TC_ORG3_P3_DATA=${TC_ORG3_DATA}/peers/${TC_ORG3_P3_NAME}
		export TC_ORG3_P3_MSP=${TC_ORG3_P3_DATA}/msp
		export TC_ORG3_P3_TLSMSP=${TC_ORG3_P3_DATA}/tls-msp
		export TC_ORG3_P3_ASSETS_CACERT=${TC_ORG3_P3_DATA}/assets/${TC_ORG3_C1_FQDN}/ca-cert.pem
		export TC_ORG3_P3_ASSETS_TLSCERT=${TC_ORG3_P3_DATA}/assets/${TC_COMMON1_C1_FQDN}/ca-cert.pem

		# endregion: org3 p3

		# endregion: org3 peers
		# region: org3 cli

		export TC_ORG3_CLI1_NAME=cli1
		export TC_ORG3_CLI1_FQDN=${TC_ORG3_CLI1_NAME}.${TC_ORG3_DOMAIN}
		export TC_ORG3_CLI1_PEER_FQDN=$TC_ORG3_P1_FQDN
		export TC_ORG3_CLI1_PEER_NAME=$TC_ORG3_P1_NAME
		export TC_ORG3_CLI1_PORT=$TC_ORG3_P1_PORT
		export TC_ORG3_CLI1_CHPORT=$TC_ORG3_P1_CHPORT
		export TC_ORG3_CLI1_OPPORT=$TC_ORG3_P1_OPPORT
		export TC_ORG3_CLI1_WORKER=$TC_ORG3_WORKER
		export TC_ORG3_CLI1_LOGLEVEL=$TC_ORG3_LOGLEVEL

		export TC_ORG3_CLI1_DATA=$TC_ORG3_P1_DATA
		export TC_ORG3_CLI1_MSP=$TC_ORG3_P1_MSP
		export TC_ORG3_CLI1_TLSMSP=$TC_ORG3_P1_TLSMSP
		export TC_ORG3_CLI1_ASSETS_CACERT=$TC_ORG3_P1_ASSETS_CACERT
		export TC_ORG3_CLI1_ASSETS_TLSCERT=$TC_ORG3_P1_ASSETS_TLSCERT
		# export TC_ORG3_CLI1_ASSETS_CHAINCODE=$TC_ORG3_P1_ASSETS_CHAINCODE

	# endregion: org3 cli

	# endregion: org3

# endregion: orgs
# region: mgmt and metrics

	# region: COMMON2

	export TC_COMMON2_STACK=metrics
	export TC_COMMOM2_DATA=${TC_PATH_WORKBENCH}/${TC_COMMON2_STACK}
	export TC_COMMON2_UID=$( id -u )
	export TC_COMMON2_GID=$( id -g )
	export TC_COMMON2_WORKER=${TC_SWARM_MANAGER1[node]}
	
	export TC_COMMON2_S1_NAME=visualizer
	export TC_COMMON2_S1_PORT=5021
	export TC_COMMON2_S2_NAME=logspout
	export TC_COMMON2_S2_PORT=5022
	export TC_COMMON2_S3_NAME=prometheus
	export TC_COMMON2_S3_DATA=${TC_COMMOM2_DATA}/${TC_COMMON2_S3_NAME}
	export TC_COMMON2_S3_PORT=5023
	export TC_COMMON2_S3_WORKER=$TC_COMMON2_WORKER
	export TC_COMMON2_S3_PW=$TC_COMMON2_S3_PW
	export TC_COMMON2_S4_NAME=cadvisor
	export TC_COMMON2_S4_PORT=5024
	export TC_COMMON2_S4_WORKER=$TC_COMMON2_WORKER
	export TC_COMMON2_S5_NAME=node-exporter
	export TC_COMMON2_S5_PORT=5025
	export TC_COMMON2_S5_WORKER=$TC_COMMON2_WORKER
	export TC_COMMON2_S6_NAME=grafana
	export TC_COMMON2_S6_PORT=5026
	export TC_COMMON2_S6_WORKER=$TC_COMMON2_WORKER
	export TC_COMMON2_S6_DATA=${TC_COMMOM2_DATA}/${TC_COMMON2_S6_NAME}
	export TC_COMMON2_S6_PW=$TC_COMMON2_S6_PW
	export TC_COMMON2_S6_INT=15

	# endregion: COMMON2
	# region: COMMON3

	export TC_COMMON3_STACK=mgmt
	export TC_COMMOM3_DATA=${TC_PATH_WORKBENCH}/${TC_COMMON3_STACK}
	export TC_COMMON3_WORKER=${TC_SWARM_MANAGER1[node]}

	export TC_COMMON3_S1_NAME=busybox
	export TC_COMMON3_S1_WORKER=$TC_COMMON3_WORKER
	export TC_COMMON3_S2_NAME=netshoot
	export TC_COMMON3_S2_WORKER=$TC_COMMON3_WORKER
	export TC_COMMON3_S3_NAME=portainer-agent
	export TC_COMMON3_S4_NAME=portainer
	export TC_COMMON3_S4_PORT=5034
	export TC_COMMON3_S4_PW=$TC_COMMON3_S4_PW
	export TC_COMMON3_S4_DATA=${TC_COMMOM3_DATA}/${TC_COMMON3_S4_NAME}

	# endregion: COMMON3

# endregion: mgmt and metrics
# region: raw api

export TC_RAWAPI_KEY=$TC_RAWAPI_KEY
export TC_RAWAPI_HTTP_ENABLED=true
export TC_RAWAPI_HTTP_NAME="TrustChain backend"
export TC_RAWAPI_HTTP_PORT=$TC_ORG1_G1_PORT1
export TC_RAWAPI_HTTP_STATIC_ENABLED=true
export TC_RAWAPI_HTTP_STATIC_ROOT=$TC_ORG1_G1_ASSETS_STATIC
export TC_RAWAPI_HTTP_STATIC_INDEX="index.html"
export TC_RAWAPI_HTTP_STATIC_ERROR="index.html"
export TC_RAWAPI_HTTPS_ENABLED=true
export TC_RAWAPI_HTTPS_PORT=$TC_ORG1_G1_PORT2
export TC_RAWAPI_HTTPS_CERT=""
export TC_RAWAPI_HTTPS_CERT_FILE=""
export TC_RAWAPI_HTTPS_KEY=""
export TC_RAWAPI_HTTPS_KEY_FILE=""
export TC_RAWAPI_LOGALLERRORS=true
export TC_RAWAPI_MAXREQUESTBODYSIZE=4194304
export TC_RAWAPI_NETWORKPROTO="tcp"
export TC_RAWAPI_LOGLEVEL=7
export TC_RAWAPI_ORGNAME=$TC_ORG1_STACK
export TC_RAWAPI_MSPID=${TC_ORG1_STACK}MSP
export TC_RAWAPI_CERTPATH="${TC_ORG1_CLIENTMSP}/signcerts/cert.pem"
export TC_RAWAPI_KEYPATH="${TC_ORG1_CLIENTMSP}/keystore/"
export TC_RAWAPI_TLSCERTPATH=${TC_ORG1_G1_TLSMSP}/tlscacerts/tls-0-0-0-0-${TC_COMMON1_C1_PORT}.pem
export TC_RAWAPI_PEERENDPOINT=${TC_ORG1_P1_FQDN}:${TC_ORG1_P1_PORT}
export TC_RAWAPI_GATEWAYPEER=${TC_ORG1_P1_FQDN}

# endregion: raw api
# region: common funcs

[[ -f "$TC_PATH_COMMON" ]] && source "$TC_PATH_COMMON"
[[ -f "$COMMON_FUNCS" ]] && source "$COMMON_FUNCS"

export COMMON_FORCE=$TC_EXEC_FORCE
export COMMON_PANIC=$TC_EXEC_PANIC
export COMMON_PREREQS=("${TC_DEPS_BINS[@]}")
export COMMON_SILENT=$TC_EXEC_SILENT
export COMMON_VERBOSE=$TC_EXEC_VERBOSE

# endregion: common funcs
# region: load .env if any

[[ -f .env ]] && source .env

# endregion: .env
