#!/bin/bash

#
# Copyright TE-FOOD International GmbH., All Rights Reserved
#

# region: load common

[[ ${TEx_COMMON:-"unset"} == "unset" ]] && TEx_COMMON="./common.sh"
if [ ! -f  $TEx_COMMON ]; then
	echo "=> $TEx_COMMON not found, make sure proper path is set or you execute this from the repo's 'scrips' directory!"
	exit 1
fi
source $TEx_COMMON
TEx_PP $TEx_BASE

# endregion: load common
# region: defaults

envDummy=$TEx_DUMMY
envVerbose=$TEx_VERBOSE
# envGenesisBlock=true
# envChannel=true
envModes=("genesis" "create" "fetchConfig" "anchorPeer" "updateConfig")
envMode=""

defaultDelay=5
defaultGenesisBlock="genesis.block"
defaultOrderer="localhost:7053"
defaultProfile="TwoOrgsApplicationGenesis"
defaultRetry=3
defaultVerbose=true

TEx_FabricChannel_Defaults() {
	[[ ${TEx_DUMMY:-"unset"}			== "unset" ]]	&& export TEx_DUMMY=false
	[[ ${TEx_FABRIC_CAFILE:-"unset"}	== "unset" ]]	&& export TEx_FABRIC_CAFILE=$ORDERER_CA
	[[ ${TEx_FABRIC_CCERT:-"unset"}		== "unset" ]]	&& export TEx_FABRIC_CCERT=$ORDERER_ADMIN_TLS_SIGN_CERT
	[[ ${TEx_FABRIC_CFPATH:-"unset"}	== "unset" ]]	&& export TEx_FABRIC_CFPATH=$TEx_BASE
	[[ ${TEx_FABRIC_CFBLOCK:-"unset"}	== "unset" ]]	&& export TEx_FABRIC_CFBLOCK="${TEx_FABRIC_CFPATH}/${defaultGenesisBlock}"
	# TEx_FABRIC_CHID=""
	[[ ${TEx_FABRIC_CKEY:-"unset"}		== "unset" ]]	&& export TEx_FABRIC_CKEY=$ORDERER_ADMIN_TLS_PRIVATE_KEY
	[[ ${TEx_FABRIC_DELAY:-"unset"}		== "unset" ]]	&& export TEx_FABRIC_DELAY=$defaultDelay
	[[ ${TEx_FABRIC_ORDERER:-"unset"}	== "unset" ]]	&& export TEx_FABRIC_ORDERER=$defaultOrderer
	[[ ${TEx_FABRIC_PROFILE:-"unset"}	== "unset" ]]	&& export TEx_FABRIC_PROFILE=$defaultProfile
	[[ ${TEx_FABRIC_RETRY:-"unset"}		== "unset" ]]	&& export TEx_FABRIC_RETRY=$defaultRetry 
	[[ ${TEx_VERBOSE:-"unset"}			== "unset" ]]	&& export TEx_VERBOSE=$defaultVerbose
}
TEx_FabricChannel_Defaults

# endregion: defaults
# region: help

fabricChannelCreate_Help() {
	TEx_Printf "usage:"
	TEx_Printf "  $0 $_modes [mode] <options>"
	TEx_Printf ""
	TEx_Printf "modes:"
	TEx_Printf "  anchorPeer    - anchor peer to chennel"
	TEx_Printf "  create        - create channel"
	TEx_Printf "  fetchConfig   - fetch channel config"
	TEx_Printf "  genesis       - create genesis block"
	TEx_Printf ""
	TEx_Printf "options:"
	TEx_Printf "  -a, --clientCert <file>     file containing PEM-encoded X509 public key to use for mutual TLS communication with the OSN, sets \$TEx_FABRIC_CCERT, falls back to \$TEx_FABRIC_CCERT then \$ORDERER_ADMIN_TLS_SIGN_CERT"
	TEx_Printf "  -A, --clientKey <file>      file containing PEM-encoded private key to use for mutual TLS communication with the OSN, sets \$TEx_FABRIC_CKEY, falls back to \$TEx_FABRIC_CKEY then \$ORDERER_ADMIN_TLS_PRIVATE_KEY" 
	TEx_Printf "  -c, --channelID <string>    channel name to be created, set \$TEx_FABRIC_CHID, falls back to \$TEx_FABRIC_CHID"
	TEx_Printf "  -C, --configPath <path>     path containing the configuration (configtx.yaml), sets \$TEx_FABRIC_CFPATH, falls back to \$TEx_FABRIC_CFPATH then \$TEx_BASE"
	TEx_Printf "  -d, --dummy                 dummy mode, commands and final validations will not be executed, falls back to \$TEx_DUMMY"
	TEx_Printf "  -D, --delay <int>           delay between attempts, sets \$TEx_FABRIC_DELAY, falls back to \$TEx_FABRIC_DELAY then defaults to '$defaultDelay'"
	TEx_Printf "  -e, --env <file>            env file to load before execution" 
	TEx_Printf "  -f, --fileOutput <string>   file output where it makes sense (fetchConfig), set \$TEx_FABRIC_OUTPUT, falls back to \$TEx_FABRIC_OUTPUT"
	TEx_Printf "  -F, --fileInput <string>    file input where it makes sense (updateConfig), set \$TEx_FABRIC_INPUT, falls back to \$TEx_FABRIC_INPUT"
	TEx_Printf "  -g, --configBlock <file>    path to genesis block, sets \$TEx_FABRIC_CFBLOCK, falls back to \$TEx_FABRIC_CFBLOCK then defaults to \$TEx_FABRIC_CFPATH/${defaultGenesisBlock}"
	TEx_Printf "  -h, --help                  print this message"
	# TEx_Printf "  -n, --noGenesis             no genesis block will be created"
	# TEx_Printf "  -N, --noChannel             no actual channel will be created"
	TEx_Printf "  -o, --caFile <file>         path to file containing PEM-encoded TLS CA certificate(s) for the OSN, sets \$TEx_FABRIC_CAFILE, falls back to \$TEx_FABRIC_CAFILE then \$ORDERER_CA"
	TEx_Printf "  -O, --orderer <host:port>   orderer host and port, sets \$TEx_FABRIC_ORDERER, falls back to \$TEx_FABRIC_ORDERER then defaults to '$defaultOrderer'"
	TEx_Printf "  -p, --profile <file>        profile from configtx.yaml to use for genesis block generation, sets \$TEx_FABRIC_PROFILE, falls back to \$TEx_FABRIC_PROFILE, defaults to '$defaultProfile'"
	TEx_Printf "  -r, --retry <int>           number of max retries, sets \$TEx_FABRIC_RETRY, falls back to \$TEx_FABRIC_RETRY then defaults to '$defaultRetry'"
	TEx_Printf "  -v, --verbose <true|false>  sets verbose mode, falls back to \$TEx_VERBOSE,  default is '$defaultVerbose'"
	TEx_Printf ""
	TEx_Printf "- all paths are either absolute or relative to TEx_BASE (currently \"$TEx_BASE\")"
	TEx_Printf "- all parameters must have a value, except where there is a default or fallback"
	TEx_Printf ""
	TEx_Printf "peer and org data can be specified via environment variables where necessary, these are:"
	TEx_Printf "  - TEx_FABRIC_ORG_NAME"
	TEx_Printf "  - TEx_FABRIC_ORG_DOMAIN"
	TEx_Printf "  - TEx_FABRIC_PEER_NAME"
	TEx_Printf "  - TEx_FABRIC_PEER_FQDN"
	TEx_Printf "  - TEx_FABRIC_PEER_PORT"
	TEx_Printf ""
}

# endregion: help
# region: mode

if [[ $# -lt 1 ]] ; then
	fabricChannelCreate_Help
	exit 1
else
	envMode=$1
	if [[ ! " ${envModes[*]} " =~ " ${envMode} " ]]; then
		fabricChannelCreate_Help
		exit 1
	fi
	shift
fi

# endregion: mode
# region: getopt

# opts="a:A:c:C:dD:e:g:hnNo:O:p:r:v:"
# lopts="clientCert:,clientKey:,channelID:,configPath:,dummy,delay:,env:,configBlock:,help,noGenesis,noChannel,caFile:,orderer:,profile:,retry:,verbose:"
opts="a:A:c:C:dD:e:f:F:g:ho:O:p:r:v:"
lopts="clientCert:,clientKey:,channelID:,configPath:,dummy,delay:,env:,fileOutput:fileInput:configBlock:,help,caFile:,orderer:,profile:,retry:,verbose:"
args=$( getopt -n $0 -o "$opts" -l "$lopts" -a -Q -- "$@" 2>&1 )
if [ $? -ne 0 ]; then
	TEx_PrintfBold "$args"
	fabricChannelCreate_Help
	TEx_Verify 1
fi
args=$( getopt -n $0 -o "$opts" -l "$lopts" -a -q -- "$@" )
eval set -- "$args"
unset opts lopts

# endregion: getopt
# region: parse $@

checkDir()  { [[ -d "$2" ]] || TEx_Verify 1 "the directory specified by '$1 $2' is cannot be accessed"; }
checkFile() { [[ -f "$2" ]] || TEx_Verify 1 "the file specified by '$1 $2' is cannot be accessed"; }
checkInt()  { [[ $2 =~ ^[0-9]+$ ]] || TEx_Verify 1 "argument must be an integer in \"$1 $2\""; }

while [ : ]; do
	case "$1" in
		-e | --env)
			checkFile "$@"
			[[ -f $2 ]] && out=$( source $2 2>&1 )
			[[ $? -ne 0 ]] && TEx_Verify 1 "unable to source ${2}: ${out}" || source $2 
			shift 2
			unset out
			TEx_FabricChannel_Defaults
			;;
		--)
			shift
			break
			;;
		*)
			shift
			;;
	esac
done

eval set -- "$args"
unset args

while [ : ]; do
	case "$1" in
		-a | --clientCert)
			checkFile "$@"
			export TEx_FABRIC_CCERT="$2"
			shift 2
			;;
		-A | --clientKey)
			checkFile "$@"
			export TEx_FABRIC_CKEY="$2"
			shift 2
			;;
		-c | --channelID)
			export TEx_FABRIC_CHID="$2"
			shift 2
			;;
		-C | --configPath)
			checkDir "$@"
			export TEx_FABRIC_CFPATH="$2"
			shift 2
			;;
		-d | --dummy)
			TEx_DUMMY=true
			shift
			;;
		-D | --delay)
			checkInt "$@"
			export TEx_FABRIC_DELAY=$2
			shift 2
			;;
		-e | --env)
			shift 2
			;;
		-f | --fileOutput)
			export TEx_FABRIC_OUTPUT=$2
			shift 2
			;;
		-F | --fileInput)
			checkFile "$@"
			export TEx_FABRIC_INPUT=$2
			shift 2
			;;
		-g | --configBlock)
			# checkDir "$1" "$(dirname "$2")"
			export TEx_FABRIC_CFBLOCK="$2"
			shift 2
			;;
		-h | --help)
			fabricChannelCreate_Help
			exit 0
			;;
		# -n | --noGenesis)
		# 	envGenesisBlock=false
		# 	shift
		# 	;;
		# -N | --noChannel)
		# 	envChannel=false
		# 	shift
		# 	;;
		-o | --caFile)
			checkFile "$@"
			export TEx_FABRIC_CAFILE="$2"
			shift 2
			;;
		-O | --orderer)
			export TEx_FABRIC_ORDERER="$2"
			shift 2
			;;
		-p | --profile)
			export TEx_FABRIC_PROFILE="$2"
			shift 2
			;;
		-r | --retry)
			checkInt "$@"
			export TEx_FABRIC_RETRY=$2
			shift 2
			;;
		-v | --verbose)
			TEx_VERBOSE=$2
			shift 2
			;;
		--)
			shift
			break
			;;
		-*)
			TEx_Verify 1 "$0: error - unrecognized option $1"
			shift
			;;
		*)
			break
			;;
	esac
done

unset checkDir checkFile checkInt

# endregion: parse $@
# region: validate

TEx_FabricChannel_Validate() {
	# checkFile() { [[ -f "${!1}" ]] && TEx_Printf "'--$1' is set to '${!1}'" || TEx_Verify 1 "'${!1}' cannot be accessed, set proper value with '--$1'"; }
	# checkFile() { [[ -f "$2" ]] || TEx_Verify 1 "'$2' cannot be accessed, set proper value with '$1'" && TEx_Printf "'$1' is set to '$2'"; }
	checkFile() { [[ -f "$2" ]] || TEx_Verify 1 "'$2' cannot be accessed, set proper value with '$1'"; }
	checkFile --caFile		"$TEx_FABRIC_CAFILE"
	checkFile --clientCert	"$TEx_FABRIC_CCERT"
	checkFile --clientKey	"$TEx_FABRIC_CKEY"
	# checkInt()  { [[ $2 =~ ^[0-9]+$ ]] || TEx_Verify 1 "'$1' must be an integer" && TEx_Printf "'$1' is set to '$2'"; }
	checkInt()  { [[ $2 =~ ^[0-9]+$ ]] || TEx_Verify 1 "'$1' must be an integer"; }
	checkInt --delay $TEx_FABRIC_DELAY
	checkInt --retry $TEx_FABRIC_RETRY

	# [[ -d "$TEx_FABRIC_CFPATH" ]]			|| TEx_Verify 1 "'${TEx_FABRIC_CFPATH}' cannot be accessed, set proper value with '--configPath'" \
	# 										&& TEx_Printf "'--configPath' is set to '${TEx_FABRIC_CFPATH}'"
	# [[ "$TEx_FABRIC_CHID" =~ ^[a-zA-Z]+$ ]] || TEx_Verify 1 "--channelID ($TEx_FABRIC_CHID) must be set to match ^[a-zA-Z]+$" \
	# 										&& TEx_Printf "'--channelID' is set to '$TEx_FABRIC_CHID'"
	# [[ -f "$TEx_FABRIC_CFBLOCK" && "$genesis" == true ]]			&& TEx_Verify 1 "'${TEx_FABRIC_CFBLOCK}' is already exists, set proper value with '--configBlock'"
	# [[ -d "$TEx_FABRIC_CFBLOCK" ]] 									&& TEx_Verify 1 "'${TEx_FABRIC_CFBLOCK}' is an existing directory, set proper value with '--configBlock'"
	# [[ "$( basename "$TEx_FABRIC_CFBLOCK" )" =~ ^[a-zA-Z\.\-]+$ ]]	|| TEx_Verify 1 "--configBlock must be set to match ^[a-zA-Z\.\-]+$" \
	# 																&& TEx_Printf "'--configBlock' is set to '$TEx_FABRIC_CFBLOCK'"
	[[ -d "$TEx_FABRIC_CFPATH" ]]			|| TEx_Verify 1 "'${TEx_FABRIC_CFPATH}' cannot be accessed, set proper value with '--configPath'"
	[[ "$TEx_FABRIC_CHID" =~ ^[a-zA-Z]+$ ]] || TEx_Verify 1 "--channelID ($TEx_FABRIC_CHID) must be set to match ^[a-zA-Z]+$"
	[[ -f "$TEx_FABRIC_CFBLOCK" && "$genesis" == true ]]			&& TEx_Verify 1 "'${TEx_FABRIC_CFBLOCK}' is already exists, set proper value with '--configBlock'"
	[[ -d "$TEx_FABRIC_CFBLOCK" ]] 									&& TEx_Verify 1 "'${TEx_FABRIC_CFBLOCK}' is an existing directory, set proper value with '--configBlock'"
	[[ "$( basename "$TEx_FABRIC_CFBLOCK" )" =~ ^[a-zA-Z\.\-]+$ ]]	|| TEx_Verify 1 "--configBlock must be set to match ^[a-zA-Z\.\-]+$"

	unset -f checkFile
	unset -f checkInt
}
# [[ "$TEx_DUMMY" != true ]] && TEx_FabricChannel_Validate

# endregion: validate
# region: actual bussines

TEx_FabricChannel_Genesis() {
	TEx_Printf "TEx_FabricChannel_Genesis() is being invoked"

	local out=$( configtxgen -profile "$TEx_FABRIC_PROFILE" -outputBlock "$TEx_FABRIC_CFBLOCK" -configPath "$TEx_FABRIC_CFPATH" -channelID "$TEx_FABRIC_CHID" 2>&1 )
	local res=$?
	TEx_Verify $res "failed to generate orderer genesis block: $out" "$out"
	[[ $res -ne 0 ]] && return 1 || return 0
}

TEx_FabricChannel_Create() {
	TEx_Printf "$TEx_FABRIC_RETRY attempts with ${TEx_FABRIC_DELAY}s safety delay to create channel \"${TEx_FABRIC_CHID}\" via \"${TEx_FABRIC_ORDERER}\" is being carried out"

	local cnt=1
	local res=1
	local out=""
	while [ $res -ne 0 -a $cnt -le $TEx_FABRIC_RETRY ] ; do
		TEx_Printf "attempt #${cnt}"
		TEx_Sleep $TEx_FABRIC_DELAY "${TEx_FABRIC_DELAY}s safety delay"
		# out=$( osnadmin channel join --channelID "$TEx_FABRIC_CHID" --config-block "$TEx_FABRIC_CFBLOCK" -o $TEx_FABRIC_ORDERER --ca-file "$TEx_FABRIC_CAFILE" --client-cert "$TEx_FABRIC_CCERT" --client-key "$TEx_FABRIC_CKEY" )
		out=$( osnadmin channel join --channelID "$TEx_FABRIC_CHID" --config-block "$TEx_FABRIC_CFBLOCK" -o $TEx_FABRIC_ORDERER )
		res=$?
		cnt=$(expr $cnt + 1)
		TEx_Printf "osnadmin output ($res): $out"
	done
	TEx_Verify $res "channel creation failed" "channel created successfully"
}

TEx_FabricChannel_FetchConfig() {
	[[ -z "$TEx_FABRIC_OUTPUT" ]] && local output=$( mktemp "${TMPDIR:-/tmp/}$(basename "$0")_FetchConfig.XXXXXX" ) || local output=$TEx_FABRIC_OUTPUT
	local raw=$( mktemp "${TMPDIR:-/tmp/}$(basename "$0")_FetchConfig_raw.XXXXXX" )
	local decoded=$( mktemp "${TMPDIR:-/tmp/}$(basename "$0")_FetchConfig_decoded.XXXXXX" )
	local out="-"

	# SC_SetGlobalsCLI
	# out=$( peer channel fetch config "$raw" -o ${TEx_FABRIC_ORDERER} --ordererTLSHostnameOverride localhost -c $ch --tls --cafile "$ORDERER_CA" 2>&1 )
	TEx_Printf "fetching the most recent configuration block for channel \"$TEx_FABRIC_CHID\" into $output"
	env | sort > FetchConfig.env
	out=$( peer channel fetch config "$raw" -c $TEx_FABRIC_CHID 2>&1 )
	TEx_Verify $? "unable to fetch confguration: $out" "raw data writen to \"${raw}\": $out"

	TEx_Printf "decoding config block to JSON"
	out=$( configtxlator proto_decode --input "$raw" --type common.Block --output "$decoded" 2>&1 )
	out=${out:--}
	TEx_Verify $? "unable to decode raw data: $out" "decoded data writen to \"$decoded\": $out"

	TEx_Printf "isolating config to $output"
	out=$( jq .data.data[0].payload.data.config $decoded > $output )
	TEx_Verify $? "unable to isolate config: $out" "config isolated to $output"

	rm "$raw"
	rm "$decoded"
}

# Takes an original and modified config, and produces the config update tx
# which transitions between the two
# NOTE: this must be run in a CLI container since it requires configtxlator
TEx_FabricChannel_UpdateConfig() {
	[[ -z "$TEx_FABRIC_OUTPUT" ]] && local output=$( mktemp "${TMPDIR:-/tmp/}$(basename "$0")_UpdateConfig.XXXXXX" ) || local output=$TEx_FABRIC_OUTPUT
	[[ -z "$1" ]] && TEx_Verify 1 "TEx_FabricChannel_UpdateConfig need original and modified config as a parameter" || originalConfig=$1
	[[ -z "$2" ]] && TEx_Verify 1 "TEx_FabricChannel_UpdateConfig need original and modified config as a parameter" || modifiedConfig=$2 
	local originalProto=$( mktemp "${TMPDIR:-/tmp/}$(basename "$0")_UpdateConfig_originalProto.XXXXXX" )
	local modifiedProto=$( mktemp "${TMPDIR:-/tmp/}$(basename "$0")_UpdateConfig_modifiedProto.XXXXXX" )
	local updateProto=$( mktemp "${TMPDIR:-/tmp/}$(basename "$0")_UpdateConfig_configUpdate.XXXXXX" )
	local updateJSON=$( mktemp "${TMPDIR:-/tmp/}$(basename "$0")_UpdateConfig_configJSON.XXXXXX" )
	local updateEnveloped=$( mktemp "${TMPDIR:-/tmp/}$(basename "$0")_UpdateConfig_configEnveloped.XXXXXX" )
	local out="-"

	TEx_Printf "updating config for \"$TEx_FABRIC_CHID\" channel"
	checkFile() { [[ -f "$2" ]] || TEx_Verify 1 "the file specified by '$1=$2' is cannot be accessed"; }
	checkFile "originalConfig" $originalConfig
	checkFile "originalConfig" $modifiedConfig

	###
	# CHANNEL=$1
	# ORIGINAL=$2
	# MODIFIED=$3
	# OUTPUT=$4
	# configtxlator proto_encode --input "${ORIGINAL}" --type common.Config --output original_config.pb
  	# configtxlator proto_encode --input "${MODIFIED}" --type common.Config --output modified_config.pb
  	# configtxlator compute_update --channel_id "${CHANNEL}" --original original_config.pb --updated modified_config.pb --output config_update.pb
  	# configtxlator proto_decode --input config_update.pb --type common.ConfigUpdate --output config_update.json
  	# echo '{"payload":{"header":{"channel_header":{"channel_id":"'$CHANNEL'", "type":2}},"data":{"config_update":'$(cat config_update.json)'}}}' | jq . >config_update_in_envelope.json
  	# configtxlator proto_encode --input config_update_in_envelope.json --type common.Envelope --output "${OUTPUT}"

	configtxlator proto_encode --input "${originalConfig}" --type common.Config --output $originalProto 
	configtxlator proto_encode --input "${modifiedConfig}" --type common.Config --output $modifiedProto
	configtxlator compute_update --channel_id "${TEx_FABRIC_CHID}" --original $originalProto --updated $modifiedProto --output $updateProto
	configtxlator proto_decode --input $updateProto --type common.ConfigUpdate --output $updateJSON
	echo '{"payload":{"header":{"channel_header":{"channel_id":"'$TEx_FABRIC_CHID'", "type":2}},"data":{"config_update":'$(cat $updateJSON)'}}}' | jq . > $updateEnveloped
	configtxlator proto_encode --input $updateEnveloped --type common.Envelope --output "${output}"

	# reset env
	# rm $originalProto
	# rm $modifiedProto
	# rm $updateProto
	# rm $updateJSON
	# rm $updateEnveloped
	unset checkFile
}

TEx_FabricChannel_Update() {
	TEx_Printf "updating \"$TEx_FABRIC_CHID\" channel"

	[[ -z "$TEx_FABRIC_INPUT" ]] && TEx_Verify 1 "TEx_FabricChannel_Update need TEx_FABRIC_INPUT to be set" || local input=$TEx_FABRIC_OUTPUT
	checkFile() { [[ -f "$2" ]] || TEx_Verify 1 "the file specified by '$1 $2' is cannot be accessed"; }
	checkFile "TEx_FABRIC_OUTPUT" $input
	local out="-"
	
	# peer channel update -o orderer.example.com:7050 --ordererTLSHostnameOverride orderer.example.com -c $CHANNEL_NAME -f ${CORE_PEER_LOCALMSPID}anchors.tx --tls --cafile "$ORDERER_CA" >&log.txt
	# peer channel update -o $TEx_FABRIC_ORDERER --ordererTLSHostnameOverride orderer.example.com -c $CHANNEL_NAME -f ${CORE_PEER_LOCALMSPID}anchors.tx --tls --cafile "$ORDERER_CA" >&log.txt
	env | sort > FabricPeerUpdate.env
	out=$( peer channel update -o $TEx_FABRIC_ORDERER -c $TEx_FABRIC_CHID -f $input --cafile "$TEx_FABRIC_CAFILE" --certfile "$TEx_FABRIC_CCERT" --keyfile "$TEx_FABRIC_CKEY" --connTimeout ${TEx_FABRIC_DELAY}s  2>&1 )
	TEx_Verify $? "update failed (peer channel update -o $TEx_FABRIC_ORDERER -c $TEx_FABRIC_CHID -f $input --cafile "$ORDERER_CA"): $out" "successful : $out"

	# reset
	unset checkFile
}

TEx_FabricChannel_AnchorPeer() {
	TEx_Printf "anchoring org/peer to \"$TEx_FABRIC_CHID\" channel"

	# fetch config
	local outputDefault=$TEx_FABRIC_OUTPUT
	local inputDefault=$TEx_FABRIC_INPUT

	outputFetchConfig=$( mktemp "${TMPDIR:-/tmp/}$(basename "$0")_AnchorPeer_outputFetchConfig.XXXXXX" )
	TEx_FABRIC_OUTPUT=$outputFetchConfig
	TEx_FabricChannel_FetchConfig

	# modify config to append anchor peer
	outputFetchConfigUpdate=$( mktemp "${TMPDIR:-/tmp/}$(basename "$0")_AnchorPeer_outputFetchConfigUpdate.XXXXXX" )
	jq '.channel_group.groups.Application.groups.'${CORE_PEER_LOCALMSPID}'.values += {"AnchorPeers":{"mod_policy": "Admins","value":{"anchor_peers": [{"host": "'$TEx_FABRIC_PEER_FQDN'","port": '$SC_ORG1_P1_PORT'}]},"version": "0"}}' $outputFetchConfig > $outputFetchConfigUpdate

	# prepare and update config block
	outputUpdateConfig=$( mktemp "${TMPDIR:-/tmp/}$(basename "$0")_AnchorPeer_outputUpdateConfig.XXXXXX" )
	TEx_FABRIC_OUTPUT=$outputUpdateConfig
	TEx_FabricChannel_UpdateConfig $outputFetchConfig $outputFetchConfigUpdate 
	TEx_FABRIC_INPUT=$outputUpdateConfig
	TEx_FabricChannel_Update	

	# reset env
	# rm $outputFetchConfig
	# rm $outputFetchConfigUpdate
	# rm $outputUpdateConfig
	TEx_FABRIC_OUTPUT=$outputDefault
	TEx_FABRIC_INPUT=$inputDefault
}

if [ "$TEx_DUMMY" != true ]; then
	TEx_FabricChannel_Defaults
	TEx_FabricChannel_Validate
	
	case "$envMode" in
		anchorPeer)
			TEx_FabricChannel_AnchorPeer
			;;
		create)
			TEx_FabricChannel_Create
			;;
		fetchConfig)
			TEx_FabricChannel_FetchConfig
			;;
		genesis)
			TEx_FabricChannel_Genesis
			;;
		*)
			TEx_PrintfBolt "something went wrong..."
			fabricChannelCreate_Help
			exit 1
			;;
	esac
else
	TEx_PrintfBold "$0 is in dummy mode, commands and validations will not be executed due to CLI or ENV settings" 
fi

# endregion: actual
# region: closing provisions

export TEx_DUMMY=$envDummy
export TEx_VERBOSE=$envVerbose

# unset envGenesisBlock envChannel
unset envDummy envVerbose
unset envMode envModes

unset defaultDelay
unset defaultRetry
unset defaultProfile
unset defaultGenesisBlock
unset defaultOrderer
unset defaultVerbose

# endregion: closing
