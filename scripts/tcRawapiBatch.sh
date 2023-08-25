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
setArgs[host]="http://localhost:5088"
setArgs[func]="CreateBundle"
setArgs[inplace]=false
setArgs[invoke]="/invoke"
setArgs[key]=".bundle_id"
setArgs[mode]=false
setArgs[position]=0
setArgs[output]="/dev/stdout"
setArgs[query]="/query"
setArgs[txid]=".tx_id"
setArgs[txidpat]="^[a-fA-F0-9]{64}$"
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
	"confirm")
		setArgs[mode]=$1
		;;
	"help")
		_help
		exit 0
		;;
	"resubmit")
		setArgs[mode]=$1
		;;
	"submit")
		setArgs[mode]=$1
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

# region: in/out

# input
[[ ! -r "${setArgs[bundle]}" ]] && commonVerify 1 "${0}: unable to read '${setArgs[bundle]}'"

# output
touch ${setArgs[output]}
commonVerify $? "${0}: unable to write '${setArgs[output]}'"

# submit input/output
if [[ "${setArgs[mode]}" == "submit" ]] && [ "${setArgs[bundle]}" = "${setArgs[output]}" ]; then
	commonVerify 1 "${0}: input and output cannot be the same in 'submit' mode, in-place update is not available"
fi

# in-place update
if [[ ! "${setArgs[mode]}" == "submit" ]] && [ "${setArgs[bundle]}" = "${setArgs[output]}" ]; then
	setArgs[inplace]=true
	setArgs[output]=$( mktemp "${TMPDIR:-/tmp/}$(basename "$0").XXXXXXXXXXXX" )
fi


# endregion: in/out
# region: key position

if [[ (! "${setArgs[position]}" =~ ^[0-9]+$ ) || ( "${setArgs[position]}" -lt 0 ) ]] && [[ "${setArgs[mode]}" != "confirm" ]]; then
	commonVerify 1 "${0}: -p must be a positive integer, see \`$0 --help\` for instructions"
fi

# endregion: key position
# region: dump

if [[ "${setArgs[verbose]}" == "true" ]]; then
	_sorted=($(echo "${!setArgs[@]}" | tr ' ' '\n' | sort))
	_args=()
	for _key in "${_sorted[@]}"; do
		_args+=("$_key -> ${setArgs[$_key]}")
	done
	commonPrintf "set args: $(commonJoinArray _args "\n%s" "")"

	unset _sorted _args _key
fi

# endregion: dump

# endregion: settings
# region: common functions

function dump() {
	local -n _dump=$1
	echo $( commonJoinArray _dump "%s|" "|" ) >> ${setArgs[output]}
}

# endregion: common functions
# region: submit

function submit() {
	
	# region: prepare

	# progress
	((cnt++)); local progress="_submit(): ${cnt}/${sum} ->"

	# output -> [0]: status [1]: key [2]: tx_id [3]: response [4]: payload
	local output=()

	# args
	local args=()
	IFS="|" read -ra args <<< "$1"
	output[4]=$( commonJoinArray args "%s|" "|" )

	# endregion: prepare
	# region: key

	output[1]=$( echo "${args[${setArgs[position]}]}" | jq -r ${setArgs[key]}  2>&1 )
	if [ $? -ne 0 ] || [ -z ${output[1]} ] || [ "${output[1]}" == "null" ]; then
		output[0]="SUBMIT_ERROR_KEY"
		output[2]=""
		output[3]=""
		dump output
		[[ "${setArgs[verbose]}" == "true" ]] && commonPrintf "$progress no ${setArgs[key]} found in ${args[${setArgs[position]}]}"
		return
	fi

	# endregion: key
	# region: submit

	local data=$( commonJoinArray args "args=%s&" "&")
	local response
	response=$( curl	-s -S -w "\n%{http_code}" -X POST									\
						--header "Content-Type: application/x-www-form-urlencoded"	\
						--header "${setArgs[apikey]}"								\
						--data-urlencode "chaincode=${setArgs[cc]}"					\
						--data-urlencode "channel=${setArgs[channel]}"				\
						--data-urlencode "function=${setArgs[func]}"				\
						--data-urlencode "$data"									\
						${setArgs[host]}${setArgs[invoke]} 2>&1 )
	if [[ $? -ne 0 ]]; then
		output[0]="SUBMIT_ERROR_CONNECT"
		output[2]=""
		output[3]=${response//$'\n'/}
		dump output
		[[ "${setArgs[verbose]}" == "true" ]] && commonPrintf "$progress unable to connect ${setArgs[host]}"
		return
	fi
		
	# endregion: submit
	# region: process

	# split the response into status_code and content
	output[0]=$( echo "$response" | tail -n 1 )
	output[3]=$( echo "$response" | sed '$d' ); body="${body//$'\n'/ }"

	# get tx_id
	output[2]=$(echo "${output[3]}" | jq -r ${setArgs[txid]} 2>&1 )
	if [ $? -ne 0 ] || [[ ! ${output[2]} =~ ${setArgs[txidpat]} ]]; then
		output[0]="SUBMIT_ERROR_TXID_"${output[0]}
		dump output
		[[ "${setArgs[verbose]}" == "true" ]] && commonPrintf "$progress ${status}, no ${setArgs[txid]} found"
		return	
	fi

	# success
	output[0]="SUBMIT_"${output[0]}
	dump output
	output=("${output[@]:0:3}")
	[[ "${setArgs[verbose]}" == "true" ]] && commonPrintf "$progress `echo $( commonJoinArray output "%s -> " "" )` success"

	# endregion: process

}

# endregion: submit
# region: resubmit

# endregion: resubmit
# region: confirm

function confirm() {

	# region: prepare

	# progress
	((cnt++)); local progress="_submit(): ${cnt}/${sum} ->"

	# output -> [0]: status [1]: key [2]: tx_id [3]: response [4->]: original payload
	local output=()
	IFS="|" read -ra output <<< "$1"

	# endregion: prepare
	# region: status

	if [ "${output[0]}" != "SUBMIT_200" ] && [[ ! "${output[0]}" =~ ^CONFIRM_ERROR_ ]]; then
		dump output
		[[ "${setArgs[verbose]}" == "true" ]] && commonPrintf "$progress bypassed status (${output[0]})"
		return	
	fi

	# endregion: status
	# region: txid

	if [[ ! ${output[2]} =~ ${setArgs[txidpat]} ]]; then
		output[0]="CONFIRM_ERROR_TXID"
		dump output
		[[ "${setArgs[verbose]}" == "true" ]] && commonPrintf "$progress ${output[0]} (${output[2]})"
		return	
	fi

	# endregion: txid
	# region: request

	local url="${setArgs[host]}${setArgs[query]}?"
	url+="channel=${setArgs[channel]}&"
	url+="chaincode=qscc&function=GetBlockByTxID&"
	url+="args=${setArgs[channel]}&"
	url+="args=${output[2]}&"
	url+="proto_decode=common.Block"

	local response
	response=$( curl -s -S -w "\n%{http_code}" --header "${setArgs[apikey]}" "$url" 2>&1 )
	if [[ $? -ne 0 ]]; then
		output[0]="CONFIRM_ERROR_CONNECT"
		output[3]=${response//$'\n'/}
		dump output
		[[ "${setArgs[verbose]}" == "true" ]] && commonPrintf "$progress ${output[0]} (${output[3]})"
		return
	fi

	# endregion: request
	# region: process

	# split the response into status_code and content
	local status=$( echo "$response" | tail -n 1 )
	output[3]=$( echo "$response" | sed '$d' | tr -d '\n' )

	# check status
	if [[ "$status" != "200" ]]; then
		output[0]="CONFIRM_ERROR_${status}"
		dump output
		[[ "${setArgs[verbose]}" == "true" ]] && commonPrintf "$progress ${output[0]} (${output[3]})"
		return
	fi

	# check for header
	output[3]=$( echo ${output[3]} | jq -r -c .result.header 2>&1 )
	if [ $? -ne 0 ] || [ -z ${output[3]} ] || [ "${output[3]}" = "null" ]; then
		output[0]="CONFIRM_ERROR_HEADER"
		output[3]=$( echo ${output[3]} | tr -d '\n' )
		dump output
		[[ "${setArgs[verbose]}" == "true" ]] && commonPrintf "$progress ${output[0]} (${output[3]})"
		return	
	fi

	# done
	output[0]="CONFIRM_${status}"
	dump output
	output=("${output[@]:0:3}")
	[[ "${setArgs[verbose]}" == "true" ]] && commonPrintf "$progress `echo $( commonJoinArray output "%s -> " "" )` success"

	# endregion: process

}

# endregion: confirm
# region: loop

cnt=0

if [[ "${setArgs[bundle]}" == "/dev/stdin" ]]; then
	sum="-"
	while IFS= read -r line; do
		${setArgs[mode]} "$line"
	done
else
	sum=$( wc -l ${setArgs[bundle]} | sed 's/ .*$//' )
	while IFS= read -r line; do
		${setArgs[mode]} "$line"
	done < "${setArgs[bundle]}" 
fi

# endregion: loopt
# region: in-place

if [[ "${setArgs[inplace]}" == "true" ]]; then
	replace=$( mv ${setArgs[output]} ${setArgs[bundle]} 2>&1 )
	commonVerify $? "failed to update in-place confirmed batch: $replace"
fi

# endregion: in-place
# region: out

if [[ "${setArgs[verbose]}" == "true" ]]; then	
	commonPrintf ""
	commonPrintf "${setArgs[mode]} is done"
	commonPrintf ""
fi

# endregion: out
