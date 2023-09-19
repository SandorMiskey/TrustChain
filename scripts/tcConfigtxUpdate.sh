#!/bin/bash

# region: load common functions

[[ ${TC_PATH_RC:-"unset"} == "unset" ]] && TC_PATH_RC=${TC_PATH_BASE}/scripts/commonFuncs.sh
if [ ! -f  $TC_PATH_RC ]; then
	echo "=> TC_PATH_RC ($TC_PATH_RC) not found, make sure proper path is set or you execute this from the repo's 'scrips' directory!"
	exit 1
fi
source $TC_PATH_RC

if [[ ${TC_PATH_SCRIPTS:-"unset"} == "unset" ]]; then
	commonVerify 1 "TC_PATH_SCRIPTS is unset"
fi
# commonPP $TC_PATH_SCRIPTS

# endregion: common
# region: defaults


declare -A setArgs
setArgs[channel]=$TC_CHANNEL1_NAME
setArgs[dry]=false
setArgs[orig]=""
setArgs[moded]=""
setArgs[mode]=false
setArgs[output]=""
setArgs[update]=""
setArgs[verbose]=false

# endregion: defaults
# region: help

function _help() {
	commonPrintf "usage:"
	commonPrintf "  $0 [mode] <options>"
	commonPrintf ""
	commonPrintf "modes:"
	commonPrintf "  commit      submit config update"
	commonPrintf "  encode      encode configtx"
	commonPrintf "  fetch       fetch, decode and unwrap latest config block"
	commonPrintf "  help        this"
	commonPrintf "  sign        sign configtx"
	commonPrintf ""
	commonPrintf "usual workflow:"
	commonPrintf "  1. 'fetch' the latest config block"
	commonPrintf "  2. make a copy and change settings"
	commonPrintf "  3. 'encode' the config update"
	commonPrintf "  4. 'sign', if necessary"
	commonPrintf "  5. 'commit'"
	commonPrintf ""
	commonPrintf "use '${0} [mode] --help' for mode specific details"
	commonPrintf ""
}

function _help_commit() {
	commonPrintf "usage:"
	commonPrintf "  $0 ${setArgs[mode]} <options>"
	commonPrintf ""
	commonPrintf "options:"
	commonPrintf "  -d --dry               dry mode don't do anything, use when you are willing to 'source' for functions, default: '${setArgs[dry]}'"
	commonPrintf "  -u --update [path]     path to the encodet config update default: '${setArgs[update]}'"
	commonPrintf "  -v --verbose           verbose output, default: '${setArgs[verbose]}'"
	commonPrintf ""
}

function _help_encode() {
	commonPrintf "usage:"
	commonPrintf "  $0 ${setArgs[mode]} <options>"
	commonPrintf ""
	commonPrintf "options:"
	commonPrintf "  -c --channel [name]    set [name] as channel id, default: '${setArgs[channel]}'"
	commonPrintf "  -d --dry               dry mode don't do anything, use when you are willing to 'source' for functions, default: '${setArgs[dry]}'"
	commonPrintf "  -M --moded [path]      file with the modified config, default: '${setArgs[moded]}'"
	commonPrintf "  -O --orig [path]       file with the current fetched config, default: '${setArgs[orig]}'"
	commonPrintf "  -o --output [path]     output file of encode, fetch and sign, default: '${setArgs[output]}'"
	commonPrintf "  -v --verbose           verbose output, default: '${setArgs[verbose]}'"
	commonPrintf ""
}

function _help_fetch() {
	commonPrintf "usage:"
	commonPrintf "  $0 ${setArgs[mode]} <options>"
	commonPrintf ""
	commonPrintf "options:"
	commonPrintf "  -c --channel [name]    set [name] as channel id, default: '${setArgs[channel]}'"
	commonPrintf "  -d --dry               dry mode don't do anything, use when you are willing to 'source' for functions, default: '${setArgs[dry]}'"
	commonPrintf "  -o --output [path]     output file of encode, fetch and sign, default: '${setArgs[output]}'"
	commonPrintf "  -v --verbose           verbose output, default: '${setArgs[verbose]}'"
	commonPrintf ""
}

function _help_sign() {
	commonPrintf "usage:"
	commonPrintf "  $0 ${setArgs[mode]} <options>"
	commonPrintf ""
	commonPrintf "options:"
	commonPrintf "  -d --dry               dry mode don't do anything, use when you are willing to 'source' for functions, default: '${setArgs[dry]}'"
	commonPrintf "  -u --update [path]     path to the encodet config update default: '${setArgs[update]}'"
	commonPrintf "  -v --verbose           verbose output, default: '${setArgs[verbose]}'"
	commonPrintf ""
}



# endregion: help
# region: mode

case "$1" in
	commit | encode | fetch | sign )
		setArgs[mode]=$1
		;;
	"help" | "-h" | "--help")
		_help
		exit 0
		;;
	*)
		commonVerify 1 "${0}: unrecognized mode '$1', see \`$0 help\` for instructions"
		;;
esac
shift

# endregion: mode
# region: getopt

_opts="c:dhi:M:o:O:U:v"
_lopts="channel:,dry,help,input:,moded:,orig:,output:,update:,verbose"
_args=$(getopt -n $0 -o $_opts -l $_lopts -a -Q -- "$@" 2>&1 )
commonVerify $? "${_args}, see \`$0 help\` for instructions" 
unset _opts _lopts _args

# endregion: getopt
# region: parse $@

while [ : ]; do
	case "$1" in
		-c | --channel)
			[[ ${setArgs[mode]} == sign ]] && commonVerify 1 "$1 parameter specified but not defined in ${setArgs[mode]} mode"
			setArgs[channel]="$2"
			shift 2
			;;
		-d | --dry)
			setArgs[dry]=true
			shift
			;;
		-h | --help)
			_help_${setArgs[mode]}
			exit 0
			;;
		-M | --moded)
			[[ ${setArgs[mode]} != encode ]] && commonVerify 1 "$1 parameter specified but not defined in ${setArgs[mode]} mode"
			setArgs[moded]="$2"
			shift 2
			;;
		-o | --output)
			[[ ${setArgs[mode]} == sign ]] && commonVerify 1 "$1 parameter specified but not defined in ${setArgs[mode]} mode"
			setArgs[output]="$2"
			shift 2
			;;
		-O | --orig)
			[[ ${setArgs[mode]} != encode ]] && commonVerify 1 "$1 parameter specified but not defined in ${setArgs[mode]} mode"
			setArgs[orig]="$2"
			shift 2
			;;
		-u | --update)
			[[ ${setArgs[mode]} != sign ]] && [[ ${setArgs[mode]} != commit ]] && commonVerify 1 "$1 parameter specified but not defined in ${setArgs[mode]} mode"
			setArgs[update]="$2"
			shift 2
			;;
		-v | --verbose)
			setArgs[verbose]=true
			shift
			;;
		--)
			shift
			break
			;;
		-*)
			commonVerify 1 "${0}: unrecognized option '${1}', see \`$0 help\` for instructions"
			;;
		*)
			break
			;;
	esac
done

# endregion: parse $@
# region: validate and dump settings

if [ ${setArgs[dry]} == false ]; then

	case ${setArgs[mode]} in
		commit )
			[ -z ${setArgs[update]} ] && commonVerify 1 "input must be set"
			[[ ! -r "${setArgs[update]}" ]] && commonVerify 1 "${0}: unable to read '${setArgs[orig]}'"
			;;
		encode )
			[ -z ${setArgs[orig]} ] && commonVerify 1 "input must be set"
			[ -z ${setArgs[moded]} ] && commonVerify 1 "input must be set"
			[[ ! -r "${setArgs[orig]}" ]] && commonVerify 1 "${0}: unable to read '${setArgs[orig]}'"
			[[ ! -r "${setArgs[moded]}" ]] && commonVerify 1 "${0}: unable to read '${setArgs[moded]}'"

			[ -z ${setArgs[output]} ] && commonVerify 1 "output must be set"
			touch ${setArgs[output]}
			commonVerify $? "${0}: unable to write '${setArgs[output]}'"
			;;
		fetch )
			[ -z ${setArgs[output]} ] && commonVerify 1 "output must be set"
			touch ${setArgs[output]}
			commonVerify $? "${0}: unable to write '${setArgs[output]}'"
			;;
		sign )
			[ -z ${setArgs[update]} ] && commonVerify 1 "input must be set"
			[[ ! -r "${setArgs[update]}" ]] && commonVerify 1 "${0}: unable to read '${setArgs[orig]}'"
			;;
		*)
			commonVerify 1 "${0}: unrecognized mode '$1', see \`$0 help\` for instructions"
			;;
	esac

fi

if [[ "${setArgs[verbose]}" == "true" ]]; then
	_sorted=($(echo "${!setArgs[@]}" | tr ' ' '\n' | sort))
	_args=()
	for _key in "${_sorted[@]}"; do
		_args+=("$_key -> ${setArgs[$_key]}")
	done
	commonPrintf "set args: $(commonJoinArray _args "\n%s" "")"

	unset _sorted _args _key
fi

# endregion: settings
# region: modes

function _commit() {
	export FABRIC_CFG_PATH=$TC_PATH_CHANNELS
	export CORE_PEER_LOCALMSPID="${TC_ORDERER1_STACK}MSP"
	export CORE_PEER_TLS_ROOTCERT_FILE=${TC_ORDERER1_DATA}/msp/tlscacerts/ca-cert.pem
	export CORE_PEER_MSPCONFIGPATH=$TC_ORDERER1_ADMINMSP
	export ORDERER_CA="${TC_ORDERER1_O1_TLSMSP}/tlscacerts/tls-0-0-0-0-${TC_COMMON1_C1_PORT}.pem"

	out=$( peer channel update -f "${setArgs[update]}" -c ${setArgs[channel]} -o localhost:${TC_ORDERER1_O1_PORT} --tls --cafile $ORDERER_CA  2>&1 )
	commonVerify $? "failed commit update $out" "update commited"

	unset out
}

function _encode() {
	local out_orig_pb=$( mktemp "${TMPDIR:-/tmp/}$(basename "$0")_${setArgs[mode]}_orig_pb.XXXXXXXXXXXX" )
	local out_moded_pb=$( mktemp "${TMPDIR:-/tmp/}$(basename "$0")_${setArgs[mode]}_moded_pb.XXXXXXXXXXXX" )
	local out_diff_pb=$( mktemp "${TMPDIR:-/tmp/}$(basename "$0")_${setArgs[mode]}_diff_pb.XXXXXXXXXXXX" )
	local out_diff_json=$( mktemp "${TMPDIR:-/tmp/}$(basename "$0")_${setArgs[mode]}_diff_json.XXXXXXXXXXXX" )
	local out_env_json=$( mktemp "${TMPDIR:-/tmp/}$(basename "$0")_${setArgs[mode]}_env_json.XXXXXXXXXXXX" )

	out=$( configtxlator proto_encode --input "${setArgs[orig]}" --type common.Config --output "$out_orig_pb" 2>&1 )
	commonVerify $? "failed to encode original config: $out" "current config encoded to protobuf format"
	out=$( configtxlator proto_encode --input "${setArgs[moded]}" --type common.Config --output "$out_moded_pb" 2>&1 )
	commonVerify $? "failed to encode modified config: $out" "modified config encoded to protobuf format"
	out=$( configtxlator compute_update --channel_id ${setArgs[channel]} --original "$out_orig_pb" --updated "$out_moded_pb" --output "$out_diff_pb" )
	commonVerify $? "failed to compute update: $out" "config update computed"
	out=$( configtxlator proto_decode --input "$out_diff_pb" --type common.ConfigUpdate --output "$out_diff_json" 2>&1 )
	commonVerify $? "failed to decode update: $out" "config update decoded"
	echo '{"payload":{"header":{"channel_header":{"channel_id":"'${setArgs[channel]}'", "type":2}},"data":{"config_update":'$(cat $out_diff_json)'}}}' | jq . > "$out_env_json"
	commonVerify $? "failed to envelope update: $out" "config update enveloped"
	out=$( configtxlator proto_encode --input "$out_env_json" --type common.Envelope --output "${setArgs[output]}" 2>&1 )
	commonVerify $? "failed to encode enveloped update: $out" "config update encoded"

	rm "$out_orig_pb"
	rm "$out_moded_pb"
	rm "$out_diff_pb"
	rm "$out_diff_json"
	rm "$out_env_json"
	unset out
}

function _fetch() {
	export CORE_PEER_LOCALMSPID="${TC_ORG1_STACK}MSP"
	export CORE_PEER_MSPCONFIGPATH=$TC_ORG1_ADMINMSP
	export CORE_PEER_TLS_ENABLED=true
	export CORE_PEER_TLS_ROOTCERT_FILE=${TC_ORG1_DATA}/msp/tlscacerts/ca-cert.pem
	export FABRIC_CFG_PATH=$TC_PATH_CHANNELS

	local certOrderer="${TC_ORDERER1_O1_TLSMSP}/tlscacerts/tls-0-0-0-0-${TC_COMMON1_C1_PORT}.pem" 
	local out_pb=$( mktemp "${TMPDIR:-/tmp/}$(basename "$0")_${setArgs[mode]}_pb.XXXXXXXXXXXX" )
	local out_json=$( mktemp "${TMPDIR:-/tmp/}$(basename "$0")_${setArgs[mode]}_json.XXXXXXXXXXXX" )

	out=$( peer channel fetch config $out_pb -o localhost:${TC_ORDERER1_O1_PORT} -c ${setArgs[channel]} --tls --cafile $certOrderer 2>&1 )
	commonVerify $? "failed to fetch config: $out" "fetch succeeded"
	out=$( configtxlator proto_decode --input $out_pb --type common.Block --output $out_json 2>&1 )
	commonVerify $? "failed to decode config protobuf: $out" "configtxlator succeeded"
	out=$( jq ".data.data[0].payload.data.config" $out_json > ${setArgs[output]} )
	commonVerify $? "failed to unwrap config: $out" "unwrap succeeded"

	rm $out_pb
	rm $out_json
	unset out
}

function _sign() {
	# orderer1
	# export CORE_PEER_ADDRESS=localhost:${TC_ORG1_P1_PORT}
	export CORE_PEER_LOCALMSPID="${TC_ORDERER1_STACK}MSP"
	export CORE_PEER_MSPCONFIGPATH=$TC_ORDERER1_ADMINMSP
	export CORE_PEER_TLS_ENABLED=true
	export CORE_PEER_TLS_ROOTCERT_FILE=${TC_ORDERER1_DATA}/msp/tlscacerts/ca-cert.pem
	export FABRIC_CFG_PATH=$TC_PATH_CHANNELS

	peer channel signconfigtx -f "${setArgs[update]}"
	commonVerify $? "failed to sign update by ${TC_ORDERER1_ADMIN}" "${TC_ORDERER1_ADMIN} signed the update"

	# org1
	# export CORE_PEER_ADDRESS=localhost:${TC_ORG1_P1_PORT}
	export CORE_PEER_LOCALMSPID="${TC_ORG1_STACK}MSP"
	export CORE_PEER_MSPCONFIGPATH=$TC_ORG1_ADMINMSP
	export CORE_PEER_TLS_ENABLED=true
	export CORE_PEER_TLS_ROOTCERT_FILE=${TC_ORG1_DATA}/msp/tlscacerts/ca-cert.pem
	export FABRIC_CFG_PATH=$TC_PATH_CHANNELS

	peer channel signconfigtx -f "${setArgs[update]}"
	commonVerify $? "failed to sign update by ${TC_ORG1_ADMIN}" "${TC_ORG1_ADMIN} signed the update"

	# org2
	# export CORE_PEER_ADDRESS=localhost:${TC_ORG2_P1_PORT}
	export CORE_PEER_LOCALMSPID="${TC_ORG2_STACK}MSP"
	export CORE_PEER_MSPCONFIGPATH=$TC_ORG2_ADMINMSP
	export CORE_PEER_TLS_ENABLED=true
	export CORE_PEER_TLS_ROOTCERT_FILE=${TC_ORG2_DATA}/msp/tlscacerts/ca-cert.pem
	export FABRIC_CFG_PATH=$TC_PATH_CHANNELS	

	peer channel signconfigtx -f "${setArgs[update]}"
	commonVerify $? "failed to sign update by ${TC_ORG2_ADMIN} admin" "${TC_ORG2_ADMIN} admin signed the update"

	# org1
	# export CORE_PEER_ADDRESS=localhost:${TC_ORG3_P1_PORT}
	export CORE_PEER_LOCALMSPID="${TC_ORG3_STACK}MSP"
	export CORE_PEER_MSPCONFIGPATH=$TC_ORG3_ADMINMSP
	export CORE_PEER_TLS_ENABLED=true
	export CORE_PEER_TLS_ROOTCERT_FILE=${TC_ORG3_DATA}/msp/tlscacerts/ca-cert.pem
	export FABRIC_CFG_PATH=$TC_PATH_CHANNELS	

	peer channel signconfigtx -f "${setArgs[update]}" 2>&1
	commonVerify $? "failed to sign update by ${TC_ORG3_ADMIN} admin" "${TC_ORG3_ADMIN} admin signed the update"

	unset out
}

# endregion: modes
# region: exec and out

[[ "$TC_EXEC_DRY" == false ]] && _${setArgs[mode]}

if [[ "${setArgs[verbose]}" == "true" ]]; then	
	commonPrintf ""
	commonPrintf "${setArgs[mode]} is done"
	commonPrintf ""
fi

# endregion: out
