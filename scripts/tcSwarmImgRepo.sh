#!/bin/bash

# region: load config

[[ ${TC_PATH_RC:-"unset"} == "unset" ]] && TC_PATH_RC=${TC_PATH_BASE}/scripts/commonFuncs.sh
if [ ! -f  $TC_PATH_RC ]; then
	echo "=> TC_PATH_RC ($TC_PATH_RC) not found, make sure proper path is set or you execute this from the repo's 'scrips' directory!"
	exit 1
fi
source $TC_PATH_RC

# commonPrintfBold "note that certain environment variables must be set to work properly!"
# commonContinue "have you reloded ${TC_PATH_BASE}/.env?"

if [[ ${TC_PATH_SCRIPTS:-"unset"} == "unset" ]]; then
	commonVerify 1 "TC_PATH_SCRIPTS is unset"
fi
commonPP $TC_PATH_SCRIPTS

# endregion: config

# export TC_SWARM_IMG_COUCHDB=localhost:6000/trustchain-couchdb

docker pull couchdb:${TC_DEPS_COUCHDB}
docker tag couchdb:${TC_DEPS_COUCHDB} $TC_SWARM_IMG_COUCHDB 
docker push $TC_SWARM_IMG_COUCHDB
docker image remove couchdb:${TC_DEPS_COUCHDB}
docker image remove $TC_SWARM_IMG_COUCHDB 

# export TC_SWARM_IMG_CA=localhost:6000/trustchain-fabric-ca

docker pull hyperledger/fabric-ca:${TC_DEPS_CA}
docker tag hyperledger/fabric-ca:${TC_DEPS_CA} $TC_SWARM_IMG_CA 
docker push $TC_SWARM_IMG_CA
docker image remove hyperledger/fabric-ca:${TC_DEPS_CA}
docker image remove $TC_SWARM_IMG_CA

# export TC_SWARM_IMG_ORDERER=localhost:6000/trustchain-fabric-orderer

docker pull hyperledger/fabric-orderer:${TC_DEPS_FABRIC}
docker tag hyperledger/fabric-orderer:${TC_DEPS_FABRIC} $TC_SWARM_IMG_ORDERER
docker push $TC_SWARM_IMG_ORDERER
docker image remove hyperledger/fabric-orderer:${TC_DEPS_FABRIC} 
docker image remove $TC_SWARM_IMG_ORDERER

# export TC_SWARM_IMG_PEER=localhost:6000/trustchain-fabric-peer

docker pull hyperledger/fabric-peer:${TC_DEPS_FABRIC}
docker tag hyperledger/fabric-peer:${TC_DEPS_FABRIC} $TC_SWARM_IMG_PEER
docker push $TC_SWARM_IMG_PEER
docker image remove hyperledger/fabric-peer:${TC_DEPS_FABRIC} 
docker image remove $TC_SWARM_IMG_PEER

# export TC_SWARM_IMG_TOOLS=localhost:6000/trustchain-fabric-tools

docker pull hyperledger/fabric-tools:${TC_DEPS_FABRIC}
docker tag hyperledger/fabric-tools:${TC_DEPS_FABRIC} $TC_SWARM_IMG_TOOLS
docker push $TC_SWARM_IMG_TOOLS
docker image remove hyperledger/fabric-tools:${TC_DEPS_FABRIC} 
docker image remove $TC_SWARM_IMG_TOOLS

# export TC_SWARM_IMG_CCENV=localhost:6000/trustchain-fabric-ccenv

docker pull hyperledger/fabric-ccenv:${TC_DEPS_FABRIC}
docker tag hyperledger/fabric-ccenv:${TC_DEPS_FABRIC} $TC_SWARM_IMG_CCENV
docker push $TC_SWARM_IMG_CCENV
docker image remove hyperledger/fabric-ccenv:${TC_DEPS_FABRIC} 
docker image remove $TC_SWARM_IMG_CCENV

# export TC_SWARM_IMG_BASEOS=localhost:6000/trustchain-fabric-baseos

docker pull hyperledger/fabric-baseos:${TC_DEPS_FABRIC}
docker tag hyperledger/fabric-baseos:${TC_DEPS_FABRIC} $TC_SWARM_IMG_BASEOS
docker push $TC_SWARM_IMG_BASEOS
docker image remove hyperledger/fabric-baseos:${TC_DEPS_FABRIC} 
docker image remove $TC_SWARM_IMG_BASEOS

# export TC_SWARM_IMG_NODEENV=localhost:6000/trustchain-fabric-nodeenv

docker pull hyperledger/fabric-nodeenv:${TC_DEPS_FABRIC}
docker tag hyperledger/fabric-nodeenv:${TC_DEPS_FABRIC} $TC_SWARM_IMG_NODEENV
docker push $TC_SWARM_IMG_NODEENV
docker image remove hyperledger/fabric-nodeenv:${TC_DEPS_FABRIC} 
docker image remove $TC_SWARM_IMG_NODEENV

# export TC_SWARM_IMG_VISUALIZER=localhost:6000/trustchain-visualizer

docker pull dockersamples/visualizer
docker tag dockersamples/visualizer $TC_SWARM_IMG_VISUALIZER
docker push $TC_SWARM_IMG_VISUALIZER
docker image remove dockersamples/visualizer
docker image remove $TC_SWARM_IMG_VISUALIZER

# export TC_SWARM_IMG_LOGSPOUT=localhost:6000/trustchain-logspout

docker pull gliderlabs/logspout:latest
docker tag gliderlabs/logspout:latest $TC_SWARM_IMG_LOGSPOUT
docker push $TC_SWARM_IMG_LOGSPOUT
docker image remove gliderlabs/logspout:latest
docker image remove $TC_SWARM_IMG_LOGSPOUT

# export TC_SWARM_IMG_PROMETHEUS=localhost:6000/trustchain-prometheus

docker pull prom/prometheus:latest
docker tag prom/prometheus:latest $TC_SWARM_IMG_PROMETHEUS
docker push $TC_SWARM_IMG_PROMETHEUS
docker image remove prom/prometheus:latest
docker image remove $TC_SWARM_IMG_PROMETHEUS

# export TC_SWARM_IMG_CADVISOR=localhost:6000/trustchain-cadvisor

docker pull gcr.io/cadvisor/cadvisor:latest
docker tag gcr.io/cadvisor/cadvisor:latest $TC_SWARM_IMG_CADVISOR
docker push $TC_SWARM_IMG_CADVISOR
docker image remove gcr.io/cadvisor/cadvisor:latest
docker image remove $TC_SWARM_IMG_CADVISOR

# export TC_SWARM_IMG_NODEEXPORTER=localhost:6000/trustchain-node-exporter

docker pull prom/node-exporter:v1.3.1
docker tag prom/node-exporter:v1.3.1 $TC_SWARM_IMG_NODEEXPORTER
docker push $TC_SWARM_IMG_NODEEXPORTER
docker image remove prom/node-exporter:v1.3.1
docker image remove $TC_SWARM_IMG_NODEEXPORTER

# export TC_SWARM_IMG_GRAFANA=localhost:6000/trustchain-grafana

docker pull grafana/grafana:latest
docker tag grafana/grafana:latest $TC_SWARM_IMG_GRAFANA
docker push $TC_SWARM_IMG_GRAFANA
docker image remove grafana/grafana:latest
docker image remove $TC_SWARM_IMG_GRAFANA

# export TC_SWARM_IMG_BUSYBOX=localhost:6000/trustchain-busybox

docker pull busybox 
docker tag busybox $TC_SWARM_IMG_BUSYBOX
docker push $TC_SWARM_IMG_BUSYBOX
docker image remove busybox
docker image remove $TC_SWARM_IMG_BUSYBOX

# export TC_SWARM_IMG_NETSHOOT=localhost:6000/trustchain-netshoot

docker pull nicolaka/netshoot
docker tag nicolaka/netshoot $TC_SWARM_IMG_NETSHOOT
docker push $TC_SWARM_IMG_NETSHOOT
docker image remove nicolaka/netshoot
docker image remove $TC_SWARM_IMG_NETSHOOT

# export TC_SWARM_IMG_PORTAINERAGENT=localhost:6000/trustchain-portainer-agent

docker pull portainer/agent:2.17.0
docker tag portainer/agent:2.17.0 $TC_SWARM_IMG_PORTAINERAGENT
docker push $TC_SWARM_IMG_PORTAINERAGENT
docker image remove portainer/agent:2.17.0
docker image remove $TC_SWARM_IMG_PORTAINERAGENT

# export TC_SWARM_IMG_PORTAINER=localhost:6000/trustchain-portainer

docker pull portainer/portainer-ce:2.17.0
docker tag portainer/portainer-ce:2.17.0 $TC_SWARM_IMG_PORTAINER
docker push $TC_SWARM_IMG_PORTAINER
docker image remove portainer/portainer-ce:2.17.0
docker image remove $TC_SWARM_IMG_PORTAINER
