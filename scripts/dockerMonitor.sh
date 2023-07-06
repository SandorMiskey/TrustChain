#!/bin/bash

#
# Copyright TE-FOOD International GmbH., All Rights Reserved
#

[[ ${COMMON_FUNCS:-"unset"} == "unset" ]] && COMMON_FUNCS=${COMMON_BASE}/commonFuncs.sh
if [ ! -f  $COMMON_FUNCS ]; then
	echo "=> COMMON_FUNCS ($COMMON_FUNCS) not found, make sure proper path is set or you execute this from the repo's 'scrips' directory!"
	exit 1
fi
source $COMMON_FUNCS

# if [[ ${COMMON_BASE:-"unset"} == "unset" ]]; then
# 	commonVerify 1 "COMMON_BASE is unset"
# fi
# commonPP $COMMON_BASE
commonPP .

#

re='^[0-9]+$'
port="$1"
[[ -z $port ]] && port=5055
[[ $port =~ $re ]] || commonVerify 1 "usage: $0 [optional port, must be a number]"

#

_logspout() {
	docker kill logspout 2> /dev/null 1>&2 || true
	docker rm logspout 2> /dev/null 1>&2 || true

	trap "docker kill logspout" SIGINT

	docker run -d --rm --name="logspout"					\
		--volume=/var/run/docker.sock:/var/run/docker.sock	\
 		--publish=127.0.0.1:${port}:80						\
	 	gliderlabs/logspout

	commonSleep 3
}
commonYN "spin up logspout?" _logspout

curl http://127.0.0.1:${port}/logs

unset re
unset port
