// region: packages

package main

import (
	"bufio"
	"bytes"
	"fmt"
	"log/syslog"
	"os"
	"os/exec"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/SandorMiskey/TEx-kit/cfg"
	"github.com/SandorMiskey/TEx-kit/log"
)

// endregion: packages
// region: globals

var (
	BlockCache      = make(map[string]*Header)
	BlockCacheMutex = sync.RWMutex{}

	Def_FabCert string = "./cert.pem"
	// Def_FabCcConfirm   string = "qscc"
	// Def_FabCcSubmit string = "te-food-bundles"
	Def_FabCc       string = "te-food-bundles"
	Def_FabChannel  string = "trustchain-test"
	Def_FabEndpoint string = "localhost:8101"
	// Def_FabFuncConfirm string = "GetBlockByTxID"
	// Def_FabFuncSubmit  string = "CreateBundle"
	Def_FabGateway  string = "localhost"
	Def_FabKeystore string = "./keystore"
	Def_FabMspId    string = "Org1MSP"
	Def_FabTlscert  string = "./tlscert.pem"
	// Def_HttpApikey     string = ""
	// Def_HttpPort       int    = 5088
	// Def_HttpQuery      string = "/query"
	// Def_IoBrake        string = "./BRAKE"
	Def_IoBuffer   int = 150
	Def_IoLoglevel int = 6
	// Def_IoTick         int    = 1000
	Def_IoTimestamp bool = false
	// Def_LatorBind  string = "127.0.0.1"
	// Def_LatorExe   string = "/usr/local/bin/configtxlator"
	// Def_LatorPort  int    = 0
	// Def_LatorProto string = "common.Block"
	// Def_ProcKeyname    string = "bundle_id"
	// Def_ProcKeypos     int    = 0
	// Def_ProcKeytype    string = "string"
	// Def_ProcTry        int    = 250
	Def_ProcInterval time.Duration = 10 * time.Second

	Logger *log.Logger
	Lout   func(s ...interface{}) *[]error
	// Logmark int

	// StatStart       time.Time = time.Now()
	// StatTrs         int       = 0
	StatCacheHists  int = 0
	StatCacheWrites int = 0

	TxRegexp *regexp.Regexp
)

// endregion: globals
// region: constants

const (
	// API_KEY_HEADER string = "X-API-Key"

	// LATOR_LATENCY int = 1

	LOG_ERR    syslog.Priority = log.LOG_ERR
	LOG_NOTICE syslog.Priority = log.LOG_NOTICE
	LOG_INFO   syslog.Priority = log.LOG_INFO
	LOG_DEBUG  syslog.Priority = log.LOG_DEBUG
	LOG_EMERG  syslog.Priority = log.LOG_EMERG

	MODE_FORMAT string = "  %-2s || %-13s    %s\n"
	// MODE_COMBINED_DESC      string = "combination of confirmBatch and submitBatch"
	// MODE_COMBINED_FULL      string = "combined"
	// MODE_COMBINED_SC        string = "co"
	// MODE_CONFIRM_DESC       string = "iterates over the output of submit/resubmit and query for block number and data hash via fabric gateway against supplied chaincode and function"
	// MODE_CONFIRM_FULL       string = "confirm"
	// MODE_CONFIRM_SC         string = "cf"
	// MODE_CONFIRMBATCH_DESC  string = "iterates over the output of submit/resubmit and query for block number and data hash via fabric gateway against supplied chaincode and function"
	// MODE_CONFIRMBATCH_FULL  string = "confirmBatch"
	// MODE_CONFIRMBATCH_SC    string = "cb"
	// MODE_CONFIRMRAWAPI_DESC string = "iterates over the output of submit/resubmit and query for block number and data hash via rawapi/http against supplied chaincode and function"
	// MODE_CONFIRMRAWAPI_FULL string = "confirmRawapi"
	// MODE_CONFIRMRAWAPI_SC   string = "cr"
	MODE_HELP_DESC     string = "or, for that matter, anything not in the list produces this output"
	MODE_HELP_FULL     string = "help"
	MODE_HELP_SC       string = "-h"
	MODE_LISTENER_DESC string = "listens for block events"
	MODE_LISTENER_FULL string = "listener"
	MODE_LISTENER_SC   string = "-l"
	// MODE_RESUBMIT_DESC      string = "iterates over the output of submit and retries unsuccessful attempts"
	// MODE_RESUBMIT_FULL      string = "resubmit"
	// MODE_RESUBMIT_SC        string = "rs"
	// MODE_SUBMIT_DESC        string = "iterates over input batch and submit line by line via direct fabric gateway link"
	// MODE_SUBMIT_FULL        string = "submit"
	// MODE_SUBMIT_SC          string = "su"
	// MODE_SUBMITBATCH_DESC   string = "iterates over list of files with bundles to be processed and submit line by line via direct fabric gateway link"
	// MODE_SUBMITBATCH_FULL   string = "submitBatch"
	// MODE_SUBMITBATCH_SC     string = "sb"

	OPT_FAB_CERT string = "cert"
	OPT_FAB_CC   string = "cc"
	// OPT_FAB_CC_CONFIRM       string = "cc_confirm"
	// OPT_FAB_CC_SUBMIT string = "cc_submit"
	OPT_FAB_CHANNEL  string = "ch"
	OPT_FAB_ENDPOINT string = "endpoint"
	// OPT_FAB_ENDPOINT_CONFIRM string = "endpoint_confirm"
	// OPT_FAB_ENDPOINT_SUBMIT  string = "endpoint_submit"
	// OPT_FAB_FUNC             string = "func"
	// OPT_FAB_FUNC_CONFIRM     string = "func_confirm"
	// OPT_FAB_FUNC_SUBMIT      string = "func_submit"
	OPT_FAB_GATEWAY string = "gw"
	// OPT_FAB_GATEWAY_CONFIRM  string = "gw_confirm"
	// OPT_FAB_GATEWAY_SUBMIT   string = "gw_submit"
	OPT_FAB_KEYSTORE string = "keystore"
	OPT_FAB_MSPID    string = "mspid"
	OPT_FAB_TLSCERT  string = "tlscert"
	// OPT_IO_BATCH             string = "batch"
	// OPT_IO_BRAKE             string = "brake"
	OPT_IO_BUFFER   string = "buffer"
	OPT_IO_LOGLEVEL string = "loglevel"
	// OPT_IO_INPUT             string = "in"
	OPT_IO_OUTPUT string = "out"
	// OPT_IO_SUFFIX            string = "suffix"
	// OPT_IO_TICK              string = "tick"
	OPT_IO_TIMESTAMP string = "ts"
	// OPT_LATOR_BIND  string = "lator_bind"
	// OPT_LATOR_EXE   string = "lator_exe"
	// OPT_LATOR_PORT  string = "lator_port"
	// OPT_LATOR_PROTO string = "lator_proto"
	// OPT_HTTP_APIKEY          string = "apikey"
	// OPT_HTTP_HOST            string = "host"
	// OPT_HTTP_QUERY           string = "query"
	// OPT_PROC_KEYNAME         string = "keyname"
	// OPT_PROC_KEYPOS          string = "keypos"
	// OPT_PROC_KEYTYPE         string = "keytype"
	// OPT_PROC_TRY             string = "try"
	OPT_PROC_INTERVAL string = "interval"

	// SCANNER_MAXTOKENSIZE int = 1024 * 1024 // 1MB

	STATUS_CONFIRM_ERROR_PREFIX string = "CONFIRM_ERROR_"
	// STATUS_CONFIRM_ERROR_QUERY  string = STATUS_CONFIRM_ERROR_PREFIX + "QUERY"
	// STATUS_CONFIRM_ERROR_DECODE string = STATUS_CONFIRM_ERROR_PREFIX + "DECODE"
	STATUS_CONFIRM_ERROR_HEADER string = STATUS_CONFIRM_ERROR_PREFIX + "HEADER"
	STATUS_CONFIRM_ERROR_TXID   string = STATUS_CONFIRM_ERROR_PREFIX + "TXID"
	STATUS_CONFIRM_OK           string = "CONFIRM_OK"
	STATUS_CONFIRM_PENDIG       string = "CONFIRM_PENDING"
	// STATUS_PARSE_ERROR          string = "PARSE_ERROR"
	// STATUS_SUBMIT_OK           string = "SUBMIT_OK"
	// STATUS_SUBMIT_ERROR_INVOKE  string = STATUS_SUBMIT_ERROR_PREFIX + "INVOKE"
	// STATUS_SUBMIT_ERROR_KEY     string = STATUS_SUBMIT_ERROR_PREFIX + "KEY"
	// STATUS_SUBMIT_ERROR_PREFIX string = "SUBMIT_ERROR_"
	// STATUS_SUBMIT_ERROR_TXID   string = STATUS_SUBMIT_ERROR_PREFIX + "TXID"

	TC_FAB_CHANNEL  string = "TC_MIG_FAB_CH"
	TC_FAB_ENDPOINT string = "TC_MIG_FAB_ENDPOINT"
	TC_FAB_GW       string = "TC_MIG_FAB_GW"
	TC_FAB_MSPID    string = "TC_MIG_FAB_MSPID"
	// TC_HTTP_PORT     string = "TC_MIG_HTTP_PORT"
	// TC_HTTP_APIKEY   string = "TC_MIG_HTTP_APIKEY"
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

type Compiler func(*PSV) string

type ModeFunction func(*cfg.Config)

// type Parser func(*bufio.Scanner) *[]PSV

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
					// case TC_HTTP_APIKEY:
					// 	Def_HttpApikey = kv[1]
					// case TC_HTTP_PORT:
					// 	_, err = strconv.Atoi(kv[1])
					// 	if err == nil {
					// 		Def_HttpPort, _ = strconv.Atoi(kv[1])
					// 	}
					// case TC_LATOR_BIND:
					// 	Def_LatorBind = kv[1]
					// case TC_LATOR_PORT:
					// 	_, err := strconv.Atoi(kv[1])
					// 	if err == nil {
					// 		Def_LatorPort, _ = strconv.Atoi(kv[1])
					// 	}
					// case TC_LATOR_EXE:
					// 	Def_LatorExe = kv[1]
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

	if len(os.Args) == 1 {
		os.Args = append(os.Args, "")
		usage := helperUsage(nil)
		usage()
		helperPanic("missing mode selector")
	}

	cfg.FlagSetArguments = os.Args[2:]
	cfg.FlagSetUsage = helperUsage
	fs := config.NewFlagSet(os.Args[0] + " " + os.Args[1])
	fs.Entries = map[string]cfg.Entry{
		OPT_FAB_CHANNEL: {Desc: "[string] as channel id, default is $TC_CHANNEL1_NAME if set", Type: "string", Def: Def_FabChannel},
		OPT_IO_LOGLEVEL: {Desc: "loglevel as syslog.Priority, default is $TC_RAWAPI_LOGLEVEL if set", Type: "int", Def: Def_IoLoglevel},
		// OPT_IO_TICK:     {Desc: "progress message at LOG_NOTICE level per this many transactions, 0 means no message", Type: "int", Def: Def_IoTick},
		OPT_IO_OUTPUT: {Desc: "path for output, empty means stdout", Type: "string", Def: ""},
	}

	// endregion: cfg/fs, common args
	// region: evaluate mode

	var modeExec ModeFunction

	switch strings.ToLower(os.Args[1]) {
	case MODE_HELP_FULL, MODE_HELP_SC:
		os.Args[1] = ""
		msg := helperUsage(fs.FlagSet)
		msg()
		os.Exit(0)
	case MODE_LISTENER_FULL, MODE_LISTENER_SC:
		fs.Entries[OPT_FAB_CC] = cfg.Entry{Desc: "event emitter chaincode", Type: "string", Def: Def_FabCc}
		fs.Entries[OPT_FAB_CERT] = cfg.Entry{Desc: "path to client pem certificate to populate the wallet with, default is $" + TC_PATH_CERT + " if set", Type: "string", Def: Def_FabCert}
		fs.Entries[OPT_FAB_ENDPOINT] = cfg.Entry{Desc: "hyperledger fabric endpoint, default is $" + TC_FAB_ENDPOINT + " if set", Type: "string", Def: Def_FabEndpoint}
		fs.Entries[OPT_FAB_GATEWAY] = cfg.Entry{Desc: "hyperledger fabric gateway, default is $" + TC_FAB_GW + " if set", Type: "string", Def: Def_FabGateway}
		fs.Entries[OPT_FAB_KEYSTORE] = cfg.Entry{Desc: "path to client keystore, default is $" + TC_PATH_KEYSTORE + " if set", Type: "string", Def: Def_FabKeystore}
		fs.Entries[OPT_FAB_MSPID] = cfg.Entry{Desc: "fabric MSPID, default is $" + TC_FAB_MSPID + " if set", Type: "string", Def: Def_FabMspId}
		fs.Entries[OPT_FAB_TLSCERT] = cfg.Entry{Desc: "path to TLS cert, default is $" + TC_PATH_CERT + " if set", Type: "string", Def: Def_FabTlscert}

		fs.Entries[OPT_IO_BUFFER] = cfg.Entry{Desc: "maximum block cache size", Type: "int", Def: Def_IoBuffer}
		fs.Entries[OPT_IO_TIMESTAMP] = cfg.Entry{Desc: "prefixes the -" + OPT_IO_OUTPUT + " with a timestamp (YYMMDD_HHMM_) if true", Type: "bool", Def: Def_IoTimestamp}

		fs.Entries[OPT_PROC_INTERVAL] = cfg.Entry{Desc: "status appear in the log every second (at LOG_NOTICE level), 0 means none", Type: "time.Duration", Def: Def_ProcInterval}

		modeExec = modeListener
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
	// Logmark = config.Entries[OPT_IO_TICK].Value.(int)

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

	// statEnd := time.Now()
	// statElapsed := time.Since(StatStart)

	// Lout(LOG_NOTICE, "start time:   ", StatStart.Format(time.RFC3339))
	// Lout(LOG_NOTICE, "end time:     ", statEnd.Format(time.RFC3339))
	// Lout(LOG_NOTICE, "elapsed time: ", statElapsed.Truncate(time.Second).String())
	// Lout(LOG_NOTICE, "cache writes: ", StatCacheWrites)
	// Lout(LOG_NOTICE, "cache hits:   ", StatCacheHists)
	// Lout(LOG_NOTICE, "trx per hour: ", float64(StatTrs)/statElapsed.Hours())
	// Lout(LOG_NOTICE, "trx per min:  ", float64(StatTrs)/statElapsed.Minutes())
	// Lout(LOG_NOTICE, "trx per sec:  ", float64(StatTrs)/statElapsed.Seconds())

	// endregion: stats

}

// endregion: main
