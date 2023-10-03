// region: packages

package main

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io/fs"
	"log/syslog"
	"math"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"reflect"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/SandorMiskey/TEx-kit/cfg"
	"github.com/SandorMiskey/TEx-kit/log"
	"github.com/SandorMiskey/TrustChain/migration/fabric"
	"github.com/buger/jsonparser"
	"github.com/hyperledger/fabric-gateway/pkg/client"
	"github.com/valyala/fasthttp"
	// "github.com/SandorMiskey/TrustChain/migration/psv"
	// "github.com/davecgh/go-spew/spew"
)

// endregion: packages
// region: globals

var (
	BlockCache      = make(map[string]Header)
	BlockCacheMutex = sync.RWMutex{}

	Def_FabCert        string        = "./cert.pem"
	Def_FabCcConfirm   string        = "qscc"
	Def_FabCcSubmit    string        = "te-food-bundles"
	Def_FabChannel     string        = "trustchain-test"
	Def_FabEndpoint    string        = "localhost:8101"
	Def_FabFuncConfirm string        = "GetBlockByTxID"
	Def_FabFuncSubmit  string        = "CreateBundle"
	Def_FabGateway     string        = "localhost"
	Def_FabKeystore    string        = "./keystore"
	Def_FabMspId       string        = "Org1MSP"
	Def_FabTlscert     string        = "./tlscert.pem"
	Def_HttpApikey     string        = ""
	Def_HttpPort       int           = 5088
	Def_HttpQuery      string        = "/query"
	Def_IoBrake        string        = "./BRAKE"
	Def_IoBuffer       int           = 150
	Def_IoCheckpoint   string        = "checkpoint"
	Def_IoLoglevel     int           = 5
	Def_IoTick         int           = 1000
	Def_IoTimestamp    bool          = false
	Def_LatorBind      string        = "127.0.0.1"
	Def_LatorExe       string        = "/usr/local/bin/configtxlator"
	Def_LatorPort      int           = 0
	Def_LatorProto     string        = "common.Block"
	Def_ProcInterval   time.Duration = 10 * time.Second
	Def_ProcKeyname    string        = "bundle_id"
	Def_ProcKeypos     int           = 0
	Def_ProcKeytype    string        = "string"
	Def_ProcTry        int           = 250

	Logger  *log.Logger
	Lout    func(s ...interface{}) *[]error
	Logmark int

	StatStart       time.Time = time.Now()
	StatTrs         int       = 0
	StatCacheHists  int       = 0
	StatCacheWrites int       = 0

	TxRegexp *regexp.Regexp
)

// endregion: globals
// region: constants

const (
	API_KEY_HEADER string = "X-API-Key"

	LATOR_LATENCY int = 1

	LOG_ERR    syslog.Priority = log.LOG_ERR
	LOG_NOTICE syslog.Priority = log.LOG_NOTICE
	LOG_INFO   syslog.Priority = log.LOG_INFO
	LOG_DEBUG  syslog.Priority = log.LOG_DEBUG
	LOG_EMERG  syslog.Priority = log.LOG_EMERG

	MODE_FORMAT             string = "  %3s || %-13s    %s\n"
	MODE_COMBINED_DESC      string = "combination of confirmBatch and submitBatch"
	MODE_COMBINED_FULL      string = "combined"
	MODE_COMBINED_SC        string = "-co"
	MODE_CONFIRM_DESC       string = "iterates over the output of submit/resubmit and query for block number and data hash via fabric gateway against supplied chaincode and function"
	MODE_CONFIRM_FULL       string = "confirm"
	MODE_CONFIRM_SC         string = "-cf"
	MODE_CONFIRMBATCH_DESC  string = "iterates over the output of submit/resubmit and query for block number and data hash via fabric gateway against supplied chaincode and function"
	MODE_CONFIRMBATCH_FULL  string = "confirmBatch"
	MODE_CONFIRMBATCH_SC    string = "-cb"
	MODE_CONFIRMRAWAPI_DESC string = "iterates over the output of submit/resubmit and query for block number and data hash via rawapi/http against supplied chaincode and function"
	MODE_CONFIRMRAWAPI_FULL string = "confirmRawapi"
	MODE_CONFIRMRAWAPI_SC   string = "-cr"
	MODE_HELP_DESC          string = "or, for that matter, anything not in the list produces this output"
	MODE_HELP_FULL          string = "help"
	MODE_HELP_SC            string = "-h"
	MODE_LISTENER_DESC      string = "listens for block events"
	MODE_LISTENER_FULL      string = "listener"
	MODE_LISTENER_SC        string = "-l"
	MODE_RESUBMIT_DESC      string = "iterates over the output of submit and retries unsuccessful attempts"
	MODE_RESUBMIT_FULL      string = "resubmit"
	MODE_RESUBMIT_SC        string = "-r"
	MODE_SUBMIT_DESC        string = "iterates over input batch and submit line by line via direct fabric gateway link"
	MODE_SUBMIT_FULL        string = "submit"
	MODE_SUBMIT_SC          string = "-su"
	MODE_SUBMITBATCH_DESC   string = "iterates over list of files with bundles to be processed and submit line by line via direct fabric gateway link"
	MODE_SUBMITBATCH_FULL   string = "submitBatch"
	MODE_SUBMITBATCH_SC     string = "-sb"

	OPT_FAB_CERT             string = "cert"
	OPT_FAB_CC               string = "cc"
	OPT_FAB_CC_CONFIRM       string = "cc_confirm"
	OPT_FAB_CC_SUBMIT        string = "cc_submit"
	OPT_FAB_CHANNEL          string = "ch"
	OPT_FAB_ENDPOINT         string = "endpoint"
	OPT_FAB_ENDPOINT_CONFIRM string = "endpoint_confirm"
	OPT_FAB_ENDPOINT_SUBMIT  string = "endpoint_submit"
	OPT_FAB_FUNC             string = "func"
	OPT_FAB_FUNC_CONFIRM     string = "func_confirm"
	OPT_FAB_FUNC_SUBMIT      string = "func_submit"
	OPT_FAB_GATEWAY          string = "gw"
	OPT_FAB_GATEWAY_CONFIRM  string = "gw_confirm"
	OPT_FAB_GATEWAY_SUBMIT   string = "gw_submit"
	OPT_FAB_KEYSTORE         string = "keystore"
	OPT_FAB_MSPID            string = "mspid"
	OPT_FAB_TLSCERT          string = "tlscert"
	OPT_IO_BATCH             string = "batch"
	OPT_IO_BRAKE             string = "brake"
	OPT_IO_BUFFER            string = "buffer"
	OPT_IO_CHECKPOINT        string = "checkpoint"
	OPT_IO_LOGLEVEL          string = "loglevel"
	OPT_IO_INPUT             string = "in"
	OPT_IO_OUTPUT            string = "out"
	OPT_IO_SUFFIX            string = "suffix"
	OPT_IO_TICK              string = "tick"
	OPT_IO_TIMESTAMP         string = "ts"
	OPT_LATOR_BIND           string = "lator_bind"
	OPT_LATOR_EXE            string = "lator_exe"
	OPT_LATOR_PORT           string = "lator_port"
	OPT_LATOR_PROTO          string = "lator_proto"
	OPT_HTTP_APIKEY          string = "apikey"
	OPT_HTTP_HOST            string = "host"
	OPT_HTTP_QUERY           string = "query"
	OPT_PROC_INTERVAL        string = "interval"
	OPT_PROC_KEYNAME         string = "keyname"
	OPT_PROC_KEYPOS          string = "keypos"
	OPT_PROC_KEYTYPE         string = "keytype"
	OPT_PROC_TRY             string = "try"

	SCANNER_MAXTOKENSIZE int = 1024 * 1024 // 1MB

	STATUS_CONFIRM_ERROR_PREFIX string = "CONFIRM_ERROR_"
	STATUS_CONFIRM_ERROR_QUERY  string = STATUS_CONFIRM_ERROR_PREFIX + "QUERY"
	STATUS_CONFIRM_ERROR_DECODE string = STATUS_CONFIRM_ERROR_PREFIX + "DECODE"
	STATUS_CONFIRM_ERROR_HEADER string = STATUS_CONFIRM_ERROR_PREFIX + "HEADER"
	STATUS_CONFIRM_ERROR_TXID   string = STATUS_CONFIRM_ERROR_PREFIX + "TXID"
	STATUS_CONFIRM_OK           string = "CONFIRM_OK"
	STATUS_CONFIRM_PENDIG       string = "CONFIRM_PENDING"
	STATUS_PARSE_ERROR          string = "PARSE_ERROR"
	STATUS_SUBMIT_ERROR_PREFIX  string = "SUBMIT_ERROR_"
	STATUS_SUBMIT_ERROR_INVOKE  string = STATUS_SUBMIT_ERROR_PREFIX + "INVOKE"
	STATUS_SUBMIT_ERROR_KEY     string = STATUS_SUBMIT_ERROR_PREFIX + "KEY"
	STATUS_SUBMIT_ERROR_TXID    string = STATUS_SUBMIT_ERROR_PREFIX + "TXID"
	STATUS_SUBMIT_OK            string = "SUBMIT_OK"

	TC_FAB_CHANNEL   string = "TC_MIG_FAB_CH"
	TC_FAB_ENDPOINT  string = "TC_MIG_FAB_ENDPOINT"
	TC_FAB_GW        string = "TC_MIG_FAB_GW"
	TC_FAB_MSPID     string = "TC_MIG_FAB_MSPID"
	TC_HTTP_PORT     string = "TC_MIG_HTTP_PORT"
	TC_HTTP_APIKEY   string = "TC_MIG_HTTP_APIKEY"
	TC_LATOR_EXE     string = "TC_MIG_LATOR_EXE"
	TC_LATOR_BIND    string = "TC_MIG_LATOR_BIND"
	TC_LATOR_PORT    string = "TC_MIG_LATOR_PORT"
	TC_LOGLEVEL      string = "TC_MIG_LOGLEVEL"
	TC_PATH_CERT     string = "TC_MIG_PATH_CERT"
	TC_PATH_KEYSTORE string = "TC_MIG_PATH_KEYSTORE"
	TC_PATH_RC       string = "TC_MIG_PATH_RC"
	TC_PATH_TLSCERT  string = "TC_MIG_PATH_TLSCERT"

	TXID string = "^[a-fA-F0-9]{64}$"

	// TODO: msg/err
)

// endregion: constants
// region: types

type Compiler func(PSV) string
type ModeFunction func(*cfg.Config)
type Parser func(*bufio.Scanner) *[]PSV

type PSV struct {
	Status   string   `json:"status"`
	Key      string   `json:"key"`
	Txid     string   `json:"txid"`
	Response string   `json:"response"`
	Payload  []string `json:"payload"`
}

type Header struct {
	DataHash     string `json:"data_hash"`
	Length       int    `json:"length"`
	Number       string `json:"number"`
	PreviousHash string `json:"previous_hash"`
	Timestamp    string `json:"timestamp"`
}

// endregion: types
// region: main

func main() {

	// region: set env. variables

	rc, ok := os.LookupEnv(TC_PATH_RC)
	if ok && len(rc) != 0 {
		_, err := os.Stat(rc)
		if os.IsNotExist(err) {
			helperPanic("$TC_PATH_RC is set but corresponding file does not exist", TC_PATH_RC, err.Error())
		}
		if err != nil {
			helperPanic("$TC_PATH_RC is set but cannot stat file", TC_PATH_RC, err.Error())
		}

		envCmd := exec.Command("bash", "-c", "source "+rc+" ; echo '<<<ENVIRONMENT>>>' ; env | sort")
		env, err := envCmd.CombinedOutput()
		if err != nil {
			helperPanic(err.Error())
		}

		s := bufio.NewScanner(bytes.NewReader(env))
		start := false
		for s.Scan() {
			if s.Text() == "<<<ENVIRONMENT>>>" {
				start = true
			} else if start {
				kv := strings.SplitN(s.Text(), "=", 2)
				if len(kv) == 2 {
					tmp, set := os.LookupEnv(kv[0])
					if set {
						kv[1] = tmp
					}
					switch kv[0] {
					case TC_FAB_CHANNEL:
						Def_FabChannel = kv[1]
					case TC_FAB_GW:
						Def_FabGateway = kv[1]
					case TC_FAB_ENDPOINT:
						Def_FabEndpoint = kv[1]
					case TC_FAB_MSPID:
						Def_FabMspId = kv[1]
					case TC_HTTP_APIKEY:
						Def_HttpApikey = kv[1]
					case TC_HTTP_PORT:
						_, err = strconv.Atoi(kv[1])
						if err == nil {
							Def_HttpPort, _ = strconv.Atoi(kv[1])
						}
					case TC_LATOR_BIND:
						Def_LatorBind = kv[1]
					case TC_LATOR_PORT:
						_, err := strconv.Atoi(kv[1])
						if err == nil {
							Def_LatorPort, _ = strconv.Atoi(kv[1])
						}
					case TC_LATOR_EXE:
						Def_LatorExe = kv[1]
					case TC_LOGLEVEL:
						_, err = strconv.Atoi(kv[1])
						if err == nil {
							Def_IoLoglevel, _ = strconv.Atoi(kv[1])
						}
					case TC_PATH_CERT:
						Def_FabCert = kv[1]
					case TC_PATH_KEYSTORE:
						Def_FabKeystore = kv[1]
					case TC_PATH_TLSCERT:
						Def_FabTlscert = kv[1]
					}
				}
			}
		}
	}

	// endregion: env. variables
	// region: cfg/fs, common args

	config := *cfg.NewConfig(os.Args[0])

	cfg.FlagSetArguments = os.Args[2:]
	cfg.FlagSetUsage = helperUsage
	fs := config.NewFlagSet(os.Args[0] + " " + os.Args[1])
	fs.Entries = map[string]cfg.Entry{
		OPT_FAB_CHANNEL: {Desc: "[string] as channel id, default is $TC_CHANNEL1_NAME if set", Type: "string", Def: Def_FabChannel},
		OPT_IO_LOGLEVEL: {Desc: "loglevel as syslog.Priority, default is $TC_RAWAPI_LOGLEVEL if set", Type: "int", Def: Def_IoLoglevel},
		OPT_IO_OUTPUT:   {Desc: "path for output, empty means stdout", Type: "string", Def: ""},
	}

	// endregion: cfg/fs, common args
	// region: evaluate mode

	var modeExec ModeFunction

	if len(os.Args) == 1 {
		usage := helperUsage(nil)
		usage()
		helperPanic("missing mode selector")
	}

	switch strings.ToLower(os.Args[1]) {
	case MODE_COMBINED_FULL, MODE_COMBINED_SC:
		fs.Entries[OPT_FAB_CC_CONFIRM] = cfg.Entry{Desc: "chaincode to invoke", Type: "string", Def: Def_FabCcConfirm}
		fs.Entries[OPT_FAB_CC_SUBMIT] = cfg.Entry{Desc: "chaincode to invoke", Type: "string", Def: Def_FabCcSubmit}
		fs.Entries[OPT_FAB_CERT] = cfg.Entry{Desc: "path to client pem certificate to populate the wallet with, default is $" + TC_PATH_CERT + " if set", Type: "string", Def: Def_FabCert}
		fs.Entries[OPT_FAB_ENDPOINT_CONFIRM] = cfg.Entry{Desc: "fabric confirm endpoint, default is $" + TC_FAB_ENDPOINT + " if set", Type: "string", Def: Def_FabEndpoint}
		fs.Entries[OPT_FAB_ENDPOINT_SUBMIT] = cfg.Entry{Desc: "fabric invoke endpoint, default is $" + TC_FAB_ENDPOINT + " if set", Type: "string", Def: Def_FabEndpoint}
		fs.Entries[OPT_FAB_FUNC_CONFIRM] = cfg.Entry{Desc: "function of -" + OPT_FAB_CC_CONFIRM, Type: "string", Def: Def_FabFuncConfirm}
		fs.Entries[OPT_FAB_FUNC_SUBMIT] = cfg.Entry{Desc: "function of -" + OPT_FAB_CC_SUBMIT, Type: "string", Def: Def_FabFuncSubmit}
		fs.Entries[OPT_FAB_GATEWAY_CONFIRM] = cfg.Entry{Desc: "default gateway, default is $" + TC_FAB_GW + " if set", Type: "string", Def: Def_FabGateway}
		fs.Entries[OPT_FAB_GATEWAY_SUBMIT] = cfg.Entry{Desc: "default gateway, default is $" + TC_FAB_GW + " if set", Type: "string", Def: Def_FabGateway}
		fs.Entries[OPT_FAB_KEYSTORE] = cfg.Entry{Desc: "path to client keystore, default is $" + TC_PATH_KEYSTORE + " if set", Type: "string", Def: Def_FabKeystore}
		fs.Entries[OPT_FAB_MSPID] = cfg.Entry{Desc: "fabric MSPID, default is $" + TC_FAB_MSPID + " if set", Type: "string", Def: Def_FabMspId}
		fs.Entries[OPT_FAB_TLSCERT] = cfg.Entry{Desc: "path to TLS cert, default is $" + TC_PATH_CERT + " if set", Type: "string", Def: Def_FabTlscert}

		fs.Entries[OPT_IO_BATCH] = cfg.Entry{Desc: "list of files to process, one file path per line, -" + OPT_IO_INPUT + " ignored if specified", Type: "string", Def: ""}
		fs.Entries[OPT_IO_BRAKE] = cfg.Entry{Desc: "file path, which if appears, processing stops before opening the next file", Type: "string", Def: Def_IoBrake}
		fs.Entries[OPT_IO_BUFFER] = cfg.Entry{Desc: "fills up the temporary buffer with this many transactions, which first get submitted, then confirmed, should be large enough for the submited transactions to be finalized by the time of confirmation begins", Type: "int", Def: Def_IoBuffer}
		fs.Entries[OPT_IO_INPUT] = cfg.Entry{Desc: ", separated list of files, which contain the output of previous submit attempts, empty causes panic", Type: "string", Def: ""}
		fs.Entries[OPT_IO_SUFFIX] = cfg.Entry{Desc: "suffix with which the name of the processed file is appended as output (-" + OPT_IO_OUTPUT + " is ignored if supplied)", Type: "string", Def: ""}
		fs.Entries[OPT_IO_TICK] = cfg.Entry{Desc: "progress message at LOG_NOTICE level per this many transactions, 0 means no message", Type: "int", Def: Def_IoTick}
		fs.Entries[OPT_IO_TIMESTAMP] = cfg.Entry{Desc: "prefixes the file with a timestamp (YYMMDD_HHMM_) if true, only valid if the -" + OPT_IO_SUFFIX + " is also set", Type: "bool", Def: Def_IoTimestamp}

		fs.Entries[OPT_LATOR_BIND] = cfg.Entry{Desc: "address to bind configtxlator's rest api to, default is $" + TC_LATOR_BIND + " if set", Type: "string", Def: Def_LatorBind}
		fs.Entries[OPT_LATOR_EXE] = cfg.Entry{Desc: "path to configtxlator (if empty, will dump protobuf as base64 encoded string), default is $" + TC_LATOR_EXE + " if set", Type: "string", Def: Def_LatorExe}
		fs.Entries[OPT_LATOR_PORT] = cfg.Entry{Desc: "port where configtxlator will listen, default is $" + TC_LATOR_PORT + " if set, 0 means random", Type: "int", Def: Def_LatorPort}
		fs.Entries[OPT_LATOR_PROTO] = cfg.Entry{Desc: "protobuf format, configtxlator will be used if set", Type: "string", Def: Def_LatorProto}

		fs.Entries[OPT_PROC_KEYNAME] = cfg.Entry{Desc: "the name of the field containing the unique identifier", Type: "string", Def: Def_ProcKeyname}
		fs.Entries[OPT_PROC_KEYPOS] = cfg.Entry{Desc: "Nth field in -in that contains the unique identifier identified by -" + OPT_PROC_KEYNAME, Type: "int", Def: Def_ProcKeypos}
		fs.Entries[OPT_PROC_KEYTYPE] = cfg.Entry{Desc: "type of -" + OPT_PROC_KEYNAME + ", either 'string' or 'int'", Type: "string", Def: Def_ProcKeytype}
		fs.Entries[OPT_PROC_TRY] = cfg.Entry{Desc: "number of invoke tries", Type: "int", Def: Def_ProcTry}

		modeExec = modeCombined
	case MODE_CONFIRM_FULL, MODE_CONFIRM_SC:
		fs.Entries[OPT_FAB_CERT] = cfg.Entry{Desc: "path to client pem certificate to populate the wallet with, default is $" + TC_PATH_CERT + " if set", Type: "string", Def: Def_FabCert}
		fs.Entries[OPT_FAB_CC_CONFIRM] = cfg.Entry{Desc: "chaincode to query", Type: "string", Def: Def_FabCcConfirm}
		fs.Entries[OPT_FAB_ENDPOINT] = cfg.Entry{Desc: "fabric endpoint, default is $" + TC_FAB_ENDPOINT + " if set", Type: "string", Def: Def_FabEndpoint}
		fs.Entries[OPT_FAB_FUNC_CONFIRM] = cfg.Entry{Desc: "function of -" + OPT_FAB_CC_CONFIRM, Type: "string", Def: Def_FabFuncConfirm}
		fs.Entries[OPT_FAB_GATEWAY] = cfg.Entry{Desc: "default gateway, default is $" + TC_FAB_GW + " if set", Type: "string", Def: Def_FabGateway}
		fs.Entries[OPT_FAB_KEYSTORE] = cfg.Entry{Desc: "path to client keystore, default is $" + TC_PATH_KEYSTORE + " if set", Type: "string", Def: Def_FabKeystore}
		fs.Entries[OPT_FAB_MSPID] = cfg.Entry{Desc: "fabric MSPID, default is $" + TC_FAB_MSPID + " if set", Type: "string", Def: Def_FabMspId}
		fs.Entries[OPT_FAB_TLSCERT] = cfg.Entry{Desc: "path to TLS cert, default is $" + TC_PATH_CERT + " if set", Type: "string", Def: Def_FabTlscert}

		fs.Entries[OPT_IO_INPUT] = cfg.Entry{Desc: "file, which contains the output of previous submit attempt, empty means stdin", Type: "string", Def: ""}
		fs.Entries[OPT_IO_TICK] = cfg.Entry{Desc: "progress message at LOG_NOTICE level per this many transactions, 0 means no message", Type: "int", Def: Def_IoTick}

		fs.Entries[OPT_LATOR_BIND] = cfg.Entry{Desc: "address to bind configtxlator's rest api to, default is " + TC_LATOR_BIND + " if set", Type: "string", Def: Def_LatorBind}
		fs.Entries[OPT_LATOR_EXE] = cfg.Entry{Desc: "path to configtxlator (if empty, will dump protobuf as base64 encoded string), default is $" + TC_LATOR_EXE + ", if set", Type: "string", Def: Def_LatorExe}
		fs.Entries[OPT_LATOR_PORT] = cfg.Entry{Desc: "port where configtxlator will listen, default is $" + TC_LATOR_PORT + " if set, 0 means random", Type: "int", Def: Def_LatorPort}
		fs.Entries[OPT_LATOR_PROTO] = cfg.Entry{Desc: "protobuf format, configtxlator will be used if set", Type: "string", Def: Def_LatorProto}

		fs.Entries[OPT_PROC_TRY] = cfg.Entry{Desc: "number of invoke tries", Type: "int", Def: Def_ProcTry}

		modeExec = modeConfirm
	case MODE_CONFIRMBATCH_FULL, MODE_CONFIRMBATCH_SC:
		fs.Entries[OPT_FAB_CERT] = cfg.Entry{Desc: "path to client pem certificate to populate the wallet with, default is $" + TC_PATH_CERT + " if set", Type: "string", Def: Def_FabCert}
		fs.Entries[OPT_FAB_CC_CONFIRM] = cfg.Entry{Desc: "chaincode to query", Type: "string", Def: Def_FabCcConfirm}
		fs.Entries[OPT_FAB_ENDPOINT] = cfg.Entry{Desc: "fabric endpoint, default is $" + TC_FAB_ENDPOINT + " if set", Type: "string", Def: Def_FabEndpoint}
		fs.Entries[OPT_FAB_FUNC_CONFIRM] = cfg.Entry{Desc: "function of -" + OPT_FAB_CC_CONFIRM, Type: "string", Def: Def_FabFuncConfirm}
		fs.Entries[OPT_FAB_GATEWAY] = cfg.Entry{Desc: "default gateway, default is $" + TC_FAB_GW + " if set", Type: "string", Def: Def_FabGateway}
		fs.Entries[OPT_FAB_KEYSTORE] = cfg.Entry{Desc: "path to client keystore, default is $" + TC_PATH_KEYSTORE + " if set", Type: "string", Def: Def_FabKeystore}
		fs.Entries[OPT_FAB_MSPID] = cfg.Entry{Desc: "fabric MSPID, default is $" + TC_FAB_MSPID + " if set", Type: "string", Def: Def_FabMspId}
		fs.Entries[OPT_FAB_TLSCERT] = cfg.Entry{Desc: "path to TLS cert, default is $" + TC_PATH_CERT + " if set", Type: "string", Def: Def_FabTlscert}

		fs.Entries[OPT_IO_BATCH] = cfg.Entry{Desc: "list of files to process, one file path per line, -" + OPT_IO_INPUT + " ignored if specified", Type: "string", Def: ""}
		fs.Entries[OPT_IO_INPUT] = cfg.Entry{Desc: ", separated list of files, which contain the output of previous submit attempts, empty causes panic", Type: "string", Def: ""}
		fs.Entries[OPT_IO_SUFFIX] = cfg.Entry{Desc: "suffix with which the name of the processed file is appended as output (-" + OPT_IO_OUTPUT + " is ignored if supplied)", Type: "string", Def: ""}
		fs.Entries[OPT_IO_TICK] = cfg.Entry{Desc: "progress message at LOG_NOTICE level per this many transactions, 0 means no message", Type: "int", Def: Def_IoTick}

		fs.Entries[OPT_LATOR_BIND] = cfg.Entry{Desc: "address to bind configtxlator's rest api to, default is " + TC_LATOR_BIND + " if set", Type: "string", Def: Def_LatorBind}
		fs.Entries[OPT_LATOR_EXE] = cfg.Entry{Desc: "path to configtxlator (if empty, will dump protobuf as base64 encoded string), default is $" + TC_LATOR_EXE + ", if set", Type: "string", Def: Def_LatorExe}
		fs.Entries[OPT_LATOR_PORT] = cfg.Entry{Desc: "port where configtxlator will listen, default is $" + TC_LATOR_PORT + " if set, 0 means random", Type: "int", Def: Def_LatorPort}
		fs.Entries[OPT_LATOR_PROTO] = cfg.Entry{Desc: "protobuf format, configtxlator will be used if set", Type: "string", Def: Def_LatorProto}

		fs.Entries[OPT_PROC_TRY] = cfg.Entry{Desc: "number of invoke tries", Type: "int", Def: Def_ProcTry}

		modeExec = modeConfirmBatch
	case MODE_CONFIRMRAWAPI_FULL, MODE_CONFIRMRAWAPI_SC:
		fs.Entries[OPT_FAB_CC_CONFIRM] = cfg.Entry{Desc: "chaincode to query", Type: "string", Def: "qscc"}
		fs.Entries[OPT_FAB_FUNC_CONFIRM] = cfg.Entry{Desc: "function of -" + OPT_FAB_CC_CONFIRM, Type: "string", Def: Def_FabFuncConfirm}

		fs.Entries[OPT_HTTP_QUERY] = cfg.Entry{Desc: "query endpoint", Type: "string", Def: Def_HttpQuery}
		fs.Entries[OPT_HTTP_APIKEY] = cfg.Entry{Desc: "api key, skip if not set, default is $" + TC_HTTP_APIKEY + ", if set", Type: "string", Def: Def_HttpApikey}
		fs.Entries[OPT_HTTP_HOST] = cfg.Entry{Desc: "api host in http(s)://host:port format, default port is $" + TC_HTTP_PORT + " if set", Type: "string", Def: "http://localhost:" + strconv.Itoa(Def_HttpPort)}

		fs.Entries[OPT_IO_INPUT] = cfg.Entry{Desc: "| separated file with args for query, empty means stdin", Type: "string", Def: ""}
		fs.Entries[OPT_IO_TICK] = cfg.Entry{Desc: "progress message at LOG_NOTICE level per this many transactions, 0 means no message", Type: "int", Def: Def_IoTick}

		modeExec = modeConfirmRawapi
	case MODE_HELP_FULL, MODE_HELP_SC:
		os.Args[1] = ""
		msg := helperUsage(fs.FlagSet)
		msg()
		os.Exit(0)
	case MODE_LISTENER_FULL, MODE_LISTENER_SC:
		fs.Entries[OPT_FAB_CC] = cfg.Entry{Desc: "event emitter chaincode", Type: "string", Def: Def_FabCcSubmit}
		fs.Entries[OPT_FAB_CERT] = cfg.Entry{Desc: "path to client pem certificate to populate the wallet with, default is $" + TC_PATH_CERT + " if set", Type: "string", Def: Def_FabCert}
		fs.Entries[OPT_FAB_ENDPOINT] = cfg.Entry{Desc: "hyperledger fabric endpoint, default is $" + TC_FAB_ENDPOINT + " if set", Type: "string", Def: Def_FabEndpoint}
		fs.Entries[OPT_FAB_GATEWAY] = cfg.Entry{Desc: "hyperledger fabric gateway, default is $" + TC_FAB_GW + " if set", Type: "string", Def: Def_FabGateway}
		fs.Entries[OPT_FAB_KEYSTORE] = cfg.Entry{Desc: "path to client keystore, default is $" + TC_PATH_KEYSTORE + " if set", Type: "string", Def: Def_FabKeystore}
		fs.Entries[OPT_FAB_MSPID] = cfg.Entry{Desc: "fabric MSPID, default is $" + TC_FAB_MSPID + " if set", Type: "string", Def: Def_FabMspId}
		fs.Entries[OPT_FAB_TLSCERT] = cfg.Entry{Desc: "path to TLS cert, default is $" + TC_PATH_CERT + " if set", Type: "string", Def: Def_FabTlscert}

		fs.Entries[OPT_IO_CHECKPOINT] = cfg.Entry{Desc: "file checkpointer, empty means next block", Type: "string", Def: Def_IoCheckpoint}
		fs.Entries[OPT_IO_BUFFER] = cfg.Entry{Desc: "maximum block cache size", Type: "int", Def: Def_IoBuffer}
		fs.Entries[OPT_IO_TIMESTAMP] = cfg.Entry{Desc: "prefixes the -" + OPT_IO_OUTPUT + " with a timestamp (YYMMDD_HHMM_) if true", Type: "bool", Def: Def_IoTimestamp}

		fs.Entries[OPT_PROC_INTERVAL] = cfg.Entry{Desc: "status appear in the log every second (at LOG_NOTICE level), 0 means none", Type: "time.Duration", Def: Def_ProcInterval}

		modeExec = modeListener
	case MODE_SUBMIT_FULL, MODE_SUBMIT_SC:
		fs.Entries[OPT_FAB_CERT] = cfg.Entry{Desc: "path to client pem certificate to populate the wallet with, default is $" + TC_PATH_CERT + " if set", Type: "string", Def: Def_FabCert}
		fs.Entries[OPT_FAB_CC_SUBMIT] = cfg.Entry{Desc: "chaincode to invoke", Type: "string", Def: Def_FabCcSubmit}
		fs.Entries[OPT_FAB_ENDPOINT] = cfg.Entry{Desc: "fabric endpoint, default is $" + TC_FAB_ENDPOINT + " if set", Type: "string", Def: Def_FabEndpoint}
		fs.Entries[OPT_FAB_FUNC_SUBMIT] = cfg.Entry{Desc: "function of -" + OPT_FAB_CC_SUBMIT, Type: "string", Def: Def_FabFuncSubmit}
		fs.Entries[OPT_FAB_GATEWAY] = cfg.Entry{Desc: "default gateway, default is $" + TC_FAB_GW + " if set", Type: "string", Def: Def_FabGateway}
		fs.Entries[OPT_FAB_KEYSTORE] = cfg.Entry{Desc: "path to client keystore, default is $" + TC_PATH_KEYSTORE + " if set", Type: "string", Def: Def_FabKeystore}
		fs.Entries[OPT_FAB_MSPID] = cfg.Entry{Desc: "fabric MSPID, default is $" + TC_FAB_MSPID + " if set", Type: "string", Def: Def_FabMspId}
		fs.Entries[OPT_FAB_TLSCERT] = cfg.Entry{Desc: "path to TLS cert, default is $" + TC_PATH_CERT + " if set", Type: "string", Def: Def_FabTlscert}

		fs.Entries[OPT_IO_INPUT] = cfg.Entry{Desc: "file, which contains the parameters of one transaction per line, separated by |, empty means stdin", Type: "string", Def: ""}
		fs.Entries[OPT_IO_TICK] = cfg.Entry{Desc: "progress message at LOG_NOTICE level per this many transactions, 0 means no message", Type: "int", Def: Def_IoTick}

		fs.Entries[OPT_PROC_KEYNAME] = cfg.Entry{Desc: "the name of the field containing the unique identifier", Type: "string", Def: Def_ProcKeyname}
		fs.Entries[OPT_PROC_KEYPOS] = cfg.Entry{Desc: "Nth field in -" + OPT_IO_INPUT + " that contains the unique identifier identified by -" + OPT_PROC_KEYNAME, Type: "int", Def: Def_ProcKeypos}
		fs.Entries[OPT_PROC_KEYTYPE] = cfg.Entry{Desc: "type of -" + OPT_PROC_KEYNAME + ", either 'string' or 'int'", Type: "string", Def: Def_ProcKeytype}
		fs.Entries[OPT_PROC_TRY] = cfg.Entry{Desc: "number of invoke tries", Type: "int", Def: Def_ProcTry}

		modeExec = modeSubmit
	case MODE_SUBMITBATCH_FULL, MODE_SUBMITBATCH_SC:
		fs.Entries[OPT_FAB_CERT] = cfg.Entry{Desc: "path to client pem certificate to populate the wallet with, default is $" + TC_PATH_CERT + " if set", Type: "string", Def: Def_FabCert}
		fs.Entries[OPT_FAB_CC_SUBMIT] = cfg.Entry{Desc: "chaincode to invoke", Type: "string", Def: Def_FabCcSubmit}
		fs.Entries[OPT_FAB_ENDPOINT] = cfg.Entry{Desc: "fabric endpoint, default is $" + TC_FAB_ENDPOINT + " if set", Type: "string", Def: Def_FabEndpoint}
		fs.Entries[OPT_FAB_FUNC_SUBMIT] = cfg.Entry{Desc: "function of -" + OPT_FAB_CC_SUBMIT, Type: "string", Def: Def_FabFuncSubmit}
		fs.Entries[OPT_FAB_GATEWAY] = cfg.Entry{Desc: "default gateway, default is $" + TC_FAB_GW + " if set", Type: "string", Def: Def_FabGateway}
		fs.Entries[OPT_FAB_KEYSTORE] = cfg.Entry{Desc: "path to client keystore, default is $" + TC_PATH_KEYSTORE + " if set", Type: "string", Def: Def_FabKeystore}
		fs.Entries[OPT_FAB_MSPID] = cfg.Entry{Desc: "fabric MSPID, default is $" + TC_FAB_MSPID + " if set", Type: "string", Def: Def_FabMspId}
		fs.Entries[OPT_FAB_TLSCERT] = cfg.Entry{Desc: "path to TLS cert, default is $" + TC_PATH_CERT + " if set", Type: "string", Def: Def_FabTlscert}

		fs.Entries[OPT_IO_BATCH] = cfg.Entry{Desc: "list of files to process, one file path per line, -in ignored if specified", Type: "string", Def: ""}
		fs.Entries[OPT_IO_INPUT] = cfg.Entry{Desc: ", separated list of files, which contain the | separated parameters of one transaction per line, empty causes panic", Type: "string", Def: ""}
		fs.Entries[OPT_IO_SUFFIX] = cfg.Entry{Desc: "suffix with which the name of the processed file is appended as output (-" + OPT_IO_OUTPUT + " is ignored if supplied)", Type: "string", Def: ""}
		fs.Entries[OPT_IO_TICK] = cfg.Entry{Desc: "progress message at LOG_NOTICE level per this many transactions, 0 means no message", Type: "int", Def: Def_IoTick}

		fs.Entries[OPT_PROC_KEYNAME] = cfg.Entry{Desc: "the name of the field containing the unique identifier", Type: "string", Def: Def_ProcKeyname}
		fs.Entries[OPT_PROC_KEYPOS] = cfg.Entry{Desc: "Nth field in -in that contains the unique identifier identified by -keyname", Type: "int", Def: Def_ProcKeypos}
		fs.Entries[OPT_PROC_KEYTYPE] = cfg.Entry{Desc: "type of -" + OPT_PROC_KEYNAME + ", either 'string' or 'int'", Type: "string", Def: Def_ProcKeytype}
		fs.Entries[OPT_PROC_TRY] = cfg.Entry{Desc: "number of invoke tries", Type: "int", Def: Def_ProcTry}

		modeExec = modeSubmitBatch
	case MODE_RESUBMIT_FULL, MODE_RESUBMIT_SC:
		shift := strconv.Itoa(reflect.TypeOf(PSV{}).NumField())
		fs.Entries[OPT_FAB_CERT] = cfg.Entry{Desc: "path to client pem certificate to populate the wallet with, default is $" + TC_PATH_CERT + " if set", Type: "string", Def: Def_FabCert}
		fs.Entries[OPT_FAB_CC_SUBMIT] = cfg.Entry{Desc: "chaincode to invoke", Type: "string", Def: Def_FabCcSubmit}
		fs.Entries[OPT_FAB_ENDPOINT] = cfg.Entry{Desc: "fabric endpoint, default is $" + TC_FAB_ENDPOINT + " if set", Type: "string", Def: Def_FabEndpoint}
		fs.Entries[OPT_FAB_FUNC_SUBMIT] = cfg.Entry{Desc: "function of -" + OPT_FAB_CC_SUBMIT, Type: "string", Def: Def_FabFuncSubmit}
		fs.Entries[OPT_FAB_GATEWAY] = cfg.Entry{Desc: "default gateway", Type: "string", Def: Def_FabGateway}
		fs.Entries[OPT_FAB_KEYSTORE] = cfg.Entry{Desc: "path to client keystore, default is $" + TC_PATH_KEYSTORE + " if set", Type: "string", Def: Def_FabKeystore}
		fs.Entries[OPT_FAB_MSPID] = cfg.Entry{Desc: "fabric MSPID, default is $" + TC_FAB_MSPID + " if set", Type: "string", Def: Def_FabMspId}
		fs.Entries[OPT_FAB_TLSCERT] = cfg.Entry{Desc: "path to TLS cert, default is $" + TC_PATH_CERT + " if set", Type: "string", Def: Def_FabTlscert}

		fs.Entries[OPT_IO_INPUT] = cfg.Entry{Desc: "file, which contains the output of previous submit attempt, empty means stdin", Type: "string", Def: ""}
		fs.Entries[OPT_IO_TICK] = cfg.Entry{Desc: "progress message at LOG_NOTICE level per this many transactions, 0 means no message", Type: "int", Def: Def_IoTick}

		fs.Entries[OPT_PROC_KEYNAME] = cfg.Entry{Desc: "the name of the field containing the unique identifier", Type: "string", Def: Def_ProcKeyname}
		fs.Entries[OPT_PROC_KEYPOS] = cfg.Entry{Desc: shift + "+Nth field in -in that contains the unique identifier identified by -" + OPT_PROC_KEYNAME, Type: "int", Def: Def_ProcKeypos}
		fs.Entries[OPT_PROC_KEYTYPE] = cfg.Entry{Desc: "type of -" + OPT_PROC_KEYNAME + ", either 'string' or 'int'", Type: "string", Def: Def_ProcKeytype}
		fs.Entries[OPT_PROC_TRY] = cfg.Entry{Desc: "number of invoke tries", Type: "int", Def: Def_ProcTry}

		modeExec = modeResubmit
	default:
		mode := os.Args[1]
		os.Args[1] = ""
		usage := helperUsage(fs.FlagSet)
		usage()
		helperPanic("invalid mode '" + mode + "'")
	}

	// endregion: evaluate mode
	// region: parse flag set

	err := fs.ParseCopy()
	if err != nil {
		helperPanic(err.Error())
	}

	// endregion: parse flag set
	// region: init logger

	level := syslog.Priority(config.Entries[OPT_IO_LOGLEVEL].Value.(int))
	if level < LOG_INFO {
		log.ChDefaults.Welcome = nil
		log.ChDefaults.Bye = nil
	} else {
		welcome := fmt.Sprintf("%s (level: %v)", *log.ChDefaults.Welcome, level)
		log.ChDefaults.Welcome = &welcome
	}
	Logger = log.NewLogger()
	_, _ = Logger.NewCh(log.ChConfig{Severity: &level})
	defer Logger.Close()
	Lout = Logger.Out

	if config.Entries[OPT_IO_TICK].Value != nil {
		Logmark = config.Entries[OPT_IO_TICK].Value.(int)
	}

	// endregion: init logger
	// region: precompile txid regexp

	TxRegexp, err = regexp.Compile(TXID)
	if err != nil {
		helperPanic(err.Error())
	}

	// endregion: precompile txid regexp
	// region: exec mode

	Lout(LOG_INFO, "mode", os.Args[1])
	modeExec(&config)

	// endregion: exec mode
	// region: stats

	statEnd := time.Now()
	statElapsed := time.Since(StatStart)

	Lout(LOG_NOTICE, "start time:   ", StatStart.Format(time.RFC3339))
	Lout(LOG_NOTICE, "end time:     ", statEnd.Format(time.RFC3339))
	Lout(LOG_NOTICE, "elapsed time: ", statElapsed.Truncate(time.Second).String())
	Lout(LOG_NOTICE, "cache writes: ", StatCacheWrites)
	Lout(LOG_NOTICE, "cache hits:   ", StatCacheHists)
	Lout(LOG_NOTICE, "trx per hour: ", float64(StatTrs)/statElapsed.Hours())
	Lout(LOG_NOTICE, "trx per min:  ", float64(StatTrs)/statElapsed.Minutes())
	Lout(LOG_NOTICE, "trx per sec:  ", float64(StatTrs)/statElapsed.Seconds())

	// endregion: stats

}

// endregion: main
// region: modes

func modeCombined(config *cfg.Config) {

	// region: input

	var input []string
	if len(config.Entries[OPT_IO_BATCH].Value.(string)) == 0 {
		input = strings.Split(config.Entries[OPT_IO_INPUT].Value.(string), ",")
	} else {
		input = procBundles2Batch(ioRead(config.Entries[OPT_IO_BATCH].Value.(string), procParseBundles))
	}
	count := ioCount(input)

	// endregion: input
	// region: output

	var output *os.File
	var suffix string = config.Entries[OPT_IO_SUFFIX].Value.(string)
	var timestamp bool = config.Entries[OPT_IO_TIMESTAMP].Value.(bool)

	if len(suffix) == 0 {
		output = ioOutputOpen(config.Entries[OPT_IO_OUTPUT].Value.(string))
		defer output.Close()
	}

	// endregion: output
	// region: client

	config.Entries[OPT_FAB_ENDPOINT] = config.Entries[OPT_FAB_ENDPOINT_SUBMIT]
	config.Entries[OPT_FAB_GATEWAY] = config.Entries[OPT_FAB_GATEWAY_SUBMIT]
	clientSubmit := fabricClient(config)

	config.Entries[OPT_FAB_ENDPOINT] = config.Entries[OPT_FAB_ENDPOINT_CONFIRM]
	config.Entries[OPT_FAB_GATEWAY] = config.Entries[OPT_FAB_GATEWAY_CONFIRM]
	clientConfirm := fabricClient(config)

	// endregion: client
	// region: configtxlator

	fabricLator(config, clientConfirm)
	defer clientConfirm.Lator.Close()
	Lout(LOG_INFO, "protobuf decode", clientConfirm.Lator.Which, fmt.Sprintf("%s:%d", clientConfirm.Lator.Bind, clientConfirm.Lator.Port))

	// endregion: configtxlator
	// region: process batch

	bufferSize := config.Entries[OPT_IO_BUFFER].Value.(int)
	count = 2 * count

	for _, file := range input {

		// region: check for brake

		brake, err := os.Stat(config.Entries[OPT_IO_BRAKE].Value.(string))
		if err == nil {
			// file exists
			Lout(LOG_NOTICE, "someone pulled the handbrake", brake.ModTime())
			break
		} else if !errors.Is(err, fs.ErrNotExist) {
			// file does not exist, bur err indicates something different
			helperPanic("an unexpected error occurred while checking the brake file", err.Error())
		}

		// endregion: check for brake
		// region: io

		batchPtr := ioRead(file, procParseBundles)
		batch := *batchPtr // needs to be dereferenced

		path := file + suffix
		if len(suffix) > 0 {
			output = ioOutputOpen(path)
			defer output.Close()
		}

		// endregion: io
		// region: iteration

		var wg sync.WaitGroup

		for i := 0; i < len(batch); i += bufferSize {

			// region: read buffer

			bufferEnd := i + bufferSize
			if bufferEnd > len(batch) {
				bufferEnd = len(batch)
			}

			// submited := batch[i:bufferEnd]
			var submited []PSV

			// endregion: read buffer
			// region: submit buffer

			for _, bundle := range batch[i:bufferEnd] {
				err := fabricSubmit(config, clientSubmit, &bundle)
				if err != nil {
					Lout(LOG_NOTICE, helperProgress(count), err)
				} else {
					Lout(LOG_INFO, helperProgress(count), " submited", fmt.Sprintf("%20s", bundle.Key), file)
				}
				submited = append(submited, bundle)
			}

			// endregion: submit buffer
			// region: confirm and write buffer

			wg.Add(1)
			go func(confirm []PSV) {
				defer wg.Done()
				for _, bundle := range confirm {
					if bundle.Status != STATUS_SUBMIT_OK && !strings.HasPrefix(bundle.Status, STATUS_CONFIRM_ERROR_PREFIX) {
						Lout(LOG_INFO, helperProgress(count), "bypassed status", bundle.Status)
						ioOutputAppend(output, bundle, procCompilePSV)
						continue
					}
					if !TxRegexp.MatchString(bundle.Txid) {
						bundle.Status = STATUS_CONFIRM_ERROR_TXID
						Lout(LOG_ERR, helperProgress(count), "invalid txid", bundle.Txid)
						ioOutputAppend(output, bundle, procCompilePSV)
						continue
					}

					err = fabricConfirm(config, clientConfirm, &bundle)
					if err != nil {
						Lout(LOG_ERR, helperProgress(count), err)
					} else {
						Lout(LOG_INFO, helperProgress(count), "confirmed", fmt.Sprintf("%20s", bundle.Key), file, output.Name())
					}
					ioOutputAppend(output, bundle, procCompilePSV)
				}
			}(submited)

			// endregion: confirm and write buffer

		}
		wg.Wait()
		if len(suffix) > 0 && timestamp {
			output.Close()
			ioTimestamp(path)
		}

		// endregion: iteration

	}

	// endregion: process

}

func modeConfirm(config *cfg.Config) {

	// region: i/o

	input := config.Entries[OPT_IO_INPUT].Value.(string)
	output := config.Entries[OPT_IO_OUTPUT].Value.(string)

	batch, sent := ioCombined(input, output, procParsePSV)
	defer sent.Close()
	Lout(LOG_INFO, "# of lines", len(*batch))

	// endregion: i/o
	// region: client

	client := fabricClient(config)
	Lout(LOG_DEBUG, "fabric client", client)

	// endregion: client
	// region: configtxlator

	fabricLator(config, client)
	defer client.Lator.Close()
	Lout(LOG_INFO, "protobuf decode", client.Lator.Which, fmt.Sprintf("%s:%d", client.Lator.Bind, client.Lator.Port))

	// endregion: configtxlator
	// region: process batch

	for _, bundle := range *batch {

		if bundle.Status != STATUS_SUBMIT_OK && !strings.HasPrefix(bundle.Status, STATUS_CONFIRM_ERROR_PREFIX) {
			Lout(LOG_INFO, helperProgress(len(*batch)), "bypassed status", bundle.Status)
			ioOutputAppend(sent, bundle, procCompilePSV)
			continue
		}
		if !TxRegexp.MatchString(bundle.Txid) {
			bundle.Status = STATUS_CONFIRM_ERROR_TXID
			Lout(LOG_ERR, helperProgress(len(*batch)), "invalid txid", bundle.Txid)
			ioOutputAppend(sent, bundle, procCompilePSV)
			continue
		}

		err := fabricConfirm(config, client, &bundle)
		if err != nil {
			Lout(LOG_NOTICE, helperProgress(len(*batch)), err)
		} else {
			Lout(LOG_INFO, helperProgress(len(*batch)), "success", bundle.Key, bundle.Txid)
		}
		ioOutputAppend(sent, bundle, procCompilePSV)

	}

	// endregion: process batch

}

func modeConfirmBatch(config *cfg.Config) {

	// region: input

	// input := strings.Split(config.Entries[OPT_IO_INPUT].Value.(string), ",")
	// count := ioCount(input)

	var input []string
	if len(config.Entries[OPT_IO_BATCH].Value.(string)) == 0 {
		input = strings.Split(config.Entries[OPT_IO_INPUT].Value.(string), ",")
	} else {
		input = procBundles2Batch(ioRead(config.Entries[OPT_IO_BATCH].Value.(string), procParseBundles))
	}
	count := ioCount(input)

	// endregion: input
	// region: output

	var output *os.File
	var suffix string = config.Entries[OPT_IO_SUFFIX].Value.(string)

	if len(suffix) == 0 {
		output = ioOutputOpen(config.Entries[OPT_IO_OUTPUT].Value.(string))
		defer output.Close()
	}

	// endregion: output
	// region: client

	client := fabricClient(config)
	Lout(LOG_DEBUG, "fabric client", client)

	// endregion: client
	// region: configtxlator

	fabricLator(config, client)
	defer client.Lator.Close()
	Lout(LOG_INFO, "protobuf decode", client.Lator.Which, fmt.Sprintf("%s:%d", client.Lator.Bind, client.Lator.Port))

	// endregion: configtxlator
	// region: process batch

	for _, file := range input {
		batch := ioRead(file, procParsePSV)
		if len(suffix) > 0 {
			output = ioOutputOpen(file + suffix)
			defer output.Close()
		}
		for _, bundle := range *batch {
			if bundle.Status != STATUS_SUBMIT_OK && !strings.HasPrefix(bundle.Status, STATUS_CONFIRM_ERROR_PREFIX) {
				Lout(LOG_INFO, helperProgress(count), "bypassed status", bundle.Status)
				ioOutputAppend(output, bundle, procCompilePSV)
				continue
			}
			if !TxRegexp.MatchString(bundle.Txid) {
				bundle.Status = STATUS_CONFIRM_ERROR_TXID
				Lout(LOG_ERR, helperProgress(count), "invalid txid", bundle.Txid)
				ioOutputAppend(output, bundle, procCompilePSV)
				continue
			}

			err := fabricConfirm(config, client, &bundle)
			if err != nil {
				Lout(LOG_NOTICE, helperProgress(count), err)
			} else {
				Lout(LOG_INFO, helperProgress(count), "success", fmt.Sprintf("%12s", bundle.Key), file, output.Name())
			}
			ioOutputAppend(output, bundle, procCompilePSV)
		}
		if len(suffix) > 0 {
			output.Close()
		}
	}

	// endregion: process

}

func modeConfirmRawapi(config *cfg.Config) {

	// region: i/o

	inPath := config.Entries[OPT_IO_INPUT].Value.(string)
	outPath := config.Entries[OPT_IO_OUTPUT].Value.(string)

	batch, outFile := ioCombined(inPath, outPath, procParsePSV)
	defer outFile.Close()
	Lout(LOG_INFO, "# of lines", len(*batch))

	// endregion: i/o
	// region: client

	client := &fasthttp.Client{}

	// endregion: client
	// region: base url

	baseurl := fasthttp.AcquireURI()
	defer fasthttp.ReleaseURI(baseurl)
	baseurl.Parse(nil, []byte(config.Entries[OPT_HTTP_HOST].Value.(string)+config.Entries[OPT_HTTP_QUERY].Value.(string)))
	baseurl.QueryArgs().Add("channel", config.Entries[OPT_FAB_CHANNEL].Value.(string))
	baseurl.QueryArgs().Add("chaincode", config.Entries[OPT_FAB_CC_CONFIRM].Value.(string))
	baseurl.QueryArgs().Add("function", config.Entries[OPT_FAB_FUNC_CONFIRM].Value.(string))
	baseurl.QueryArgs().Add("proto_decode", "common.Block")
	baseurl.QueryArgs().Add("args", config.Entries[OPT_FAB_CHANNEL].Value.(string))
	Lout(LOG_INFO, "base url", baseurl.String())

	// endregion: base url
	// region: process batch

	for _, item := range *batch {

		// region: validate input

		if item.Status != STATUS_SUBMIT_OK && !strings.HasPrefix(item.Status, STATUS_CONFIRM_ERROR_PREFIX) {
			Lout(LOG_INFO, helperProgress(len(*batch)), "bypassed status", item.Status)
			ioOutputAppend(outFile, item, procCompilePSV)
			continue
		}
		if !TxRegexp.MatchString(item.Txid) {
			item.Status = STATUS_CONFIRM_ERROR_TXID
			Lout(LOG_ERR, helperProgress(len(*batch)), "invalid txid", item.Txid)
			ioOutputAppend(outFile, item, procCompilePSV)
			continue
		}

		// endregion: validate input
		// region: prepare request

		url := fasthttp.AcquireURI()
		defer fasthttp.ReleaseURI(url)
		baseurl.CopyTo(url)
		url.QueryArgs().Add("args", item.Txid)

		req := fasthttp.AcquireRequest()
		defer fasthttp.ReleaseRequest(req)
		req.Header.SetMethod("GET")
		req.SetRequestURI(url.String())
		if len(config.Entries[OPT_HTTP_APIKEY].Value.(string)) != 0 {
			req.Header.Set(API_KEY_HEADER, config.Entries[OPT_HTTP_APIKEY].Value.(string))
		}
		Lout(LOG_DEBUG, helperProgress(len(*batch)), url)

		resp := fasthttp.AcquireResponse()
		defer fasthttp.ReleaseResponse(resp)

		// endregion: prepare request
		// region: query

		err := client.Do(req, resp)
		if err != nil {
			item.Status = STATUS_CONFIRM_ERROR_QUERY
			item.Response = string(err.Error())
			Lout(LOG_ERR, helperProgress(len(*batch)), "http client error", err)
			ioOutputAppend(outFile, item, procCompilePSV)
			continue
		}

		// endregion: query
		// region: check status

		if resp.StatusCode() != fasthttp.StatusOK {
			item.Status = STATUS_CONFIRM_ERROR_PREFIX + strconv.Itoa(resp.StatusCode())
			item.Response = string(resp.Body())
			Lout(LOG_ERR, helperProgress(len(*batch)), "response status indicates an error", resp.StatusCode(), item.Response)
			ioOutputAppend(outFile, item, procCompilePSV)
			continue
		}

		// endregion: check status
		// region: get block

		blockData, blockDataType, _, err := jsonparser.Get(resp.Body(), "result")
		if blockDataType != jsonparser.Object || err != nil {
			item.Status = STATUS_CONFIRM_ERROR_HEADER
			item.Response = err.Error()
			Lout(LOG_ERR, helperProgress(len(*batch)), "no parsable header in response", item.Response)
			ioOutputAppend(outFile, item, procCompilePSV)
			continue
		}

		// endregion: get block
		// region: parse header

		headerStruct, err := procParseHeader(blockData)
		if err != nil {
			item.Response = err.Error()
			item.Status = STATUS_CONFIRM_ERROR_HEADER
			ioOutputAppend(outFile, item, procCompilePSV)
			continue
		}

		headerBytes, err := json.Marshal(headerStruct)
		if err != nil {
			item.Response = err.Error()
			item.Status = STATUS_CONFIRM_ERROR_HEADER
			ioOutputAppend(outFile, item, procCompilePSV)
			continue

		}

		// endregion: parse header
		// region: done

		item.Status = STATUS_CONFIRM_OK
		item.Response = string(headerBytes)
		ioOutputAppend(outFile, item, procCompilePSV)
		Lout(LOG_INFO, helperProgress(len(*batch)), "done")

		// endregion: done

	}

	// endregion: process batch

}

func modeListener(c *cfg.Config) {

	// region: output

	path := c.Entries[OPT_IO_OUTPUT].Value.(string)
	output := ioOutputOpen(path)
	defer output.Close()

	// endregion: output
	// region: fabric client

	fabric := fabricClient(c)
	network := fabric.Gateway.GetNetwork(c.Entries[OPT_FAB_CHANNEL].Value.(string))
	defer fabric.Close()

	// endregion: fabric
	// region: checkpoint, ctx

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// checkpointer := new(client.FileCheckpointer)
	var checkpointer *client.FileCheckpointer
	if len(c.Entries[OPT_IO_CHECKPOINT].Value.(string)) > 0 {
		ch, err := client.NewFileCheckpointer(c.Entries[OPT_IO_CHECKPOINT].Value.(string))
		if err != nil {
			helperPanic(err.Error())
		}
		checkpointer = ch
		checkpointer.Sync()
	}

	// endregion: checkpoint, ctx
	// region: prepare for sigint

	var wg sync.WaitGroup

	cleanupCh := make(chan struct{})
	interruptCh := make(chan os.Signal, 1)

	signal.Notify(interruptCh, os.Interrupt, syscall.SIGTERM)

	// endregion: prepare for sigint
	// region: block events

	blockCnt := 0
	blockErr := 0

	wg.Add(1)
	go func() {
		defer wg.Done()
		Lout(LOG_INFO, "block event listener started")

		blockEvents, err := network.BlockEvents(
			ctx,
			// client.WithStartBlock(3605), // ignored if the checkpointer has checkpoint state
			client.WithCheckpoint(checkpointer),
		)
		if err != nil {
			helperPanic(err.Error())
		}

		for {
			select {
			case <-cleanupCh:
				Lout(LOG_NOTICE, "block event listener is closing")
				return
			case event := <-blockEvents:
				blockCnt++

				header, err := json.Marshal(event.GetHeader())
				if err != nil {
					blockErr++
					Lout(LOG_ERR, "unable to parse block header", err)
					continue
				}

				var data_hash string
				var previous_hash string
				jsonparser.EachKey(header, func(idx int, value []byte, vt jsonparser.ValueType, errEachKey error) {
					switch idx {
					case 0:
						err = errEachKey
						if err == nil {
							data_hash = string(value)
						}
					case 1:
						err = errEachKey
						if err == nil {
							previous_hash = string(value)
						}
					}
				}, []string{"data_hash"}, []string{"previous_hash"})
				if err != nil {
					blockErr++
					Lout(LOG_ERR, "unable to parse block header details", err)
					continue
				}

				procBlockCacheWrite(Header{
					DataHash:     data_hash,
					Length:       len(event.GetData().GetData()),
					Number:       strconv.FormatUint(event.GetHeader().GetNumber(), 10),
					PreviousHash: previous_hash,
					Timestamp:    time.Now().Format(time.RFC3339),
				})
				// checkpointer.CheckpointBlock(event.GetHeader().GetNumber())
				Lout(LOG_DEBUG, "block event", blockCnt, string(header))
			}
		}
	}()

	// endregion: block events
	// region: chaincode events

	chCache := make(map[string]*PSV)
	chCacheMutex := sync.RWMutex{}
	chErr := 0

	wg.Add(1)
	go func() {
		defer wg.Done()
		Lout(LOG_INFO, "chaincode event listener started")

		chEvents, err := network.ChaincodeEvents(
			ctx,
			c.Entries[OPT_FAB_CC].Value.(string),
			// client.WithStartBlock(3605), // ignored if the checkpointer has checkpoint state
			client.WithCheckpoint(checkpointer),
		)
		if err != nil {
			helperPanic(err.Error())
		}

		for {
			select {
			case <-cleanupCh:
				Lout(LOG_NOTICE, "chaincode event listener is closing")
				return
			case event := <-chEvents:
				StatTrs++

				var tx_id string
				var bundle_id string
				jsonparser.EachKey(event.Payload, func(idx int, value []byte, vt jsonparser.ValueType, errEachKey error) {
					switch idx {
					case 0:
						err = errEachKey
						if err == nil {
							tx_id = string(value)
						}
					case 1:
						err = errEachKey
						if err == nil {
							bundle_id = string(value)
						}
					}
				}, []string{"tx_id"}, []string{"bundle_id"})
				if err != nil {
					chErr++
					Lout(LOG_ERR, "unable to parse chaincode event payload details", err)
					continue
				}

				chCacheMutex.Lock()
				chCache[tx_id] = &PSV{
					Txid:     tx_id,
					Status:   STATUS_CONFIRM_PENDIG,
					Key:      bundle_id,
					Payload:  []string{string(event.Payload)},
					Response: strconv.FormatUint(event.BlockNumber, 10),
				}
				Lout(LOG_DEBUG, "chaincode event", StatTrs, chCache[tx_id])
				chCacheMutex.Unlock()
				checkpointer.CheckpointChaincodeEvent(event)
			}
		}
	}()

	// endregion: chaincode events
	// region: match block and chaincode events

	wg.Add(1)
	go func() {
		defer wg.Done()
		Lout(LOG_INFO, "event matching started")

		for {
			select {
			case <-cleanupCh:
				Lout(LOG_NOTICE, "event matching is closing")
				return
			default:
				chCacheMutex.Lock()
				for tx_id := range chCache {
					if chCache[tx_id].Status != STATUS_CONFIRM_PENDIG {
						continue
					}
					if !TxRegexp.MatchString(tx_id) {
						chCache[tx_id].Status = STATUS_CONFIRM_ERROR_TXID
						Lout(LOG_ERR, "invalid txid", chCache[tx_id])
						ioOutputAppend(output, *chCache[tx_id], procCompilePSV)
						delete(chCache, tx_id)
						continue
					}
					if block, exists := procBlockCacheRead(chCache[tx_id].Response); exists {
						header, err := json.Marshal(block)
						if err != nil {
							chCache[tx_id].Response = err.Error()
							chCache[tx_id].Status = STATUS_CONFIRM_ERROR_HEADER
							Lout(LOG_ERR, "unable to parse blockheader while matching events", err)
							ioOutputAppend(output, *chCache[tx_id], procCompilePSV)
							delete(chCache, tx_id)
							continue
						}
						chCache[tx_id].Response = string(header)
						chCache[tx_id].Status = STATUS_CONFIRM_OK
						ioOutputAppend(output, *chCache[tx_id], procCompilePSV)
						delete(chCache, tx_id)
						Lout(LOG_DEBUG, "matched events", chCache[tx_id])
					}
				}
				chCacheMutex.Unlock()
			}
		}
	}()

	// endregion: match
	// region: purge

	wg.Add(1)
	go func() {
		defer wg.Done()
		Lout(LOG_INFO, "block cache purger started")

		for {
			select {
			case <-cleanupCh:
				Lout(LOG_NOTICE, "block cache purger is closing")
				return
			default:
				chCacheMutex.Lock()
				if len(BlockCache) > c.Entries[OPT_IO_BUFFER].Value.(int) {
					min := math.MaxInt

					var purged string
					for key, header := range BlockCache {
						num, err := strconv.Atoi(header.Number)
						if err != nil {
							Lout(LOG_ERR, "block number is NaN")
							delete(BlockCache, key)
							continue
						}
						if num < min {
							min = num
							purged = key
						}
					}
					delete(BlockCache, purged)
				}
				chCacheMutex.Unlock()
			}
		}
	}()

	// endregion: purge
	// region: status

	interval := c.Entries[OPT_PROC_INTERVAL].Value.(time.Duration)
	if interval != 0 {
		go func() {
			for {
				time.Sleep(interval)
				Lout(LOG_NOTICE, "listener status ==>")
				Lout(LOG_NOTICE, "elapsed time since launch:        ", helperProgressDuration(time.Since(StatStart)))

				Lout(LOG_NOTICE, "cached block headers:             ", blockCnt)
				Lout(LOG_NOTICE, "purged block headers:             ", blockCnt-len(BlockCache))
				Lout(LOG_NOTICE, "length of block cache:            ", len(BlockCache))
				Lout(LOG_NOTICE, "block event caching errors:       ", blockErr)

				Lout(LOG_NOTICE, "all buffered chaincode events:    ", StatTrs)
				Lout(LOG_NOTICE, "purged chaincode events:          ", StatTrs-len(chCache))
				Lout(LOG_NOTICE, "length of chaincode event buffer: ", len(chCache))
				Lout(LOG_NOTICE, "chaincode event buffering errors: ", chErr)

			}
		}()
	}

	// endregion: status
	// region: signals

	<-interruptCh
	Lout(LOG_NOTICE, "received interupt signal, initiating cleanup")
	close(cleanupCh)
	wg.Wait()
	for tx_id := range chCache {
		ioOutputAppend(output, *chCache[tx_id], procCompilePSV)
	}
	if checkpointer != nil {
		checkpointer.Sync()
		checkpointer.Close()
	}
	if c.Entries[OPT_IO_TIMESTAMP].Value.(bool) {
		output.Close()
		err := ioTimestamp(path)
		if err != nil {
			Lout(LOG_ERR, err)
		}
	}
	Lout(LOG_NOTICE, "cleanup complete")

	// endregion: signals

}

func modeResubmit(config *cfg.Config) {

	// region: i/o

	input := config.Entries[OPT_IO_INPUT].Value.(string)
	output := config.Entries[OPT_IO_OUTPUT].Value.(string)

	batch, sent := ioCombined(input, output, procParsePSV)
	defer sent.Close()
	Lout(LOG_INFO, "# of lines", len(*batch))

	// endregion: i/o
	// region: client

	client := fabricClient(config)
	Lout(LOG_DEBUG, "fabric client", client)

	// endregion: client
	// region: process batch

	for _, bundle := range *batch {

		if !strings.HasPrefix(bundle.Status, STATUS_SUBMIT_ERROR_PREFIX) {
			Lout(LOG_INFO, helperProgress(len(*batch)), "bypassed status", bundle.Status)
			ioOutputAppend(sent, bundle, procCompilePSV)
			continue
		}

		err := fabricSubmit(config, client, &bundle)
		if err != nil {
			Lout(LOG_NOTICE, helperProgress(len(*batch)), err)
		} else {
			Lout(LOG_INFO, helperProgress(len(*batch)), "success", bundle.Key, bundle.Txid)
		}
		ioOutputAppend(sent, bundle, procCompilePSV)
	}

	// endregion: process

}

func modeSubmit(config *cfg.Config) {

	// region: i/o

	input := config.Entries[OPT_IO_INPUT].Value.(string)
	output := config.Entries[OPT_IO_OUTPUT].Value.(string)

	batch, sent := ioCombined(input, output, procParseBundles)
	defer sent.Close()
	Lout(LOG_INFO, "# of lines", len(*batch))

	// endregion: i/o
	// region: client

	client := fabricClient(config)
	Lout(LOG_DEBUG, "fabric client", client)

	// endregion: client
	// region: process batch

	for _, bundle := range *batch {
		err := fabricSubmit(config, client, &bundle)
		if err != nil {
			Lout(LOG_NOTICE, helperProgress(len(*batch)), err)
		} else {
			Lout(LOG_INFO, helperProgress(len(*batch)), "success", bundle.Key, bundle.Txid)
		}
		ioOutputAppend(sent, bundle, procCompilePSV)
	}

	// endregion: process

}

func modeSubmitBatch(config *cfg.Config) {

	// region: input

	var input []string
	if len(config.Entries[OPT_IO_BATCH].Value.(string)) == 0 {
		input = strings.Split(config.Entries[OPT_IO_INPUT].Value.(string), ",")
	} else {
		input = procBundles2Batch(ioRead(config.Entries[OPT_IO_BATCH].Value.(string), procParseBundles))
	}
	count := ioCount(input)

	// endregion: input
	// region: output

	var output *os.File
	var suffix string = config.Entries[OPT_IO_SUFFIX].Value.(string)

	if len(suffix) == 0 {
		output = ioOutputOpen(config.Entries[OPT_IO_OUTPUT].Value.(string))
		defer output.Close()
	}

	// endregion: output
	// region: client

	client := fabricClient(config)
	Lout(LOG_DEBUG, "fabric client", client)

	// endregion: client
	// region: process batch

	for _, file := range input {
		batch := ioRead(file, procParseBundles)
		if len(suffix) > 0 {
			output = ioOutputOpen(file + suffix)
			defer output.Close()
		}
		for _, bundle := range *batch {
			err := fabricSubmit(config, client, &bundle)
			if err != nil {
				Lout(LOG_NOTICE, helperProgress(count), err)
			} else {
				Lout(LOG_INFO, helperProgress(count), "success", fmt.Sprintf("%12s", bundle.Key), file, output.Name())
			}
			ioOutputAppend(output, bundle, procCompilePSV)
		}
		if len(suffix) > 0 {
			output.Close()
		}
	}

	// endregion: process

}

// endregion: modes
// region: fabric

func fabricClient(config *cfg.Config) *fabric.Client {
	client := fabric.Client{
		CertPath:     config.Entries[OPT_FAB_CERT].Value.(string),
		GatewayPeer:  config.Entries[OPT_FAB_GATEWAY].Value.(string),
		KeyPath:      config.Entries[OPT_FAB_KEYSTORE].Value.(string),
		MSPID:        config.Entries[OPT_FAB_MSPID].Value.(string),
		PeerEndpoint: config.Entries[OPT_FAB_ENDPOINT].Value.(string),
		TLSCertPath:  config.Entries[OPT_FAB_TLSCERT].Value.(string),
	}
	err := client.Init()
	if err != nil {
		helperPanic(err.Error())
	}

	Lout(LOG_DEBUG, "fabric client instance", client)
	return &client
}

func fabricConfirm(config *cfg.Config, client *fabric.Client, bundle *PSV) error {

	// region: shorten variables coming from config

	channel := config.Entries[OPT_FAB_CHANNEL].Value.(string)
	chaincode := config.Entries[OPT_FAB_CC_CONFIRM].Value.(string)
	function := config.Entries[OPT_FAB_FUNC_CONFIRM].Value.(string)
	proto := config.Entries[OPT_LATOR_PROTO].Value.(string)
	try := config.Entries[OPT_PROC_TRY].Value.(int)

	// endregion: shorten variables coming from config
	// region: request

	request := fabric.Request{
		Chaincode: chaincode,
		Channel:   channel,
		Function:  function,
	}
	Lout(LOG_DEBUG, "fabric query request", request)

	// endregion: request
	// region: tries

	var response *fabric.Response
	var responseErr *fabric.ResponseError
	var headerStruct *Header

	for cnt := 1; cnt <= try; cnt++ {

		// region: response

		request.Args = []string{channel, bundle.Txid}
		response, responseErr = fabric.Query(client, &request)
		if responseErr != nil {
			bundle.Response = responseErr.Error()
			bundle.Status = STATUS_CONFIRM_ERROR_QUERY
			Lout(LOG_NOTICE, fmt.Sprintf("unsuccessful confirm attempt %d/%d", cnt, try))
			continue
		}

		// endregion: response
		// region: proto decode

		if len(proto) != 0 {
			Lout(LOG_DEBUG, "protobuf format", proto)

			block, err := client.Lator.Exe(response.Result, proto)
			if err != nil {
				bundle.Response = err.Error()
				bundle.Status = STATUS_CONFIRM_ERROR_DECODE
				responseErr = &fabric.ResponseError{Err: err}
				Lout(LOG_NOTICE, fmt.Sprintf("unsuccessful protobuf decode %d/%d", cnt, try))
				continue
			}
			response.Result = block
		}

		// endregion: proto decode
		// region: parse header

		header, err := procParseHeader(response.Result)
		if err != nil {
			bundle.Response = err.Error()
			bundle.Status = STATUS_CONFIRM_ERROR_HEADER
			responseErr = &fabric.ResponseError{Err: err}
			Lout(LOG_NOTICE, fmt.Sprintf("unable to parse header %d/%d", cnt, try))
			continue
		}

		headerStruct = header
		break

		// endregion: parse header

	}
	if responseErr != nil {
		return responseErr
	}

	// endregion: tries
	// region: out

	headerBytes, err := json.Marshal(headerStruct)
	if err != nil {
		bundle.Response = err.Error()
		bundle.Status = STATUS_CONFIRM_ERROR_HEADER
	}

	bundle.Response = string(headerBytes)
	bundle.Status = STATUS_CONFIRM_OK
	return nil

	// endregion: out

}

func fabricLator(config *cfg.Config, client *fabric.Client) {
	client.Lator = &fabric.Lator{
		Bind:  config.Entries[OPT_LATOR_BIND].Value.(string),
		Which: config.Entries[OPT_LATOR_EXE].Value.(string),
		Port:  config.Entries[OPT_LATOR_PORT].Value.(int),
	}
	err := client.Lator.Init()
	if err != nil {
		helperPanic("error initializing configtxlator instance", err.Error())
	}
	Lout(LOG_DEBUG, "configtxlator instance", client.Lator)
	Lout(LOG_INFO, "waiting for configtxlator launch", LATOR_LATENCY)
	time.Sleep(time.Duration(LATOR_LATENCY) * time.Second)
}

func fabricSubmit(config *cfg.Config, client *fabric.Client, bundle *PSV) error {

	// region: shorten variables coming from config

	chaincode := config.Entries[OPT_FAB_CC_SUBMIT].Value.(string)
	channel := config.Entries[OPT_FAB_CHANNEL].Value.(string)
	function := config.Entries[OPT_FAB_FUNC_SUBMIT].Value.(string)

	// if config.Entries[OPT_FAB_FUNC_SUBMIT].Value != nil {
	// 	function = config.Entries[OPT_FAB_FUNC_SUBMIT].Value.(string)
	// }

	keypos := config.Entries[OPT_PROC_KEYPOS].Value.(int)
	keyname := config.Entries[OPT_PROC_KEYNAME].Value.(string)
	keytype := config.Entries[OPT_PROC_KEYTYPE].Value.(string)

	try := config.Entries[OPT_PROC_TRY].Value.(int)

	// endregion: shorten variables coming from config
	// region: get unique id

	var err error

	switch keytype {
	case "string":
		bundle.Key, err = jsonparser.GetString([]byte(bundle.Payload[keypos]), keyname)
	case "int":
		var key int64
		key, err = jsonparser.GetInt([]byte(bundle.Payload[keypos]), keyname)
		if err == nil {
			bundle.Key = strconv.FormatInt(key, 10)
		}
	default:
		helperPanic("invalid keytype")
	}
	if err != nil {
		bundle.Response = err.Error()
		bundle.Status = STATUS_SUBMIT_ERROR_KEY
		return err
	}
	if len(bundle.Key) == 0 {
		bundle.Status = STATUS_SUBMIT_ERROR_KEY
		return errors.New("empty unique id")
	}
	Lout(LOG_DEBUG, "unique id", bundle.Key)

	// endregion: unique id
	// region: request

	request := fabric.Request{
		Chaincode: chaincode,
		Channel:   channel,
		Function:  function,
		Args:      bundle.Payload,
	}
	Lout(LOG_DEBUG, "fabric invoke request", request)

	// endregion: request
	// region: response

	var response *fabric.Response
	var responseErr *fabric.ResponseError

	for cnt := 1; cnt <= try; cnt++ {
		// response, responseErr = fabricInvoke(config, client, bundle.Payload)
		response, responseErr = fabric.Invoke(client, &request)
		if responseErr == nil {
			break
		}
		Lout(LOG_DEBUG, fmt.Sprintf("unsuccessful submit attempt %d/%d", cnt, try))
	}
	if responseErr != nil {
		bundle.Response = responseErr.Error()
		bundle.Status = STATUS_SUBMIT_ERROR_INVOKE
		return responseErr
	}
	Lout(LOG_DEBUG, "fabric invoke response", response)

	// endregion: response
	// region: validate txid, out

	bundle.Status = STATUS_SUBMIT_OK

	if !TxRegexp.MatchString(response.Txid) {
		bundle.Response = string(response.Result)
		bundle.Status = STATUS_SUBMIT_ERROR_TXID
		bundle.Txid = response.Txid
		return errors.New("invalid txid")
	}

	// endregion: txid
	// region: out

	bundle.Response = string(response.Result)
	bundle.Status = STATUS_SUBMIT_OK
	bundle.Txid = response.Txid
	return nil

	// endregion: out

}

// endregion: fabric
// region: generic

func helperPanic(s ...string) {
	msg := strings.Join(s, " -> ")
	if Logger != nil {
		Lout(LOG_EMERG, msg)
	}
	fmt.Fprintln(os.Stderr, msg)
	os.Exit(1)
}

func helperProgress(totalTransactions int) string {

	// counter
	StatTrs++

	if totalTransactions == 0 {
		totalTransactions = StatTrs
	}

	// calculate progress percentage
	percentage := (float64(StatTrs) / float64(totalTransactions)) * 100

	// calculate elapsed time
	elapsedTime := time.Since(StatStart)

	// calculate remaining time
	remainingTransactions := totalTransactions - StatTrs
	transactionsPerSecond := float64(StatTrs) / elapsedTime.Seconds()
	remainingTime := time.Duration(float64(remainingTransactions) / transactionsPerSecond * float64(time.Second))

	// format elapsed time and remaining time as HH:MM:SS
	elapsedTimeFormatted := helperProgressDuration(elapsedTime)
	remainingTimeFormatted := helperProgressDuration(remainingTime)

	// format and return the result as a string
	formattedString := fmt.Sprintf("progress: %6.2f%% %7d/%-7d elapsed: %s remaining: %s tx/s: %6.2f", percentage, StatTrs, totalTransactions, elapsedTimeFormatted, remainingTimeFormatted, transactionsPerSecond)

	// check
	if Logmark != 0 {
		if StatTrs%Logmark == 0 {
			Lout(LOG_NOTICE, formattedString)
		}
	}

	return formattedString
}

func helperProgressDuration(d time.Duration) string {
	hours := int(d.Hours())
	minutes := int(d.Minutes()) % 60
	seconds := int(d.Seconds()) % 60
	return fmt.Sprintf("%02d:%02d:%02d", hours, minutes, seconds)
}

func helperUsage(fs *flag.FlagSet) func() {
	return func() {
		fmt.Println("usage:")
		if len(os.Args[1]) == 0 {
			fmt.Println("  " + os.Args[0] + " [mode] <options>")
			fmt.Println("")
			fmt.Println("modes:")

			fmt.Printf(MODE_FORMAT, MODE_COMBINED_SC, MODE_COMBINED_FULL, MODE_COMBINED_DESC)
			fmt.Printf(MODE_FORMAT, MODE_CONFIRM_SC, MODE_CONFIRM_FULL, MODE_CONFIRM_DESC)
			fmt.Printf(MODE_FORMAT, MODE_CONFIRMBATCH_SC, MODE_CONFIRMBATCH_FULL, MODE_CONFIRMBATCH_DESC)
			fmt.Printf(MODE_FORMAT, MODE_CONFIRMRAWAPI_SC, MODE_CONFIRMRAWAPI_FULL, MODE_CONFIRMRAWAPI_DESC)
			fmt.Printf(MODE_FORMAT, MODE_HELP_SC, MODE_HELP_FULL, MODE_HELP_DESC)
			fmt.Printf(MODE_FORMAT, MODE_LISTENER_SC, MODE_LISTENER_FULL, MODE_LISTENER_DESC)
			// fmt.Printf(MODE_FORMAT, "psv2json", "convert PSV format to JSON for server-side batch processing")
			fmt.Printf(MODE_FORMAT, MODE_RESUBMIT_SC, MODE_RESUBMIT_FULL, MODE_RESUBMIT_DESC)
			fmt.Printf(MODE_FORMAT, MODE_SUBMIT_SC, MODE_SUBMIT_FULL, MODE_SUBMIT_DESC)
			fmt.Printf(MODE_FORMAT, MODE_SUBMITBATCH_SC, MODE_SUBMITBATCH_FULL, MODE_SUBMITBATCH_DESC)
			fmt.Println("")
			fmt.Println("use `" + os.Args[0] + " [mode] --help` for mode specific details")
		} else {
			fmt.Println("  " + os.Args[0] + " " + os.Args[1] + " <options>")
			fmt.Println("")
			if fs != nil {
				fmt.Println("options:")
				fs.PrintDefaults()
				fmt.Println("")
				fmt.Println("Before evaluation, the file corresponding to $TC_PATH_RC is read (if it is set and the file exists) and otherwise unset variables are taken into account")
				fmt.Println("when setting some default values and parsing cli. Parameters can also be passed via env. variables, like `CHANNEL=foo` instead of '-channel=foo', order")
				fmt.Println("of precedence:")
				fmt.Println("  1. command line options")
				fmt.Println("  2. environment variables")
				fmt.Println("  3. default values")
				fmt.Println("")
			}
		}
		fmt.Println("")
	}
}

// endregion: generic
// region: io

func ioCombined(in, out string, fn Parser) (*[]PSV, *os.File) {
	batch := ioRead(in, fn)

	if len(in) != 0 && filepath.Clean(in) == filepath.Clean(out) {
		helperPanic("in-place update not supported yet", in, out)
	}

	file := ioOutputOpen(out)

	return batch, file
}

func ioCount(input []string) int {
	count := 0
	for k, v := range input {
		if len(v) == 0 {
			helperPanic(fmt.Sprintf("empty value in position %d of input files", k+1))
		}
		batch := ioRead(v, procParseBundles)
		Lout(LOG_INFO, fmt.Sprintf("%d/%d with  %d lines", k+1, len(input), len(*batch)))
		count = count + len(*batch)
	}
	Lout(LOG_INFO, fmt.Sprintf("%d files with total of %d lines", len(input), count))
	return count
}

func ioOutputAppend(f *os.File, psv PSV, fn Compiler) {
	line := fn(psv)
	_, err := f.WriteString(line + "\n")
	if err != nil {
		helperPanic("error appending line to file", err.Error(), f.Name(), line)
	}
}

func ioOutputOpen(f string) *os.File {

	var osFile *os.File

	// region: stdout

	if len(f) == 0 {
		Lout(LOG_INFO, "writing stdout")
		f = "/dev/stdout"
	}

	// endregion: stdout
	// region: does not file exists

	if _, err := os.Stat(f); os.IsNotExist(err) {
		Lout(LOG_INFO, "creating new file", f)
		osFile, err = os.Create(f)
		if err != nil {
			helperPanic("cannot create output file", f, err.Error())
		}
		return osFile
	}

	// endregion: file exists
	// region: open file

	osFile, err := os.OpenFile(f, os.O_APPEND|os.O_WRONLY, os.ModeAppend)
	Lout(LOG_DEBUG, "output file opened for appending", f)
	if err != nil {
		helperPanic("cannot open file, for appending", f, err.Error())
	}
	return osFile

	// endregion: open file

}

func ioRead(f string, fn Parser) *[]PSV {

	// region: stdin

	if f == "" {
		Lout(LOG_INFO, "reading stdin")

		scanner := bufio.NewScanner(os.Stdin)
		scanner.Buffer(make([]byte, SCANNER_MAXTOKENSIZE), SCANNER_MAXTOKENSIZE)

		return fn(scanner)
	}

	// endregion: stdin
	// region: actual file

	Lout(LOG_INFO, "reading file", f)

	// check if file exists
	_, err := os.Stat(f)
	if os.IsNotExist(err) {
		helperPanic("input file does not exist", err.Error())
	}
	if err != nil {
		helperPanic("cannot stat input file", err.Error())
	}

	// open for reading
	file, err := os.Open(f)
	if err != nil {
		helperPanic("cannot open input file", err.Error())
	}
	defer file.Close()

	// parse
	scanner := bufio.NewScanner(file)
	scanner.Buffer(make([]byte, SCANNER_MAXTOKENSIZE), SCANNER_MAXTOKENSIZE)

	return fn(scanner)

	// endregion: actual file

}

func ioTimestamp(path string) error {
	info, err := os.Stat(path)
	if err != nil {
		return err
	}
	if !info.Mode().IsRegular() {
		return errors.New("unable to timestamp not regular file")
	}

	timestamp := time.Now().Format("060102_1504_")
	basename := filepath.Base(path)
	prefixed := timestamp + basename

	err = os.Rename(path, filepath.Join(filepath.Dir(path), prefixed))
	if err != nil {
		return errors.New("error renaming the file: " + err.Error())
	}
	return nil
}

// endregion: io
// region: proc

func procBlockCacheRead(block string) (*Header, bool) {
	BlockCacheMutex.RLock()
	defer BlockCacheMutex.RUnlock()
	if header, exists := BlockCache[block]; exists {
		StatCacheHists++
		Lout(LOG_DEBUG, "cache hit", block)
		return &header, true
	}
	return nil, false
}

func procBlockCacheWrite(header Header) {
	BlockCacheMutex.Lock()
	defer BlockCacheMutex.Unlock()
	StatCacheWrites++
	Lout(LOG_DEBUG, "cache write", header.Number)
	BlockCache[header.Number] = header
}

func procCompilePSV(psv PSV) string {
	v := reflect.ValueOf(psv)
	if v.Kind() != reflect.Struct {
		Lout(log.LOG_WARNING, "cannot compile item to psv", psv, v.Kind())
		v = reflect.ValueOf(PSV{})
	}

	var values []string
	for i := 0; i < v.NumField()-1; i++ {
		fieldValue := v.Field(i)
		values = append(values, fmt.Sprintf("%v", fieldValue.Interface()))
	}
	values = append(values, strings.Join(psv.Payload, "|"))

	return strings.Join(values, "|")
}

func procBundles2Batch(psv *[]PSV) []string {
	var batch []string
	for _, line := range *psv {
		batch = append(batch, line.Payload...)
	}
	return batch
}

func procParseBundles(scanner *bufio.Scanner) *[]PSV {

	// TODO: implement helperParseJSON

	var batch []PSV

	for scanner.Scan() {
		line := scanner.Text()
		values := strings.Split(line, "|")
		item := PSV{Payload: values}
		batch = append(batch, item)
	}

	if err := scanner.Err(); err != nil {
		helperPanic(err.Error())
	}

	return &batch
}

func procParseHeader(response []byte) (*Header, error) {

	var responseHeader Header
	var err error

	// region: get block #

	responseHeader.Number, err = jsonparser.GetString(response, "header", "number")
	if err != nil {
		return nil, err
	}

	// endregion: block #
	// region: parse or cache

	if header, exists := procBlockCacheRead(responseHeader.Number); exists {
		responseHeader = *header
	} else {
		paths := [][]string{
			{"data", "data"},
			// {"data", "data", "[0]", "payload", "header", "channel_header", "timestamp"},
			{"header", "data_hash"},
			{"header", "previous_hash"},
		}

		var errOverall error
		jsonparser.EachKey(response, func(idx int, value []byte, vt jsonparser.ValueType, errEachKey error) {
			switch idx {
			case 0:
				errOverall = errEachKey
				if errOverall == nil {
					if vt == jsonparser.Array {
						length := 0
						_, errArrayEachOuter := jsonparser.ArrayEach(value, func(v []byte, dataType jsonparser.ValueType, offset int, errArrayEachInner error) {
							errOverall = errArrayEachInner
							if errOverall == nil {
								length++
							}
							if length == 1 {
								responseHeader.Timestamp, errOverall = jsonparser.GetString(value, "[0]", "payload", "header", "channel_header", "timestamp")
							}
						})
						errOverall = errArrayEachOuter
						if errOverall == nil {
							responseHeader.Length = length
						}
					} else {
						errOverall = errors.New("payload is not an array")
					}
				}
			// case 1:
			// 	errOverall = errEachKey
			// 	if errOverall == nil {
			// 		responseHeader.Timestamp = string(value)
			// 	}
			case 1:
				errOverall = errEachKey
				if errOverall == nil {
					responseHeader.DataHash = string(value)
				}
			case 2:
				errOverall = errEachKey
				if errOverall == nil {
					responseHeader.PreviousHash = string(value)
				}
			}
		}, paths...)
		if errOverall != nil {
			return nil, errOverall
		}

		procBlockCacheWrite(responseHeader)
		// BlockCache[responseHeader.Number] = responseHeader
	}

	// endregion: parse or cache

	return &responseHeader, nil
}

func procParsePSV(scanner *bufio.Scanner) *[]PSV {

	// TODO: implement helperParseJSON

	var batch []PSV

	for scanner.Scan() {
		line := scanner.Text()
		values := strings.Split(line, "|")

		if len(values) < 5 {
			Lout(LOG_NOTICE, "row skipped due to insufficient number of fields")
			item := PSV{
				Status:  STATUS_PARSE_ERROR,
				Payload: values,
			}
			batch = append(batch, item)
			continue
		}

		item := PSV{
			Status:   values[0],
			Key:      values[1],
			Txid:     values[2],
			Response: values[3],
			Payload:  values[4:],
		}
		batch = append(batch, item)

	}

	if err := scanner.Err(); err != nil {
		helperPanic(err.Error())
	}

	return &batch
}

// endregion: proc
