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

defaultDelay=3
defaultGenesisBlock="genesis.block"
defaultOrderer="localhost:7053"
defaultRetry=3
defaultVerbose=true

TEx_FabricPeerJoin_Defaults() {
	[[ ${TEx_DUMMY:-"unset"}			== "unset" ]]	&& export TEx_DUMMY=false
	[[ ${TEx_FABRIC_CAFILE:-"unset"}	== "unset" ]]	&& export TEx_FABRIC_CAFILE=$ORDERER_CA
	[[ ${TEx_FABRIC_CCERT:-"unset"}		== "unset" ]]	&& export TEx_FABRIC_CCERT=$ORDERER_ADMIN_TLS_SIGN_CERT
	[[ ${TEx_FABRIC_CFBLOCK:-"unset"}	== "unset" ]]	&& export TEx_FABRIC_CFBLOCK="${TEx_FABRIC_CFPATH}/${defaultGenesisBlock}"
	# TEx_FABRIC_CHID=""
	[[ ${TEx_FABRIC_CKEY:-"unset"}		== "unset" ]]	&& export TEx_FABRIC_CKEY=$ORDERER_ADMIN_TLS_PRIVATE_KEY
	[[ ${TEx_FABRIC_DELAY:-"unset"}		== "unset" ]]	&& export TEx_FABRIC_DELAY=$defaultDelay
	[[ ${TEx_FABRIC_ORDERER:-"unset"}	== "unset" ]]	&& export TEx_FABRIC_ORDERER=$defaultOrderer
	[[ ${TEx_FABRIC_RETRY:-"unset"}		== "unset" ]]	&& export TEx_FABRIC_RETRY=$defaultRetry 
	[[ ${TEx_VERBOSE:-"unset"}			== "unset" ]]	&& export TEx_VERBOSE=$defaultVerbose
}
TEx_FabricPeerJoin_Defaults

# endregion: defaults
# region: help

TEx_FabricPeerJoin_Help() {
	TEx_Printf "usage:"
	TEx_Printf "  $0 <options>"
	TEx_Printf ""
	TEx_Printf "options:"
	TEx_Printf "  -a, --clientCert <file>     file containing PEM-encoded X509 public key to use for mutual TLS communication with the OSN, sets \$TEx_FABRIC_CCERT, falls back to \$TEx_FABRIC_CCERT then \$ORDERER_ADMIN_TLS_SIGN_CERT"
	TEx_Printf "  -A, --clientKey <file>      file containing PEM-encoded private key to use for mutual TLS communication with the OSN, sets \$TEx_FABRIC_CKEY, falls back to \$TEx_FABRIC_CKEY then \$ORDERER_ADMIN_TLS_PRIVATE_KEY" 
	TEx_Printf "  -c, --channelID <string>    channel name to be created, set \$TEx_FABRIC_CHID, falls back to \$TEx_FABRIC_CHID"
	TEx_Printf "  -d, --dummy                 dummy mode, commands and final validations will not be executed, falls back to \$TEx_DUMMY"
	TEx_Printf "  -D, --delay <int>           delay between attempts, sets \$TEx_FABRIC_DELAY, falls back to \$TEx_FABRIC_DELAY then defaults to '$defaultDelay'"
	TEx_Printf "  -e, --env <file>            env file to load before execution" 
	TEx_Printf "  -g, --configBlock <file>    path to genesis block, sets \$TEx_FABRIC_CFBLOCK, falls back to \$TEx_FABRIC_CFBLOCK then defaults to \$TEx_FABRIC_CFPATH/${defaultGenesisBlock}"
	TEx_Printf "  -h, --help                  print this message"
	TEx_Printf "  -o, --caFile <file>         path to file containing PEM-encoded TLS CA certificate(s) for the OSN, sets \$TEx_FABRIC_CAFILE, falls back to \$TEx_FABRIC_CAFILE then \$ORDERER_CA"
	TEx_Printf "  -O, --orderer <host:port>   orderer host and port, sets \$TEx_FABRIC_ORDERER, falls back to \$TEx_FABRIC_ORDERER then defaults to '$defaultOrderer'"
	TEx_Printf "  -r, --retry <int>           number of max retries, sets \$TEx_FABRIC_RETRY, falls back to \$TEx_FABRIC_RETRY then defaults to '$defaultRetry'"
	TEx_Printf "  -v, --verbose <true|false>  sets verbose mode, falls back to \$TEx_VERBOSE,  default is '$defaultVerbose'"
	TEx_Printf ""
	TEx_Printf "- all paths are either absolute or relative to TEx_BASE (currently \"$TEx_BASE\")"
	TEx_Printf "- all parameters must have a value, except where there is a default or fallback"
	TEx_Printf "- peer and org definition relies on the environment's standard FABRIC_LOGGING_SPEC and CORE_PEER_* variables, it is possible that this will be changed later so that it can be specified with cli parameters"
}

# endregion: help
# region: getopt

opts="a:A:c:dD:e:g:ho:O:r:v:"
lopts="clientCert:,clientKey:,channelID:,dummy,delay:,env:,configBlock:,help,caFile:,orderer:,retry:,verbose:"
args=$( getopt -n $0 -o "$opts" -l "$lopts" -a -Q -- "$@" 2>&1 )
if [ $? -ne 0 ]; then
	TEx_PrintfBold "$args"
	TEx_FabricPeerJoin_Help
	TEx_Verify 1
fi
args=$( getopt -n $0 -o "$opts" -l "$lopts" -a -q -- "$@" )
eval set -- "$args"
unset opts lopts

# endregion: getopt
# region: parse $@

# checkDir()  { [[ -d "$2" ]] || TEx_Verify 1 "the directory specified by '$1 $2' is cannot be accessed"; }
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
			TEx_FabricPeerJoin_Defaults
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
		-g | --configBlock)
			# checkDir "$1" "$(dirname "$2")"
			export TEx_FABRIC_CFBLOCK="$2"
			shift 2
			;;
		-h | --help)
			TEx_FabricPeerJoin_Help
			exit 0
			;;
		-o | --caFile)
			checkFile "$@"
			export TEx_FABRIC_CAFILE="$2"
			shift 2
			;;
		-O | --orderer)
			export TEx_FABRIC_ORDERER="$2"
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

TEx_FabricPeerJoin_Validate() {
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

	# [[ "$TEx_FABRIC_CHID" =~ ^[a-zA-Z]+$ ]] || TEx_Verify 1 "--channelID must be set to match ^[a-zA-Z]+$" \
	# 										&& TEx_Printf "'--channelID' is set to '$TEx_FABRIC_CHID'"
	# [[ -f "$TEx_FABRIC_CFBLOCK" && "$genesis" == true ]]			&& TEx_Verify 1 "'${TEx_FABRIC_CFBLOCK}' is already exists, set proper value with '--configBlock'"
	# [[ -d "$TEx_FABRIC_CFBLOCK" ]] 									&& TEx_Verify 1 "'${TEx_FABRIC_CFBLOCK}' is an existing directory, set proper value with '--configBlock'"
	# [[ "$( basename "$TEx_FABRIC_CFBLOCK" )" =~ ^[a-zA-Z\.\-]+$ ]]	|| TEx_Verify 1 "--configBlock must be set to match ^[a-zA-Z\.\-]+$" \
	# 																&& TEx_Printf "'--configBlock' is set to '$TEx_FABRIC_CFBLOCK'"
	[[ "$TEx_FABRIC_CHID" =~ ^[a-zA-Z]+$ ]] || TEx_Verify 1 "--channelID must be set to match ^[a-zA-Z]+$"
	[[ -f "$TEx_FABRIC_CFBLOCK" && "$genesis" == true ]]			&& TEx_Verify 1 "'${TEx_FABRIC_CFBLOCK}' is already exists, set proper value with '--configBlock'"
	[[ -d "$TEx_FABRIC_CFBLOCK" ]] 									&& TEx_Verify 1 "'${TEx_FABRIC_CFBLOCK}' is an existing directory, set proper value with '--configBlock'"
	[[ "$( basename "$TEx_FABRIC_CFBLOCK" )" =~ ^[a-zA-Z\.\-]+$ ]]	|| TEx_Verify 1 "--configBlock must be set to match ^[a-zA-Z\.\-]+$"

	unset -f checkFile
	unset -f checkInt
}
# [[ "$TEx_DUMMY" != true ]] && TEx_FabricChannelCreate_Validate

# endregion: validate
# region: actual bussines

TEx_FabricPeerJoin() {
	TEx_Printf "$TEx_FABRIC_RETRY attempts with ${TEx_FABRIC_DELAY}s safety delay to join $CORE_PEER_ADDRESS to channel \"${TEx_FABRIC_CHID}\" via \"${TEx_FABRIC_ORDERER}\" is being carried out"
	TEx_FabricPeerJoin_Defaults
	TEx_FabricPeerJoin_Validate

	local cnt=1
	local res=1
	local out=""
	while [ $res -ne 0 -a $cnt -le $TEx_FABRIC_RETRY ] ; do
		TEx_Printf "attempt #${cnt}"
		TEx_Sleep $TEx_FABRIC_DELAY "${TEx_FABRIC_DELAY}s safety delay"
		env | sort > FabricPeerJoin.env
		out=$( peer channel join -b "$TEx_FABRIC_CFBLOCK" -o $TEx_FABRIC_ORDERER --cafile "$TEx_FABRIC_CAFILE" --certfile "$TEx_FABRIC_CCERT" --keyfile "$TEx_FABRIC_CKEY" --connTimeout ${TEx_FABRIC_DELAY}s 2>&1 )
		res=$?
		cnt=$(expr $cnt + 1)
		TEx_Printf "join output ($res): $out"
	done
	TEx_Verify $res "after $TEx_FABRIC_RETRY attempts, ${CORE_PEER_ADDRESS} has failed to join channel '$TEx_FABRIC_CHID'" "${CORE_PEER_ADDRESS} has successfully joined to channel '$TEx_FABRIC_CHID'"
}

[[ "$TEx_DUMMY" != true ]] && TEx_FabricPeerJoin || TEx_PrintfBold "$0 is in dummy mode, commands and validations will not be executed due to CLI or ENV settings"

# endregion: actual
# region: closing provisions

export TEx_DUMMY=$envDummy
export TEx_VERBOSE=$envVerbose

unset envDummy envVerbose
unset envGenesisBlock envChannel

unset defaultDelay
unset defaultRetry
unset defaultProfile
unset defaultGenesisBlock
unset defaultOrderer
unset defaultVerbose

# endregion: closing
