# region: interfaces, metrics and management

export SC_UID=$SC_UID
export SC_GID=$SC_GID

export SC_INTERFACES_CLI_HOST=$SC_SWARM_MANAGER
export SC_INTERFACES_CLI_BASE=/opt/gopath/src/github.com/hyperledger/fabric/peer
export SC_INTERFACES_CLI_SCRIPTS=$( echo $SC_PATH_SCRIPTS | sed s+${SC_PATH_BASE}+${SC_INTERFACES_CLI_BASE}+ )
export SC_INTERFACES_CLI_ORGS=$( echo $SC_PATH_ORGS | sed s+${SC_PATH_BASE}+${SC_INTERFACES_CLI_BASE}+ )
export SC_INTERFACES_CLI_STORAGE=$( echo $SC_PATH_STORAGE | sed s+${SC_PATH_BASE}+${SC_INTERFACES_CLI_BASE}+ )
export SC_INTERFACES_CLI_COMMON=$( echo $TEx_COMMON | sed s+${SC_PATH_BASE}+${SC_INTERFACES_CLI_BASE}+ )

export SC_METRICS_HOST=$SC_SWARM_MANAGER
export SC_METRICS_VISUALIZER_PORT=5050
export SC_METRICS_PROMETHEUS_PORT=5051
export SC_METRICS_CADVISOR_PORT=5052
export SC_METRICS_NEXPORTER_PORT=5053
export SC_METRICS_GRAFANA_PORT=5054
export SC_METRICS_GRAFANA_PASSWORD=$SC_METRICS_GRAFANA_PASSWORD
export SC_METRICS_LOGSPOUT_PORT=5055

export SC_MGMT_HOST=$SC_SWARM_MANAGER
export SC_MGMT_PORTAINER_PASSWORD=$SC_MGMT_PORTAINER_PASSWORD
export SC_MGMT_PORTAINER_PORT=5070

# endregion: interfaces
# region: functions

SC_SetGlobals() {
	[[ -z "$1" ]] && local org=ORG1 || local org=$(echo "$1" |  tr '[:lower:]' '[:upper:]' )
	[[ -z "$2" ]] && local peer=P1 || local peer=$(echo "$2" |  tr '[:lower:]' '[:lower:]' )
	local org_name="SC_${org}_NAME"
	local org_domain="SC_${org}_DOMAIN"
	local peer_name="SC_${org}_${peer}_NAME"
	local peer_port="SC_${org}_${peer}_PORT"

	if [[ "$TEx_SHELL" = "zsh" ]]; then
		# TEx_Printf "ZSH detected"
		[[ -z "${(P)org_name}" ]] && TEx_Verify 1 "invalid org ${org}"
		[[ -z "${(P)peer_name}" ]] && TEx_Verify 1 "invalid peer ${peer}"
		# TEx_Printf "setting globals for ${(P)peer_name}.${(P)org_domain}"

		export TEx_FABRIC_ORG_NAME=${(P)org_name}
		export TEx_FABRIC_ORG_DOMAIN=${(P)org_name}.${SC_NETWORK_DOMAIN}
		export TEx_FABRIC_PEER_NAME=${(P)peer_name}
		export TEx_FABRIC_PEER_FQDN=${(P)peer_name}.${(P)org_name}.${SC_NETWORK_DOMAIN}
		export TEx_FABRIC_PEER_PORT=${(P)peer_port}
	else
		# TEx_Printf "BASH detected"
		[[ -z "${!org_name}" ]] && TEx_Verify 1 "invalid org ${org}"
		[[ -z "${!peer_name}" ]] && TEx_Verify 1 "invalid peer ${peer}"
		# TEx_Printf "setting globals for ${!peer_name}.${!org_domain}"

		export TEx_FABRIC_ORG_NAME=${!org_name}
		export TEx_FABRIC_ORG_DOMAIN=${!org_name}.${SC_NETWORK_DOMAIN}
		export TEx_FABRIC_PEER_NAME=${!peer_name}
		export TEx_FABRIC_PEER_FQDN=${!peer_name}.${!org_name}.${SC_NETWORK_DOMAIN}
		export TEx_FABRIC_PEER_PORT=${!peer_port}
	fi

	export TEx_FABRIC_CHID="$TEx_FABRIC_CHID"
	export TEx_FABRIC_CFPATH="$SC_PATH_CONF"
	export TEx_FABRIC_PROFILE="$SC_CHANNEL_PROFILE"
	export TEx_FABRIC_ORDERER="localhost:${SC_ORDERER1_O1_ADMINPORT}"
	export TEx_FABRIC_CFBLOCK="${SC_PATH_ARTIFACTS}/${TEx_FABRIC_CHID}-genesis.block"
	export TEx_FABRIC_CAFILE="${SC_PATH_ORGS}/ordererOrganizations/${SC_ORDERER1_DOMAIN}/tlsca/tlsca.${SC_ORDERER1_DOMAIN}-cert.pem"
	export TEx_FABRIC_CCERT="${SC_PATH_ORGS}/ordererOrganizations/${SC_ORDERER1_DOMAIN}/orderers/${SC_ORDERER1_O1_FQDN}/tls/server.crt"
	export TEx_FABRIC_CKEY="${SC_PATH_ORGS}/ordererOrganizations/${SC_ORDERER1_DOMAIN}/orderers/${SC_ORDERER1_O1_FQDN}/tls/server.key"

	export FABRIC_LOGGING_SPEC=${SC_FABRIC_LOGLEVEL}
	export FABRIC_CFG_PATH=${SC_PATH_PEERCFG}

	export ORDERER_CA=$TEx_FABRIC_CAFILE
	export ORDERER_ADMIN_TLS_SIGN_CERT=$TEx_FABRIC_CCERT
	export ORDERER_ADMIN_TLS_PRIVATE_KEY=${SC_PATH_ORGS}/ordererOrganizations/${SC_ORDERER1_DOMAIN}/orderers/${SC_ORDERER1_O1_FQDN}/tls/server.key

	export CORE_PEER_TLS_ENABLED=true
	export CORE_PEER_LOCALMSPID="${TEx_FABRIC_ORG_NAME}MSP"
	export CORE_PEER_TLS_ROOTCERT_FILE=${SC_PATH_ORGS}/peerOrganizations/${TEx_FABRIC_ORG_DOMAIN}/tlsca/tlsca.${TEx_FABRIC_ORG_DOMAIN}-cert.pem
	export CORE_PEER_MSPCONFIGPATH=${SC_PATH_ORGS}/peerOrganizations/${TEx_FABRIC_ORG_DOMAIN}/users/Admin@${TEx_FABRIC_ORG_DOMAIN}/msp
	export CORE_PEER_ADDRESS=localhost:${TEx_FABRIC_PEER_PORT}
}
# SC_SetGlobals

SC_SetGlobalsCLI() {
	SC_SetGlobals $1 $2

	export FABRIC_CFG_PATH=$( echo $SC_PATH_PEERCFG | sed s+${SC_PATH_BASE}+${SC_INTERFACES_CLI_BASE}+ )

	export ORDERER_CA=${SC_INTERFACES_CLI_ORGS}/ordererOrganizations/${SC_ORDERER1_DOMAIN}/tlsca/tlsca.${SC_ORDERER1_DOMAIN}-cert.pem
	export ORDERER_ADMIN_TLS_SIGN_CERT=${SC_INTERFACES_CLI_ORGS}/ordererOrganizations/${SC_ORDERER1_DOMAIN}/orderers/${SC_ORDERER1_O1_FQDN}/tls/server.crt
	export ORDERER_ADMIN_TLS_PRIVATE_KEY=${SC_INTERFACES_CLI_ORGS}/ordererOrganizations/${SC_ORDERER1_DOMAIN}/orderers/${SC_ORDERER1_O1_FQDN}/tls/server.key

	export CORE_PEER_ADDRESS=${TEx_FABRIC_PEER_FQDN}:${TEx_FABRIC_PEER_PORT} 

	export TEx_FABRIC_CFPATH="${SC_INTERFACES_CLI_STORAGE}/conf"
	export TEx_FABRIC_ORDERER="${SC_ORDERER1_O1_FQDN}:${SC_ORDERER1_O1_ADMINPORT}"
	export TEx_FABRIC_CFBLOCK="${SC_INTERFACES_CLI_STORAGE}/artifacts/${TEx_FABRIC_CHID}-genesis.block"
}

# endregion: functions
