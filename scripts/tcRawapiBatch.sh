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
commonPP $TC_PATH_SCRIPTS

# endregion: common
# region: defaults

declare -A setArgs
setArgs[apikey]="X-API-Key: $TC_HTTP_API_KEY"
setArgs[bundle]="./bundle.csv"
setArgs[cc]="te-food-bundles"
setArgs[channel]="trustchain-test"
setArgs[confirm]=true
setArgs[host]="http://localhost:5088"
setArgs[func]="CreateBundle"
setArgs[invoke]="/invoke"
setArgs[key]="bundle_id"
setArgs[position]=0
setArgs[output]="./out.csv"
setArgs[query]="/query"
setArgs[submit]=true

# endregion: defaults
# region: help

function _help() {
	commonPrintf "usage:"
	commonPrintf "  $0 [mode] <options>"
	commonPrintf ""
	commonPrintf "modes:"
	commonPrintf "  submit     iterate over input batch and submit line by line"
	commonPrintf "  confirm    iterate over input batch and query for block number and data hash against qscc's GetBlockByTxID()"
	commonPrintf "  both       both above"
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
	commonPrintf "  -k --key [name]        unique id in input, default: \"${setArgs[key]}\""
	commonPrintf "  -o --output [file]     output of submit, input for confirm, default: \"${setArgs[output]}\""
	commonPrintf "  -p --position [N]      field which contains JSON with -k, default: \"${setArgs[position]}\""
	commonPrintf "  -q --query [name]      query endpoint form confirmation, default: \"${setArgs[query]}\""
	commonPrintf ""
}

# endregion: help
# region: mode

setMode=$1; shift
case "$setMode" in
	"submit")
		setArgs[confirm]=false
		setArgs[submit]=true
		;;
	"confirm")
		setArgs[confirm]=true
		setArgs[submit]=false
		;;
	"both")
		setArgs[confirm]=true
		setArgs[submit]=true
		;;
	"help")
		_help
		exit 0
		;;
	*)
		_help
		commonVerify 1 "invalid mode: $setMode"
		;;
esac

# endregion: mode
# region: getopt

_opts="a:b:c:C:f:hH:i:k:o:p:q:"
_lopts="apikey:,bundle:,channel:,chaincode:,func:,help,host:,invoke:,key:,output:,position:,query:"
_args=$(getopt -n $0 -o $_opts -l $_lopts -a -Q -- "$@" 2>&1 )
if [ $? -ne 0 ]; then
	_help
	commonVerify 1 "set args: $_args"
fi
_args=$(getopt -n $0 -o $_opts -l $_lopts -a -q -- "$@" 2>&1 )
eval set -- "$_args"
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
		--)
			shift
			break
			;;
		-*)
			_help
			commonVerify 1 "unrecognized option $1"
			;;
		*)
			break
			;;
	esac
done

# endregion: parse $@
# region: validate and dump settings

# input
if [[ ! -r "${setArgs[bundle]}" ]]; then
	commonVerify 1 "unable to open ${setArgs[bundle]}"
fi

# output
touch ${setArgs[output]}
commonVerify $? "failed to open ${setArgs[output]}"

# key position
if [[ ! "${setArgs[position]}" =~ ^[0-9]+$ ]] || [[ "${setArgs[position]}" -lt 0 ]]; then
	commonVerify 1 "-p must be a positive integer"
fi

# dump
_sorted=($(echo "${!setArgs[@]}" | tr ' ' '\n' | sort))
_args=()
for _key in "${_sorted[@]}"; do
	_args+=("$_key -> ${setArgs[$_key]}")
done
commonPrintf "set mode: $setMode"
commonPrintf "set args: $(commonJoinArray _args "\n%s" "")"
unset _sorted _args _key

# endregion: settings
# region: submit

declare -A op
op[sum]=$( wc -l ${setArgs[bundle]} | sed 's/ .*$//' )
op[cnt]=0
while IFS= read -r _line; do

	# progress
	((op[cnt]++))
	_progress="${op[cnt]}/${op[sum]}"

	# args
	IFS="|" read -ra _args <<< "$_line"

	# set unique id
	_id=$( echo "${_args[${setArgs[position]}]}" | jq .${setArgs[key]} )
	if [ -z $_id ] || [ "$_id" = "null" ]; then
		echo "000||${_line}" >> ${setArgs[output]} 
		commonPrintf "$_progress: no ${setArgs[key]} found"
		continue
	fi

	# TODO: FÜGGVÉNYBE!

	commonPrintf "$_progress $_id"
	response=$(	curl	-s -w "\n%{http_code}" -X POST					\
						--header "Content-Type: application/x-www-form-urlencoded" \
						--header "${setArgs[apikey]}"					\
						--data-urlencode "chaincode=${setArgs[apikey]}"	\
						--data-urlencode "channel=${setArgs[channel]}"	\
						--data-urlencode "function=${setArgs[func]}"	\
						${setArgs[host]}${setArgs[invoke]} )

						# --data-urlencode "args=${line}"					\
	# # split the response into status_code and content
	# http_status=$(echo "$response" | tail -n 1)
	# tx_id=$(echo "$response" | sed '$d' | jq .tx_id)

	# if [[ "$http_status" == "200" ]]; then
	# 	echo "$bundle_id,$tx_id" >> $output
	# else
	# 	echo "$line" >> $error
	# fi
	# ((cnt++))
	# commonPrintf "submited ${cnt}/${sum}	$bundle_id: ${http_status}/${tx_id}"

	unset _line _progress _id
done < "${setArgs[bundle]}"
unset op
exit

# endregion: submit
# region: confirm

while IFS= read -r line; do
	IFS="|" read -r bundle_id tx_id confirmation <<< "$line";
	commonPrintf "$bundle_id -> $tx_id -> $confirmation"
	if [[ -z $confirmation ]]; then
		commonPrintf "unconfirmed"
	fi
	# curl --location 'http://3.77.27.176:5088/query?channel=trustchain-test&chaincode=qscc&function=GetBlockByTxID&args=trustchain-test&args=740ddfeb34a0bf7f69445875e43ee95a04d1dec649068ec9a0f1ea836e5c7762&proto_decode=common.Block'
	# response=$(	curl	-s -w "\n%{http_code}" -X GET					\
	# 					--header "X-API-Key: $TC_HTTP_API_KEY"			\
	# 					--data-urlencode "chaincode=te-food-bundles"	\
	# 					--data-urlencode "channel=trustchain-test"		\
	# 					--data-urlencode "function=CreateBundle"		\
	# 					--data-urlencode "args=${line}"					\
	# 					http://localhost:5088/ )

	# # split the response into status_code and content
	# http_status=$(echo "$response" | tail -n 1)
	# tx_id=$(echo "$response" | sed '$d' | jq .tx_id)

	# if [[ "$http_status" == "200" ]]; then
	# 	echo "$bundle_id,$tx_id" >> $output
	# else
	# 	echo "$line" >> $error
	# fi
	# commonPrintf "$bundle_id: ${http_status}/${tx_id}"
done < "$output"

# endregion: confirm
