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

export COMMON_PANIC=true

declare -A setArgs
setArgs[apikey]="X-API-Key: $TC_HTTP_API_KEY"
setArgs[bundle]="./bundle.csv"
setArgs[cc]="te-food-bundles"
setArgs[channel]="trustchain-test"
setArgs[confirm]=true
setArgs[host]="http://localhost:5088"
setArgs[func]="CreateBundle"
setArgs[invoke]="/invoke"
setArgs[key]=".bundle_id"
setArgs[position]=0
setArgs[output]="/dev/stdout"
setArgs[query]="/query"
setArgs[submit]=false
setArgs[txid]=".tx_id"
setArgs[verbose]=false

# endregion: defaults
# region: help

function _help() {
	commonPrintf "usage:"
	commonPrintf "  $0 [mode] <options>"
	commonPrintf ""
	commonPrintf "modes:"
	commonPrintf "  submit     iterate over input batch and submit line by line"
	commonPrintf "  confirm    iterate over input batch and query for block number and data hash against qscc's GetBlockByTxID()"
	commonPrintf "  help       prints this quits"
	commonPrintf ""
	commonPrintf "options:"
	commonPrintf "  -a --apikey [string]   api key in header, default: \"X-API-Key: \$TC_HTTP_API_KEY\""
	commonPrintf "  -b --bundle [file]     | separated file with args for invoke, default: \"${setArgs[bundle]}\""
	commonPrintf "  -c --channel [name]    set [name] as channel id, default: \"${setArgs[channel]}\""
	commonPrintf "  -C --chaincode [name]  chaincode name for submit, default: \"${setArgs[cc]}\""
	commonPrintf "  -f --func [name]       -C's function for submit, default \"${setArgs[func]}\""
	commonPrintf "  -h --help              prints this and quits"
	commonPrintf "  -H --host              api host in http(s)://host:port format, default \"${setArgs[host]}\""
	commonPrintf "  -i --invoke [name]     invoke endpoint for submit, default: \"${setArgs[invoke]}\""
	commonPrintf "  -k --key [name]        jq's path to unique id in input, default: \"${setArgs[key]}\""
	commonPrintf "  -o --output [file]     output of submit, input for confirm, default: \"${setArgs[output]}\""
	commonPrintf "  -p --position [N]      field which contains JSON with -k, default: \"${setArgs[position]}\""
	commonPrintf "  -q --query [name]      query endpoint form confirmation, default: \"${setArgs[query]}\""
	commonPrintf "  -t --txid [path]       jq's path for transaction id, default: \"${setArgs[txid]}\""
	commonPrintf "  -v --verbose           verbose output, default \"${setArgs[verbose]}\""
	commonPrintf ""
}

# endregion: help
# region: mode

case "$1" in
	"submit")
		setArgs[confirm]=false
		setArgs[submit]=true
		;;
	"confirm")
		setArgs[confirm]=true
		setArgs[submit]=false
		;;
	"help")
		_help
		exit 0
		;;
	*)
		commonVerify 1 "${0}: unrecognized mode '$1', see \`$0 --help\` for instructions"
		;;
esac
shift

# endregion: mode
# region: getopt

_opts="a:b:c:C:f:hH:i:k:o:p:q:t:v"
_lopts="apikey:,bundle:,channel:,chaincode:,func:,help,host:,invoke:,key:,output:,position:,query:,txid:,verbose"
_args=$(getopt -n $0 -o $_opts -l $_lopts -a -Q -- "$@" 2>&1 )
commonVerify $? "${_args}, see \`$0 --help\` for instructions" 
# _args=$(getopt -n $0 -o $_opts -l $_lopts -a -q -- "$@" 2>&1 )
# eval set -- "$_args"
unset _opts _lopts _args

# endregion: getopt
# region: parse $@

while [ : ]; do
	case "$1" in
		-a | --apikey)
			setArgs[apikey]="$2"
			shift 2
			;;
		-b | --bundle)
			setArgs[bundle]="$2"
			shift 2
			;;
		-c | --channel)
			setArgs[channel]="$2"
			shift 2
			;;
		-C | --chainCode)
			setArgs[cc]="$2"
			shift 2
			;;
		-f | --func)
			setArgs[func]="$2"
			shift 2
			;;
		-h | --help)
			_help
			exit 0
			;;
		-i | --invoke)
			setArgs[invoke]="$2"
			shift 2
			;;
		-H | --host)
			setArgs[host]="$2"
			shift 2
			;;
		-k | --key)
			setArgs[key]="$2"
			shift 2
			;;
		-o | --output)
			setArgs[output]="$2"
			shift 2
			;;
		-p | --position)
			setArgs[position]="$2"
			shift 2
			;;
		-q | --query)
			setArgs[query]="$2"
			shift 2
			;;
		-t | --txid)
			setArgs[txid]="$2"
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
			commonVerify 1 "${0}: unrecognized option '${1}', see \`$0 --help\` for instructions"
			;;
		*)
			break
			;;
	esac
done

# endregion: parse $@
# region: validate and dump settings

# input
if [[ ! -r "${setArgs[bundle]}" ]] && [[ "${setArgs[submit]}" == "true" ]]; then
	commonVerify 1 "${0}: unable to read '${setArgs[bundle]}'"
fi

# output
touch ${setArgs[output]}
commonVerify $? "${0}: unable to write '${setArgs[output]}'"

# key position
if [[ (! "${setArgs[position]}" =~ ^[0-9]+$ ) || ( "${setArgs[position]}" -lt 0 ) ]] && [[ "${setArgs[submit]}" == "true" ]]; then
	commonVerify 1 "${0}: -p must be a positive integer, see \`$0 --help\` for instructions"
fi

# dump
if [[ "${setArgs[verbose]}" == "true" ]]; then

	# mode
	_sorted=("confirm" "submit")
	_args=()
	for _key in "${_sorted[@]}"; do
		_args+=("$_key -> ${setArgs[$_key]}")
	done
	commonPrintf "set mode: $(commonJoinArray _args "\n%s" "")"

	# opts
	_sorted=($(echo "${!setArgs[@]}" | tr ' ' '\n' | sort))
	_args=()
	for _key in "${_sorted[@]}"; do
		[[ "$_key" == "confirm" ]] && continue
		[[ "$_key" == "submit" ]] && continue
		_args+=("$_key -> ${setArgs[$_key]}")
	done
	commonPrintf "set args: $(commonJoinArray _args "\n%s" "")"

	unset _sorted _args _key
fi

# endregion: settings
# region: submit

function _submit() {

	local cnt=0
	local sum="-"
	
	_inner() {

		# progress
		((cnt++)); local progress="_submit() ${cnt}/${sum}"

		# args
		IFS="|" read -ra _args <<< "$1"

		# set unique id
		_id=$( echo "${_args[${setArgs[position]}]}" | jq -r ${setArgs[key]}  2>&1 )
		if [ $? -ne 0 ] || [ -z $_id ] || [ "$_id" = "null" ]; then
			echo "NO_KEY_FOUND|||${line}" >> ${setArgs[output]} 
			[[ "${setArgs[verbose]}" == "true" ]] && commonPrintf "$progress: no ${setArgs[key]} found"
			return
		fi

		# submit
		local data=$( commonJoinArray _args "args=%s&" "&")
		_response=$( curl	-s -w "\n%{http_code}" -X POST						\
							--header "Content-Type: application/x-www-form-urlencoded" \
							--header "${setArgs[apikey]}"						\
							--data-urlencode "chaincode=${setArgs[cc]}"	\
							--data-urlencode "channel=${setArgs[channel]}"		\
							--data-urlencode "function=${setArgs[func]}"		\
							--data-urlencode "$data"							\
							${setArgs[host]}${setArgs[invoke]} 2>&1 )
		if [[ $? -ne 0 ]]; then
			echo "UNABLE_TO_CONNECT|${_id}||${line}" >> ${setArgs[output]}
			[[ "${setArgs[verbose]}" == "true" ]] && commonPrintf "$progress: unable to connect ${setArgs[host]}"
			return
		fi

		# split the response into status_code and content
		local status=$( echo "$_response" | tail -n 1 )
		local body=$( echo "$_response" | sed '$d' ); body="${body//$'\n'/ }"

		# get tx_id
		_txid=$(echo "$body" | jq -r ${setArgs[txid]} 2>&1 )
		if [ $? -ne 0 ] || [ -z $_txid ] || [ "$_txid" = "null" ]; then
			[[ "$status" == "200" ]] && echo "NO_TXID_200|${_id}||${body}" >> ${setArgs[output]} 
			[[ "$status" != "200" ]] && echo "NO_TXID_NO_200|${_id}||${body}" >> ${setArgs[output]} 
			[[ "${setArgs[verbose]}" == "true" ]] && commonPrintf "$progress: ${status}, no ${setArgs[txid]} found"
			return	
		fi

		# success
		echo "${status}|${_id}|${_txid}|${body}" >> ${setArgs[output]}
		[[ "${setArgs[verbose]}" == "true" ]] && commonPrintf "$progress: ${status}, $_txid"

		unset _response _id _txid _args
	}

	if [[ "${setArgs[bundle]}" == "/dev/stdin" ]]; then
		while IFS= read -r _line; do
			_inner "$_line"
		done
	else
		local sum=$( wc -l ${setArgs[bundle]} | sed 's/ .*$//' )
		while IFS= read -r line; do
			_inner "$_line"
		done < "${setArgs[bundle]}" 
	fi 

	if [[ "${setArgs[verbose]}" == "true" ]]; then	
		commonPrintf ""
		commonPrintf "_submit() is done"
		commonPrintf ""
	fi
}
[[ "${setArgs[submit]}" == "true" ]] && _submit
unset _inner _submit _line

# endregion: submit
# region: confirm

function _confirm() {

	local cnt=0
	local sum="-"
	
	_inner() {

		# progress
		((cnt++)); local progress="_confirm() ${cnt}/${sum}"

		# args
		IFS="|" read -ra _args <<< "$1"
		local status=${_args[0]}
		local key=${_args[1]}
		local txid=${_args[2]}
		local data=${_args[3]}

		# status
		if [ -z "$status" ] || [ "$status" != "200" ]; then
			[[ "${setArgs[verbose]}" == "true" ]] && commonPrintf "$progress: status != 200"
			return	
		fi

		# txid
		if [ -z "$txid" ] || [ "$txid" = "null" ]; then
			echo "NO_TX_ID|${key}|${txid}|${data}" >> ${setArgs[output]}
			[[ "${setArgs[verbose]}" == "true" ]] && commonPrintf "$progress: no tx id"
			return	
		fi

		# confirm
		local url="${setArgs[host]}${setArgs[query]}?"
		url+="channel=${setArgs[channel]}&"
		url+="chaincode=qscc&function=GetBlockByTxID&"
		url+="args=${setArgs[channel]}&"
		url+="args=${txid}&"
		url+="proto_decode=common.Block"
		commonPrintfBold $url
		_response=$( curl -s -w "\n%{http_code}" --header "${setArgs[apikey]}" "$url" 2>&1 )
		if [[ $? -ne 0 ]]; then
			echo "UNABLE_TO_CONNECT|${key}|${txid}|${data}" >> ${setArgs[output]}
			[[ "${setArgs[verbose]}" == "true" ]] && commonPrintf "$progress: unable to connect ${setArgs[host]}"
			return
		fi

		# split the response into status_code and content
		local status=$( echo "$_response" | tail -n 1 )
		local body=$( echo "$_response" | sed '$d' ); body="${body//$'\n'/ }"

		# header
		_header=$(echo "$body" | jq -r -c .result.header 2>&1 )
		if [ $? -ne 0 ] || [ -z $_header ] || [ "$_header" = "null" ]; then
			[[ "$status" == "200" ]] && echo "NO_HEADER_200|${key}|${txid}|${body}" >> ${setArgs[output]} 
			[[ "$status" != "200" ]] && echo "NO_HEADER_NO_200|${key}|${txid}|${body}" >> ${setArgs[output]} 
			[[ "${setArgs[verbose]}" == "true" ]] && commonPrintf "$progress: ${status}, no block header found"
			return	
		fi

		success
		echo "${status}|${key}|${txid}|${_header}" >> ${setArgs[output]}
		[[ "${setArgs[verbose]}" == "true" ]] && commonPrintf "$progress: ${status}, $txid"

		unset _args _response _header
	}

	if [[ "${setArgs[bundle]}" == "/dev/stdin" ]]; then
		while IFS= read -r _line; do
			_inner "$_line"
		done
	else
		local sum=$( wc -l ${setArgs[bundle]} | sed 's/ .*$//' )
		while IFS= read -r line; do
			_inner "$_line"
		done < "${setArgs[bundle]}" 
	fi 
	
	if [[ "${setArgs[verbose]}" == "true" ]]; then	
		commonPrintf ""
		commonPrintf "_confirm() is done"
		commonPrintf ""
	fi

}
[[ "${setArgs[confirm]}" == "true" ]] && _confirm
unset _inner _confirm _line

# endregion: confirm
