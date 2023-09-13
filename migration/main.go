// region: packages

package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"log/syslog"
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/SandorMiskey/TEx-kit/cfg"
	"github.com/SandorMiskey/TEx-kit/log"
	"github.com/SandorMiskey/TrustChain/migration/fabric"
	"github.com/buger/jsonparser"
	"github.com/valyala/fasthttp"
	// "github.com/SandorMiskey/TrustChain/migration/psv"
	// "github.com/davecgh/go-spew/spew"
)

// endregion: packages
// region: globals

var (
	BlockCache = make(map[string]Header)

	DefaultBundleBuffered int    = 100
	DefaultBundleKeyName  string = "bundle_id"
	DefaultBundleKeyPos   int    = 0
	DefaultBundleKeyType  string = "string"
	DefaultFabConfirmCc   string = "qscc"
	DefaultFabConfirmFunc string = "GetBlockByTxID"
	DefaultFabChannel     string = "trustchain-test"
	// DefaultFabClient     string = "org1-client"
	DefaultFabEndpoint   string = "localhost:7051"
	DefaultFabGw         string = "localhost"
	DefaultFabTry        int    = 10
	DefaultFabMspId      string = "Org1MSP"
	DefaultFabSubmitCc   string = "te-food-bundles"
	DefaultFabSubmitFunc string = "CreateBundle"
	DefaultHttpApikey    string = ""
	DefaultHttpPort      int    = 5088
	DefaultLatorBind     string = "127.0.0.1"
	DefaultLatorExe      string = "/usr/local/bin/configtxlator"
	DefaultLatorPort     int    = 1337
	DefaultLatorProto    string = "common.Block"
	DefaultLatorSleep    int    = 3
	DefaultLoglevel      int    = 7
	DefaultPathCert      string = "./cert.pem"
	DefaultPathKeystore  string = "./keystore"
	DefaultPathTlsCert   string = "./tlscert.pem"

	Logger *log.Logger
	Lout   func(s ...interface{}) *[]error

	StatStart time.Time = time.Now()
	StatTrs   int       = 0

	TxRegexp *regexp.Regexp
)

// endregion: globals
// region: constants

const (
	API_KEY_HEADER string = "X-API-Key"

	LOG_ERR    syslog.Priority = log.LOG_ERR
	LOG_NOTICE syslog.Priority = log.LOG_NOTICE
	LOG_INFO   syslog.Priority = log.LOG_INFO
	LOG_DEBUG  syslog.Priority = log.LOG_DEBUG
	LOG_EMERG  syslog.Priority = log.LOG_EMERG

	SCANNER_MAXTOKENSIZE int = 1024 * 1024 // 1MB

	MODE_CONFIRM_FULL       string = "confirm"
	MODE_CONFIRM_SC         string = "c"
	MODE_CONFIRMBATCH_FULL  string = "confirmBatch"
	MODE_CONFIRMBATCH_SC    string = "cb"
	MODE_CONFIRMRAWAPI_FULL string = "confirmRawapi"
	MODE_CONFIRMRAWAPI_SC   string = "cr"
	MODE_COMBINED_FULL      string = "combined"
	MODE_COMBINED_SC        string = "co"
	MODE_SUBMIT_FULL        string = "submit"
	MODE_SUBMIT_SC          string = "s"
	MODE_SUBMITBATCH_FULL   string = "submitBatch"
	MODE_SUBMITBATCH_SC     string = "sb"
	MODE_RESUBMIT_FULL      string = "resubmit"
	MODE_RESUBMIT_SC        string = "r"

	OPT_FAB_CERT         string = "cert"
	OPT_FAB_CC           string = "chaincode"
	OPT_FAB_CC_CONFIRM   string = "chaincode_confirm"
	OPT_FAB_CC_SUBMIT    string = "chaincode_submit"
	OPT_FAB_CHANNEL      string = "channel"
	OPT_FAB_ENDPOINT     string = "endpoint"
	OPT_FAB_FUNC         string = "func"
	OPT_FAB_FUNC_CONFIRM string = "func_confirm"
	OPT_FAB_FUNC_SUBMIT  string = "func_submit"
	OPT_FAB_GATEWAY      string = "gw"
	OPT_FAB_KEYSTORE     string = "keystore"
	OPT_FAB_MSPID        string = "mspid"
	OPT_FAB_TLSCERT      string = "tlscert"
	OPT_IO_BATCH         string = "batch"
	OPT_IO_BUFFER        string = "buffer"
	OPT_IO_LOGLEVEL      string = "loglevel"
	OPT_IO_INPUT         string = "in"
	OPT_IO_OUTPUT        string = "out"
	OPT_IO_SUFFIX        string = "suffix"
	OPT_LATOR_BIND       string = "lator_bind"
	OPT_LATOR_EXE        string = "lator_exe"
	OPT_LATOR_PORT       string = "lator_port"
	OPT_LATOR_PROTO      string = "lator_proto"
	OPT_HTTP_APIKEY      string = "apikey"
	OPT_HTTP_HOST        string = "host"
	OPT_HTTP_QUERY       string = "query"
	OPT_PROC_KEYNAME     string = "keyname"
	OPT_PROC_KEYPOS      string = "keypos"
	OPT_PROC_KEYTYPE     string = "keytype"
	OPT_PROC_TRY         string = "try"

	STATUS_CONFIRM_ERROR_PREFIX string = "CONFIRM_ERROR_"
	STATUS_CONFIRM_ERROR_QUERY  string = STATUS_CONFIRM_ERROR_PREFIX + "QUERY"
	STATUS_CONFIRM_ERROR_DECODE string = STATUS_CONFIRM_ERROR_PREFIX + "DECODE"
	STATUS_CONFIRM_ERROR_HEADER string = STATUS_CONFIRM_ERROR_PREFIX + "HEADER"
	STATUS_CONFIRM_ERROR_TXID   string = STATUS_CONFIRM_ERROR_PREFIX + "TXID"
	STATUS_CONFIRM_OK           string = "CONFIRM_OK"
	STATUS_PARSE_ERROR          string = "PARSE_ERROR"
	STATUS_SUBMIT_ERROR_PREFIX  string = "SUBMIT_ERROR_"
	STATUS_SUBMIT_ERROR_INVOKE  string = STATUS_SUBMIT_ERROR_PREFIX + "INVOKE"
	STATUS_SUBMIT_ERROR_KEY     string = STATUS_SUBMIT_ERROR_PREFIX + "KEY"
	STATUS_SUBMIT_ERROR_TXID    string = STATUS_SUBMIT_ERROR_PREFIX + "TXID"
	STATUS_SUBMIT_OK            string = "SUBMIT_OK"

	TC_FAB_CHANNEL   string = "TC_CHANNEL1_NAME"
	TC_FAB_CLIENT    string = "TC_ORG1_CLIENT"
	TC_FAB_ENDPOINT  string = "TC_RAWAPI_PEERENDPOINT"
	TC_FAB_GW        string = "TC_RAWAPI_GATEWAYPEER"
	TC_FAB_MSPID     string = "TC_RAWAPI_MSPID"
	TC_HTTP_APIKEY   string = "TC_HTTP_API_KEY"
	TC_HTTP_PORT     string = "TC_RAWAPI_HTTP_PORT"
	TC_LATOR_BIND    string = "TC_RAWAPI_LATOR_BIND"
	TC_LATOR_EXE     string = "TC_PATH_BIN"
	TC_LATOR_PORT    string = "TC_RAWAPI_LATOR_PORT"
	TC_LOGLEVEL      string = "TC_RAWAPI_LOGLEVEL"
	TC_PATH_CERT     string = "TC_RAWAPI_CERTPATH"
	TC_PATH_KEYSTORE string = "TC_RAWAPI_KEYPATH"
	TC_PATH_RC       string = "TC_PATH_RC"
	TC_PATH_TLSCERT  string = "TC_RAWAPI_TLSCERTPATH"

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
						DefaultFabChannel = kv[1]
					// case TC_FAB_CLIENT:
					// 	DefaultFabClient = kv[1]
					case TC_FAB_GW:
						DefaultFabGw = kv[1]
					case TC_FAB_ENDPOINT:
						DefaultFabEndpoint = kv[1]
					case TC_FAB_MSPID:
						DefaultFabMspId = kv[1]
					case TC_HTTP_APIKEY:
						DefaultHttpApikey = kv[1]
					case TC_HTTP_PORT:
						_, err = strconv.Atoi(kv[1])
						if err == nil {
							DefaultHttpPort, _ = strconv.Atoi(kv[1])
						}
					case TC_LATOR_BIND:
						DefaultLatorBind = kv[1]
					case TC_LATOR_PORT:
						_, err := strconv.Atoi(kv[1])
						if err == nil {
							DefaultLatorPort, _ = strconv.Atoi(kv[1])
						}
					case TC_LATOR_EXE:
						DefaultLatorExe = kv[1] + "/configtxlator"
					case TC_LOGLEVEL:
						_, err = strconv.Atoi(kv[1])
						if err == nil {
							DefaultLoglevel, _ = strconv.Atoi(kv[1])
						}
					case TC_PATH_CERT:
						DefaultPathCert = kv[1]
					case TC_PATH_KEYSTORE:
						DefaultPathKeystore = kv[1]
					case TC_PATH_TLSCERT:
						DefaultPathTlsCert = kv[1]
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
		OPT_FAB_CHANNEL: {Desc: "[string] as channel id, default is $TC_CHANNEL1_NAME if set", Type: "string", Def: DefaultFabChannel},
		OPT_IO_LOGLEVEL: {Desc: "loglevel as syslog.Priority, default is $TC_RAWAPI_LOGLEVEL if set", Type: "int", Def: DefaultLoglevel},
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
	case MODE_CONFIRM_FULL, MODE_CONFIRM_SC:
		fs.Entries[OPT_FAB_CERT] = cfg.Entry{Desc: "path to client pem certificate to populate the wallet with, default is $TC_RAWAPI_CERTPATH if set", Type: "string", Def: DefaultPathCert}
		fs.Entries[OPT_FAB_CC] = cfg.Entry{Desc: "chaincode to query", Type: "string", Def: DefaultFabConfirmCc}
		fs.Entries[OPT_FAB_ENDPOINT] = cfg.Entry{Desc: "fabric endpoint, default is $TC_RAWAPI_PEERENDPOINT if set", Type: "string", Def: DefaultFabEndpoint}
		fs.Entries[OPT_FAB_FUNC] = cfg.Entry{Desc: "function of --chaincode", Type: "string", Def: DefaultFabConfirmFunc}
		fs.Entries[OPT_FAB_GATEWAY] = cfg.Entry{Desc: "default gateway, default is $TC_RAWAPI_GATEWAYPEER if set", Type: "string", Def: DefaultFabGw}
		fs.Entries[OPT_IO_INPUT] = cfg.Entry{Desc: "file, which contains the output of previous submit attempt, empty means stdin", Type: "string", Def: ""}
		fs.Entries[OPT_FAB_KEYSTORE] = cfg.Entry{Desc: "path to client keystore, default is $TC_RAWAPI_KEYPATH if set", Type: "string", Def: DefaultPathKeystore}
		fs.Entries[OPT_LATOR_BIND] = cfg.Entry{Desc: "address to bind configtxlator's rest api to, default is TC_RAWAPI_LATOR_BIND if set", Type: "string", Def: DefaultLatorBind}
		fs.Entries[OPT_LATOR_EXE] = cfg.Entry{Desc: "path to configtxlator (if empty, will dump protobuf as base64 encoded string), default is $TC_PATH_BIN/configtxlator if set", Type: "string", Def: DefaultLatorExe}
		fs.Entries[OPT_LATOR_PORT] = cfg.Entry{Desc: "port where configtxlator will listen, default is $TC_RAWAPI_LATOR_PORT if set, 0 meand random", Type: "int", Def: DefaultLatorPort}
		fs.Entries[OPT_LATOR_PROTO] = cfg.Entry{Desc: "protobuf format, configtxlator will be used if set", Type: "string", Def: DefaultLatorProto}
		fs.Entries[OPT_FAB_MSPID] = cfg.Entry{Desc: "fabric MSPID, default is $TC_RAWAPI_MSPID if set", Type: "string", Def: DefaultFabMspId}
		fs.Entries[OPT_PROC_TRY] = cfg.Entry{Desc: "number of invoke tries", Type: "int", Def: DefaultFabTry}
		fs.Entries[OPT_FAB_TLSCERT] = cfg.Entry{Desc: "path to TLS cert, default is $TC_RAWAPI_TLSCERTPATH if set", Type: "string", Def: DefaultPathTlsCert}

		modeExec = modeConfirm
	case MODE_CONFIRMBATCH_FULL, MODE_CONFIRMBATCH_SC:
		fs.Entries[OPT_IO_BATCH] = cfg.Entry{Desc: "list of files to process, one file path per line, -in ignored if specified", Type: "string", Def: ""}
		fs.Entries[OPT_FAB_CERT] = cfg.Entry{Desc: "path to client pem certificate to populate the wallet with, default is $TC_RAWAPI_CERTPATH if set", Type: "string", Def: DefaultPathCert}
		fs.Entries[OPT_FAB_CC] = cfg.Entry{Desc: "chaincode to query", Type: "string", Def: DefaultFabConfirmCc}
		fs.Entries[OPT_FAB_ENDPOINT] = cfg.Entry{Desc: "fabric endpoint, default is $TC_RAWAPI_PEERENDPOINT if set", Type: "string", Def: DefaultFabEndpoint}
		fs.Entries[OPT_FAB_FUNC] = cfg.Entry{Desc: "function of --chaincode", Type: "string", Def: DefaultFabConfirmFunc}
		fs.Entries[OPT_FAB_GATEWAY] = cfg.Entry{Desc: "default gateway, default is $TC_RAWAPI_GATEWAYPEER if set", Type: "string", Def: DefaultFabGw}
		fs.Entries[OPT_IO_INPUT] = cfg.Entry{Desc: ", separated list of files, which contain the output of previous submit attempts, empty causes panic", Type: "string", Def: ""}
		fs.Entries[OPT_FAB_KEYSTORE] = cfg.Entry{Desc: "path to client keystore, default is $TC_RAWAPI_KEYPATH if set", Type: "string", Def: DefaultPathKeystore}
		fs.Entries[OPT_LATOR_BIND] = cfg.Entry{Desc: "address to bind configtxlator's rest api to, default is TC_RAWAPI_LATOR_BIND if set", Type: "string", Def: DefaultLatorBind}
		fs.Entries[OPT_LATOR_EXE] = cfg.Entry{Desc: "path to configtxlator (if empty, will dump protobuf as base64 encoded string), default is $TC_PATH_BIN/configtxlator if set", Type: "string", Def: DefaultLatorExe}
		fs.Entries[OPT_LATOR_PORT] = cfg.Entry{Desc: "port where configtxlator will listen, default is $TC_RAWAPI_LATOR_PORT if set, 0 meand random", Type: "int", Def: DefaultLatorPort}
		fs.Entries[OPT_LATOR_PROTO] = cfg.Entry{Desc: "protobuf format, configtxlator will be used if set", Type: "string", Def: DefaultLatorProto}
		fs.Entries[OPT_FAB_MSPID] = cfg.Entry{Desc: "fabric MSPID, default is $TC_RAWAPI_MSPID if set", Type: "string", Def: DefaultFabMspId}
		fs.Entries[OPT_IO_SUFFIX] = cfg.Entry{Desc: "suffix with which the name of the processed file is appended as output (-out is ignored if supplied)", Type: "string", Def: ""}
		fs.Entries[OPT_PROC_TRY] = cfg.Entry{Desc: "number of invoke tries", Type: "int", Def: DefaultFabTry}
		fs.Entries[OPT_FAB_TLSCERT] = cfg.Entry{Desc: "path to TLS cert, default is $TC_RAWAPI_TLSCERTPATH if set", Type: "string", Def: DefaultPathTlsCert}

		modeExec = modeConfirmBatch
	case MODE_CONFIRMRAWAPI_FULL, MODE_CONFIRMRAWAPI_SC:
		fs.Entries["apikey"] = cfg.Entry{Desc: "api key, skip if not set, default is $TC_HTTP_API_KEY if set", Type: "string", Def: DefaultHttpApikey}
		fs.Entries[OPT_FAB_CC] = cfg.Entry{Desc: "chaincode to query", Type: "string", Def: "qscc"}
		fs.Entries[OPT_FAB_FUNC] = cfg.Entry{Desc: "function of --chaincode", Type: "string", Def: "GetBlockByTxID"}
		fs.Entries[OPT_HTTP_HOST] = cfg.Entry{Desc: "api host in http(s)://host:port format, default port is $TC_RAWAPI_HTTP_PORT if set", Type: "string", Def: "http://localhost:" + strconv.Itoa(DefaultHttpPort)}
		fs.Entries[OPT_IO_INPUT] = cfg.Entry{Desc: "| separated file with args for query, empty means stdin", Type: "string", Def: ""}
		fs.Entries[OPT_HTTP_QUERY] = cfg.Entry{Desc: "query endpoint", Type: "string", Def: "/query"}

		modeExec = modeConfirmRawapi
	case MODE_COMBINED_FULL, MODE_COMBINED_SC:
		fs.Entries[OPT_IO_BATCH] = cfg.Entry{Desc: "list of files to process, one file path per line, -in ignored if specified", Type: "string", Def: ""}
		fs.Entries[OPT_IO_BUFFER] = cfg.Entry{Desc: "fills up the temporary buffer with this many transactions, which first gets submitted, then confirmed, should be a large enough value for the submit transactions to be finalized", Type: "int", Def: DefaultBundleBuffered}
		fs.Entries[OPT_IO_INPUT] = cfg.Entry{Desc: ", separated list of files, which contain the output of previous submit attempts, empty causes panic", Type: "string", Def: ""}
		fs.Entries[OPT_IO_SUFFIX] = cfg.Entry{Desc: "suffix with which the name of the processed file is appended as output (-out is ignored if supplied)", Type: "string", Def: ""}

		fs.Entries[OPT_FAB_CERT] = cfg.Entry{Desc: "path to client pem certificate to populate the wallet with, default is $TC_RAWAPI_CERTPATH if set", Type: "string", Def: DefaultPathCert}
		fs.Entries[OPT_FAB_CC_CONFIRM] = cfg.Entry{Desc: "chaincode to invoke", Type: "string", Def: DefaultFabConfirmCc}
		fs.Entries[OPT_FAB_FUNC_CONFIRM] = cfg.Entry{Desc: "function of --chaincode", Type: "string", Def: DefaultFabConfirmFunc}
		fs.Entries[OPT_FAB_ENDPOINT] = cfg.Entry{Desc: "fabric endpoint, default is $TC_RAWAPI_PEERENDPOINT if set", Type: "string", Def: DefaultFabEndpoint}
		fs.Entries[OPT_FAB_GATEWAY] = cfg.Entry{Desc: "default gateway, default is $TC_RAWAPI_GATEWAYPEER if set", Type: "string", Def: DefaultFabGw}
		fs.Entries[OPT_FAB_KEYSTORE] = cfg.Entry{Desc: "path to client keystore, default is $TC_RAWAPI_KEYPATH if set", Type: "string", Def: DefaultPathKeystore}
		fs.Entries[OPT_FAB_MSPID] = cfg.Entry{Desc: "fabric MSPID, default is $TC_RAWAPI_MSPID if set", Type: "string", Def: DefaultFabMspId}
		fs.Entries[OPT_FAB_CC_SUBMIT] = cfg.Entry{Desc: "chaincode to invoke", Type: "string", Def: DefaultFabSubmitCc}
		fs.Entries[OPT_FAB_FUNC_SUBMIT] = cfg.Entry{Desc: "function of --chaincode", Type: "string", Def: DefaultFabSubmitFunc}
		fs.Entries[OPT_FAB_TLSCERT] = cfg.Entry{Desc: "path to TLS cert, default is $TC_RAWAPI_TLSCERTPATH if set", Type: "string", Def: DefaultPathTlsCert}

		fs.Entries[OPT_PROC_KEYNAME] = cfg.Entry{Desc: "the name of the field containing the unique identifier", Type: "string", Def: DefaultBundleKeyName}
		fs.Entries[OPT_PROC_KEYPOS] = cfg.Entry{Desc: "Nth field in -in that contains the unique identifier identified by -keyname", Type: "int", Def: DefaultBundleKeyPos}
		fs.Entries[OPT_PROC_KEYTYPE] = cfg.Entry{Desc: "type of -keyname, either 'string' or 'int'", Type: "string", Def: DefaultBundleKeyType}
		fs.Entries[OPT_PROC_TRY] = cfg.Entry{Desc: "number of invoke tries", Type: "int", Def: DefaultFabTry}

		fs.Entries[OPT_LATOR_BIND] = cfg.Entry{Desc: "address to bind configtxlator's rest api to, default is TC_RAWAPI_LATOR_BIND if set", Type: "string", Def: DefaultLatorBind}
		fs.Entries[OPT_LATOR_EXE] = cfg.Entry{Desc: "path to configtxlator (if empty, will dump protobuf as base64 encoded string), default is $TC_PATH_BIN/configtxlator if set", Type: "string", Def: DefaultLatorExe}
		fs.Entries[OPT_LATOR_PORT] = cfg.Entry{Desc: "port where configtxlator will listen, default is $TC_RAWAPI_LATOR_PORT if set, 0 meand random", Type: "int", Def: DefaultLatorPort}
		fs.Entries[OPT_LATOR_PROTO] = cfg.Entry{Desc: "protobuf format, configtxlator will be used if set", Type: "string", Def: DefaultLatorProto}

		modeExec = modeCombined
	case "help", "h", "-h", "--help":
		os.Args[1] = ""
		msg := helperUsage(fs.FlagSet)
		msg()
		os.Exit(0)
	case MODE_SUBMIT_FULL, MODE_SUBMIT_SC:
		fs.Entries[OPT_FAB_CERT] = cfg.Entry{Desc: "path to client pem certificate to populate the wallet with, default is $TC_RAWAPI_CERTPATH if set", Type: "string", Def: DefaultPathCert}
		fs.Entries[OPT_FAB_CC] = cfg.Entry{Desc: "chaincode to invoke", Type: "string", Def: DefaultFabSubmitCc}
		fs.Entries[OPT_FAB_ENDPOINT] = cfg.Entry{Desc: "fabric endpoint, default is $TC_RAWAPI_PEERENDPOINT if set", Type: "string", Def: DefaultFabEndpoint}
		fs.Entries[OPT_FAB_FUNC] = cfg.Entry{Desc: "function of --chaincode", Type: "string", Def: DefaultFabSubmitFunc}
		fs.Entries[OPT_FAB_GATEWAY] = cfg.Entry{Desc: "default gateway, default is $TC_RAWAPI_GATEWAYPEER if set", Type: "string", Def: DefaultFabGw}
		fs.Entries[OPT_IO_INPUT] = cfg.Entry{Desc: "file, which contains the parameters of one transaction per line, separated by |, empty means stdin", Type: "string", Def: ""}
		fs.Entries[OPT_PROC_KEYNAME] = cfg.Entry{Desc: "the name of the field containing the unique identifier", Type: "string", Def: DefaultBundleKeyName}
		fs.Entries[OPT_PROC_KEYPOS] = cfg.Entry{Desc: "Nth field in -in that contains the unique identifier identified by -keyname", Type: "int", Def: DefaultBundleKeyPos}
		fs.Entries[OPT_FAB_KEYSTORE] = cfg.Entry{Desc: "path to client keystore, default is $TC_RAWAPI_KEYPATH if set", Type: "string", Def: DefaultPathKeystore}
		fs.Entries[OPT_PROC_KEYTYPE] = cfg.Entry{Desc: "type of -keyname, either 'string' or 'int'", Type: "string", Def: DefaultBundleKeyType}
		fs.Entries[OPT_FAB_MSPID] = cfg.Entry{Desc: "fabric MSPID, default is $TC_RAWAPI_MSPID if set", Type: "string", Def: DefaultFabMspId}
		fs.Entries[OPT_PROC_TRY] = cfg.Entry{Desc: "number of invoke tries", Type: "int", Def: DefaultFabTry}
		fs.Entries[OPT_FAB_TLSCERT] = cfg.Entry{Desc: "path to TLS cert, default is $TC_RAWAPI_TLSCERTPATH if set", Type: "string", Def: DefaultPathTlsCert}

		modeExec = modeSubmit
	case MODE_SUBMITBATCH_FULL, MODE_SUBMITBATCH_SC:
		fs.Entries[OPT_IO_BATCH] = cfg.Entry{Desc: "list of files to process, one file path per line, -in ignored if specified", Type: "string", Def: ""}
		fs.Entries[OPT_FAB_CERT] = cfg.Entry{Desc: "path to client pem certificate to populate the wallet with, default is $TC_RAWAPI_CERTPATH if set", Type: "string", Def: DefaultPathCert}
		fs.Entries[OPT_FAB_CC] = cfg.Entry{Desc: "chaincode to invoke", Type: "string", Def: DefaultFabSubmitCc}
		fs.Entries[OPT_FAB_ENDPOINT] = cfg.Entry{Desc: "fabric endpoint, default is $TC_RAWAPI_PEERENDPOINT if set", Type: "string", Def: DefaultFabEndpoint}
		fs.Entries[OPT_FAB_FUNC] = cfg.Entry{Desc: "function of --chaincode", Type: "string", Def: DefaultFabSubmitFunc}
		fs.Entries[OPT_FAB_GATEWAY] = cfg.Entry{Desc: "default gateway, default is $TC_RAWAPI_GATEWAYPEER if set", Type: "string", Def: DefaultFabGw}
		fs.Entries[OPT_IO_INPUT] = cfg.Entry{Desc: ", separated list of files, which contain the | separated parameters of one transaction per line, empty causes panic", Type: "string", Def: ""}
		fs.Entries[OPT_PROC_KEYNAME] = cfg.Entry{Desc: "the name of the field containing the unique identifier", Type: "string", Def: DefaultBundleKeyName}
		fs.Entries[OPT_PROC_KEYPOS] = cfg.Entry{Desc: "Nth field in -in that contains the unique identifier identified by -keyname", Type: "int", Def: DefaultBundleKeyPos}
		fs.Entries[OPT_FAB_KEYSTORE] = cfg.Entry{Desc: "path to client keystore, default is $TC_RAWAPI_KEYPATH if set", Type: "string", Def: DefaultPathKeystore}
		fs.Entries[OPT_PROC_KEYTYPE] = cfg.Entry{Desc: "type of -keyname, either 'string' or 'int'", Type: "string", Def: DefaultBundleKeyType}
		fs.Entries[OPT_FAB_MSPID] = cfg.Entry{Desc: "fabric MSPID, default is $TC_RAWAPI_MSPID if set", Type: "string", Def: DefaultFabMspId}
		fs.Entries[OPT_IO_SUFFIX] = cfg.Entry{Desc: "suffix with which the name of the processed file is appended as output (-out is ignored if supplied)", Type: "string", Def: ""}
		fs.Entries[OPT_PROC_TRY] = cfg.Entry{Desc: "number of invoke tries", Type: "int", Def: DefaultFabTry}
		fs.Entries[OPT_FAB_TLSCERT] = cfg.Entry{Desc: "path to TLS cert, default is $TC_RAWAPI_TLSCERTPATH if set", Type: "string", Def: DefaultPathTlsCert}

		modeExec = modeSubmitBatch
	case MODE_RESUBMIT_FULL, MODE_RESUBMIT_SC:
		shift := strconv.Itoa(reflect.TypeOf(PSV{}).NumField())
		fs.Entries[OPT_FAB_CERT] = cfg.Entry{Desc: "path to client pem certificate to populate the wallet with, default is $TC_RAWAPI_CERTPATH if set", Type: "string", Def: DefaultPathCert}
		fs.Entries[OPT_FAB_CC] = cfg.Entry{Desc: "chaincode to invoke", Type: "string", Def: "te-food-bundles"}
		fs.Entries[OPT_FAB_ENDPOINT] = cfg.Entry{Desc: "fabric endpoint, default is $TC_RAWAPI_PEERENDPOINT if set", Type: "string", Def: DefaultFabEndpoint}
		fs.Entries[OPT_FAB_FUNC] = cfg.Entry{Desc: "function of --chaincode", Type: "string", Def: "CreateBundle"}
		fs.Entries[OPT_FAB_GATEWAY] = cfg.Entry{Desc: "default gateway", Type: "string", Def: DefaultFabGw}
		fs.Entries[OPT_IO_INPUT] = cfg.Entry{Desc: "file, which contains the output of previous submit attempt, empty means stdin", Type: "string", Def: ""}
		fs.Entries[OPT_PROC_KEYNAME] = cfg.Entry{Desc: "the name of the field containing the unique identifier", Type: "string", Def: DefaultBundleKeyName}
		fs.Entries[OPT_PROC_KEYPOS] = cfg.Entry{Desc: shift + "+Nth field in -in that contains the unique identifier identified by -keyname", Type: "int", Def: DefaultBundleKeyPos}
		fs.Entries[OPT_FAB_KEYSTORE] = cfg.Entry{Desc: "path to client keystore, default is $TC_RAWAPI_KEYPATH if set", Type: "string", Def: DefaultPathKeystore}
		fs.Entries[OPT_PROC_KEYTYPE] = cfg.Entry{Desc: "type of -keyname, either 'string' or 'int'", Type: "string", Def: DefaultBundleKeyType}
		fs.Entries[OPT_FAB_MSPID] = cfg.Entry{Desc: "fabric MSPID, default is $TC_RAWAPI_MSPID if set", Type: "string", Def: DefaultFabMspId}
		fs.Entries[OPT_PROC_TRY] = cfg.Entry{Desc: "number of invoke tries", Type: "int", Def: DefaultFabTry}
		fs.Entries[OPT_FAB_TLSCERT] = cfg.Entry{Desc: "path to TLS cert, default is $TC_RAWAPI_TLSCERTPATH if set", Type: "string", Def: DefaultPathTlsCert}

		modeExec = modeResubmit
	default:
		os.Args[1] = ""
		usage := helperUsage(fs.FlagSet)
		usage()
		helperPanic("invalid mode '" + os.Args[1] + "'")
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

	Lout(LOG_INFO, "start time", StatStart.Format(time.RFC3339))
	Lout(LOG_INFO, "end time", statEnd.Format(time.RFC3339))
	Lout(LOG_INFO, "elapsed time", statElapsed.Truncate(time.Second).String())
	Lout(LOG_INFO, "trx per hour", float64(StatTrs)/statElapsed.Hours())
	Lout(LOG_INFO, "trx per min", float64(StatTrs)/statElapsed.Minutes())
	Lout(LOG_INFO, "trx per sec", float64(StatTrs)/statElapsed.Seconds())

	// endregion: stats
}

// endregion: main
// region: modes

func modeConfirm(config *cfg.Config) {

	// region: i/o

	input := config.Entries[OPT_IO_INPUT].Value.(string)
	output := config.Entries[OPT_IO_OUTPUT].Value.(string)

	batch, sent := ioCombined(input, output, procParsePSV)
	defer sent.Close()
	Lout(LOG_INFO, "# of lines", len(*batch))

	// endregion: i/o
	// region: client

	client, err := fabricClient(config)
	if err != nil {
		helperPanic("cannot init fabric gw", err.Error())
	}
	Lout(LOG_DEBUG, "fabric client", client)

	// endregion: client
	// region: configtxlator

	err = fabricLator(config, client)
	if err != nil {
		helperPanic("error while initializing configtxlator")
	}
	Lout(LOG_INFO, "protobuf decode", client.Lator.Which, fmt.Sprintf("%s:%d", client.Lator.Bind, client.Lator.Port))

	// endregion: configtxlator
	// region: process batch

	for _, bundle := range *batch {
		StatTrs++
		progress := helperProgress(StatTrs, len(*batch))

		if bundle.Status != STATUS_SUBMIT_OK && !strings.HasPrefix(bundle.Status, STATUS_CONFIRM_ERROR_PREFIX) {
			Lout(LOG_INFO, progress, "bypassed status", bundle.Status)
			ioOutputAppend(sent, bundle, procCompilePSV)
			continue
		}
		if !TxRegexp.MatchString(bundle.Txid) {
			bundle.Status = STATUS_CONFIRM_ERROR_TXID
			Lout(LOG_ERR, progress, "invalid txid", bundle.Txid)
			ioOutputAppend(sent, bundle, procCompilePSV)
			continue
		}

		err := fabricConfirm(config, client, &bundle)
		if err != nil {
			Lout(LOG_NOTICE, progress, err)
		} else {
			Lout(LOG_INFO, progress, "success", bundle.Key, bundle.Txid)
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

	client, err := fabricClient(config)
	if err != nil {
		helperPanic("cannot init fabric gw", err.Error())
	}
	Lout(LOG_DEBUG, "fabric client", client)

	// endregion: client
	// region: configtxlator

	err = fabricLator(config, client)
	if err != nil {
		helperPanic("error while initializing configtxlator")
	}
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
			StatTrs++
			progress := helperProgress(StatTrs, count)

			if bundle.Status != STATUS_SUBMIT_OK && !strings.HasPrefix(bundle.Status, STATUS_CONFIRM_ERROR_PREFIX) {
				Lout(LOG_INFO, progress, "bypassed status", bundle.Status)
				ioOutputAppend(output, bundle, procCompilePSV)
				continue
			}
			if !TxRegexp.MatchString(bundle.Txid) {
				bundle.Status = STATUS_CONFIRM_ERROR_TXID
				Lout(LOG_ERR, progress, "invalid txid", bundle.Txid)
				ioOutputAppend(output, bundle, procCompilePSV)
				continue
			}

			err := fabricConfirm(config, client, &bundle)
			if err != nil {
				Lout(LOG_NOTICE, progress, err)
			} else {
				Lout(LOG_INFO, progress, "success", fmt.Sprintf("%12s", bundle.Key), file, output.Name())
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
	baseurl.QueryArgs().Add("channel", config.Entries["channel"].Value.(string))
	baseurl.QueryArgs().Add("chaincode", config.Entries[OPT_FAB_CC].Value.(string))
	baseurl.QueryArgs().Add("function", config.Entries[OPT_FAB_FUNC].Value.(string))
	baseurl.QueryArgs().Add("proto_decode", "common.Block")
	baseurl.QueryArgs().Add("args", config.Entries["channel"].Value.(string))
	Lout(LOG_INFO, "base url", baseurl.String())

	// endregion: base url
	// region: process batch

	for _, item := range *batch {

		StatTrs++
		progress := helperProgress(StatTrs, len(*batch))

		// region: validate input

		if item.Status != STATUS_SUBMIT_OK && !strings.HasPrefix(item.Status, STATUS_CONFIRM_ERROR_PREFIX) {
			Lout(LOG_INFO, progress, "bypassed status", item.Status)
			ioOutputAppend(outFile, item, procCompilePSV)
			continue
		}
		if !TxRegexp.MatchString(item.Txid) {
			item.Status = STATUS_CONFIRM_ERROR_TXID
			Lout(LOG_ERR, progress, "invalid txid", item.Txid)
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
		if len(config.Entries["apikey"].Value.(string)) != 0 {
			req.Header.Set(API_KEY_HEADER, config.Entries["apikey"].Value.(string))
		}
		Lout(LOG_DEBUG, progress, url)

		resp := fasthttp.AcquireResponse()
		defer fasthttp.ReleaseResponse(resp)

		// endregion: prepare request
		// region: query

		err := client.Do(req, resp)
		if err != nil {
			item.Status = STATUS_CONFIRM_ERROR_QUERY
			item.Response = string(err.Error())
			Lout(LOG_ERR, progress, "http client error", err)
			ioOutputAppend(outFile, item, procCompilePSV)
			continue
		}

		// endregion: query
		// region: check status

		if resp.StatusCode() != fasthttp.StatusOK {
			item.Status = STATUS_CONFIRM_ERROR_PREFIX + strconv.Itoa(resp.StatusCode())
			item.Response = string(resp.Body())
			Lout(LOG_ERR, progress, "response status indicates an error", resp.StatusCode(), item.Response)
			ioOutputAppend(outFile, item, procCompilePSV)
			continue
		}

		// endregion: check status
		// region: get block

		blockData, blockDataType, _, err := jsonparser.Get(resp.Body(), "result")
		if blockDataType != jsonparser.Object || err != nil {
			item.Status = STATUS_CONFIRM_ERROR_HEADER
			item.Response = err.Error()
			Lout(LOG_ERR, progress, "no parsable header in response", item.Response)
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
		Lout(LOG_DEBUG, progress, item.Status)
		Lout(LOG_DEBUG, progress, item.Key)
		Lout(LOG_DEBUG, progress, item.Txid)
		Lout(LOG_DEBUG, progress, item.Response)
		Lout(LOG_DEBUG, progress, item.Payload)
		ioOutputAppend(outFile, item, procCompilePSV)
		Lout(LOG_INFO, progress, "done")

		// endregion: done

	}

	// endregion: process batch

}

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

	if len(suffix) == 0 {
		output = ioOutputOpen(config.Entries[OPT_IO_OUTPUT].Value.(string))
		defer output.Close()
	}

	// endregion: output
	// region: client

	client, err := fabricClient(config)
	if err != nil {
		helperPanic("cannot init fabric gw", err.Error())
	}
	Lout(LOG_DEBUG, "fabric client", client)

	// endregion: client
	// region: configtxlator

	err = fabricLator(config, client)
	if err != nil {
		helperPanic("error while initializing configtxlator")
	}
	Lout(LOG_INFO, "protobuf decode", client.Lator.Which, fmt.Sprintf("%s:%d", client.Lator.Bind, client.Lator.Port))

	// endregion: configtxlator
	// region: process batch

	bufferSize := config.Entries[OPT_IO_BUFFER].Value.(int)
	count = 2 * count

	for _, file := range input {

		// region: read batch

		batchPointer := ioRead(file, procParseBundles)
		if len(suffix) > 0 {
			output = ioOutputOpen(file + suffix)
			defer output.Close()
		}
		batch := *batchPointer // needs to be dereferenced

		// endregion: read batch

		for i := 0; i < len(batch); i += bufferSize {

			// region: read buffer

			bufferEnd := i + bufferSize
			if bufferEnd > len(batch) {
				bufferEnd = len(batch)
			}

			// submit := batch[i:bufferEnd]
			var confirm []PSV

			// endregion: read buffer
			// region: submit buffer

			for _, bundle := range batch[i:bufferEnd] {
				StatTrs++
				progress := helperProgress(StatTrs, count)

				err := fabricSubmit(config, client, &bundle)
				if err != nil {
					Lout(LOG_NOTICE, progress, err)
				} else {
					Lout(LOG_INFO, progress, " submited", fmt.Sprintf("%12s", bundle.Key), file, output.Name())
				}
				confirm = append(confirm, bundle)
			}

			// endregion: submit buffer
			// region: confirm and write buffer

			for _, bundle := range confirm {
				StatTrs++
				progress := helperProgress(StatTrs, count)

				if bundle.Status != STATUS_SUBMIT_OK && !strings.HasPrefix(bundle.Status, STATUS_CONFIRM_ERROR_PREFIX) {
					Lout(LOG_INFO, progress, "bypassed status", bundle.Status)
					ioOutputAppend(output, bundle, procCompilePSV)
					continue
				}
				if !TxRegexp.MatchString(bundle.Txid) {
					bundle.Status = STATUS_CONFIRM_ERROR_TXID
					Lout(LOG_ERR, progress, "invalid txid", bundle.Txid)
					ioOutputAppend(output, bundle, procCompilePSV)
					continue
				}

				err = fabricConfirm(config, client, &bundle)
				if err != nil {
					Lout(LOG_NOTICE, progress, err)
				} else {
					Lout(LOG_INFO, progress, "confirmed", fmt.Sprintf("%12s", bundle.Key), file, output.Name())
				}
				ioOutputAppend(output, bundle, procCompilePSV)
			}

			// endregion: confirm and write buffer

		}
		if len(suffix) > 0 {
			output.Close()
		}
	}

	// endregion: process

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

	client, err := fabricClient(config)
	if err != nil {
		helperPanic("cannot init fabric gw", err.Error())
	}
	Lout(LOG_DEBUG, "fabric client", client)

	// endregion: client
	// region: process batch

	for _, bundle := range *batch {

		StatTrs++
		progress := helperProgress(StatTrs, len(*batch))

		if !strings.HasPrefix(bundle.Status, STATUS_SUBMIT_ERROR_PREFIX) {
			Lout(LOG_INFO, progress, "bypassed status", bundle.Status)
			ioOutputAppend(sent, bundle, procCompilePSV)
			continue
		}

		err := fabricSubmit(config, client, &bundle)
		if err != nil {
			Lout(LOG_NOTICE, progress, err)
		} else {
			Lout(LOG_INFO, progress, "success", bundle.Key, bundle.Txid)
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

	client, err := fabricClient(config)
	if err != nil {
		helperPanic("cannot init fabric gw", err.Error())
	}
	Lout(LOG_DEBUG, "fabric client", client)

	// endregion: client
	// region: process batch

	for _, bundle := range *batch {
		StatTrs++
		progress := helperProgress(StatTrs, len(*batch))

		err := fabricSubmit(config, client, &bundle)

		if err != nil {
			Lout(LOG_NOTICE, progress, err)
		} else {
			Lout(LOG_INFO, progress, "success", bundle.Key, bundle.Txid)
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

	client, err := fabricClient(config)
	if err != nil {
		helperPanic("cannot init fabric gw", err.Error())
	}
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
			StatTrs++
			progress := helperProgress(StatTrs, count)

			err := fabricSubmit(config, client, &bundle)
			if err != nil {
				Lout(LOG_NOTICE, progress, err)
			} else {
				Lout(LOG_INFO, progress, "success", fmt.Sprintf("%12s", bundle.Key), file, output.Name())
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

func fabricClient(config *cfg.Config) (*fabric.Client, error) {
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
		return nil, err
	}

	Lout(LOG_DEBUG, "fabric client instance", client)
	return &client, nil
}

func fabricConfirm(config *cfg.Config, client *fabric.Client, bundle *PSV) error {

	// region: shorten variables coming from config

	if config.Entries[OPT_FAB_CC_CONFIRM].Value != nil {
		config.Entries[OPT_FAB_CC] = config.Entries[OPT_FAB_CC_CONFIRM]
	}
	if config.Entries[OPT_FAB_FUNC_CONFIRM].Value != nil {
		config.Entries[OPT_FAB_FUNC] = config.Entries[OPT_FAB_FUNC_CONFIRM]
	}

	channel := config.Entries["channel"].Value.(string)
	chaincode := config.Entries[OPT_FAB_CC].Value.(string)
	function := config.Entries[OPT_FAB_FUNC].Value.(string)
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
	// region: response

	var response *fabric.Response
	var responseErr *fabric.ResponseError

	for cnt := 1; cnt <= try; cnt++ {
		request.Args = []string{channel, bundle.Txid}
		response, responseErr = fabric.Query(client, &request)
		if responseErr == nil {
			Lout(LOG_DEBUG, "error in fabric query", responseErr)
			break
		}
		Lout(LOG_NOTICE, fmt.Sprintf("unsuccessful confirm attempt %d/%d", cnt, try))
	}
	if responseErr != nil {
		bundle.Response = responseErr.Error()
		bundle.Status = STATUS_CONFIRM_ERROR_QUERY
		return responseErr
	}

	// endregion: response
	// region: proto decode

	if len(proto) != 0 {
		Lout(LOG_DEBUG, "protobuf format", proto)

		block, err := client.Lator.Exe(response.Result, proto)
		if err != nil {
			bundle.Response = err.Error()
			bundle.Status = STATUS_CONFIRM_ERROR_DECODE
			return err
		}
		response.Result = block
	}

	// endregion: proto decode
	// region: parse header

	headerStruct, err := procParseHeader(response.Result)
	if err != nil {
		bundle.Response = err.Error()
		bundle.Status = STATUS_CONFIRM_ERROR_HEADER
		return err
	}

	// endregion: parse header
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

/*
func fabricInvoke(config *cfg.Config, client *fabric.Client, args []string) (*fabric.Response, *fabric.ResponseError) {
	request := fabric.Request{
		Chaincode: config.Entries[OPT_FAB_CHAINCODE].Value.(string),
		Channel:   config.Entries["channel"].Value.(string),
		Function:  config.Entries[OPT_FAB_FUNCTION].Value.(string),
		Args:      args,
	}
	Lout(LOG_DEBUG, "fabric invoke request", request)

	response, err := fabric.Invoke(client, &request)
	if err != nil {
		Lout(LOG_DEBUG, "error in fabric invoke", err)
		return nil, err
	}
	Lout(LOG_DEBUG, "fabric invoke response", response)

	return response, nil
}
*/

func fabricLator(config *cfg.Config, client *fabric.Client) error {
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

	Lout(LOG_INFO, "waiting for configtxlator launch", DefaultLatorSleep)
	time.Sleep(time.Duration(DefaultLatorSleep) * time.Second)
	return nil
}

func fabricSubmit(config *cfg.Config, client *fabric.Client, bundle *PSV) error {

	// region: shorten variables coming from config

	if config.Entries[OPT_FAB_CC_SUBMIT].Value != nil {
		config.Entries[OPT_FAB_CC] = config.Entries[OPT_FAB_CC_SUBMIT]
	}
	if config.Entries[OPT_FAB_FUNC_SUBMIT].Value != nil {
		config.Entries[OPT_FAB_FUNC] = config.Entries[OPT_FAB_FUNC_SUBMIT]
	}

	chaincode := config.Entries[OPT_FAB_CC].Value.(string)
	channel := config.Entries["channel"].Value.(string)
	function := config.Entries[OPT_FAB_FUNC].Value.(string)

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

func helperProgress(doneTransactions, totalTransactions int) string {
	// Calculate progress percentage
	percentage := (float64(doneTransactions) / float64(totalTransactions)) * 100

	// Calculate elapsed time
	elapsedTime := time.Since(StatStart)

	// Calculate remaining time
	remainingTransactions := totalTransactions - doneTransactions
	transactionsPerSecond := float64(doneTransactions) / elapsedTime.Seconds()
	remainingTime := time.Duration(float64(remainingTransactions) / transactionsPerSecond * float64(time.Second))

	// Format elapsed time and remaining time as HH:MM:SS
	elapsedTimeFormatted := helperProgressDuration(elapsedTime)
	remainingTimeFormatted := helperProgressDuration(remainingTime)

	// Format and return the result as a string
	formattedString := fmt.Sprintf("progress: %6.2f%% %7d/%-7d elapsed: %s remaining: %s tx/s: %6.2f", percentage, doneTransactions, totalTransactions, elapsedTimeFormatted, remainingTimeFormatted, transactionsPerSecond)

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

			format := "  %-18s  %s\n"
			fmt.Printf(format, "confirm (c)", "iterates over the output of submit/resubmit and query via fabric gateway for block number and data hash against supplied chaincode and function")
			fmt.Printf(format, "confirmBatch (cb)", "iterates over the output of submit/resubmit and query via fabric sdk for block number and data hash against supplied chaincode and function")
			fmt.Printf(format, "confirmRawapi (cr)", "iterates over the output of submit/resubmit and query via Rawapi for block number and data hash against supplied chaincode and function")
			fmt.Printf(format, "combined (co)", "combination of confirmBatch and submitBatch")
			fmt.Printf(format, "help (h)", "produces this")
			// fmt.Printf(format, "psv2json", "convert PSV format to JSON for server-side batch processing")
			fmt.Printf(format, "resubmit (rs)", "iterates over the output of submit and retries unsuccessful attempts")
			fmt.Printf(format, "submit (s)", "iterates over input batch and submit line by line via direct fabric gateway link")
			fmt.Printf(format, "submitBatch (sb)", "iterates over list of files with bundles to be processed and submit line by line via direct fabric gateway link")
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

// endregion: io
// region: proc

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

	// region: get header

	blockHeader, blockHeaderType, _, err := jsonparser.Get(response, "header")
	if err != nil {
		return nil, err
	}
	if blockHeaderType != jsonparser.Object {
		return nil, errors.New("header type mismatch")
	}

	// endregion: get header
	// region: get block #

	responseHeader.Number, err = jsonparser.GetString(blockHeader, "number")
	if err != nil {
		return nil, err
	}

	// endregion: block #
	// region: parse or cache

	if _, exists := BlockCache[responseHeader.Number]; exists {
		responseHeader = BlockCache[responseHeader.Number]
	} else {

		// region: parse .result.header

		responseHeader.DataHash, err = jsonparser.GetString(blockHeader, "data_hash")
		if err != nil {
			return nil, err
		}

		responseHeader.PreviousHash, err = jsonparser.GetString(blockHeader, "previous_hash")
		if err != nil {
			return nil, err
		}

		// endregion: parse .result.header
		// region: get payload (.result.data.data)

		blockPayload, blockPayloadType, _, err := jsonparser.Get(response, "data", "data")
		if err != nil {
			return nil, err
		}
		if blockPayloadType != jsonparser.Array {
			return nil, errors.New("payload type mismatch")
		}

		// endregion: get payload
		// region: parse timestamp and length from payload

		responseHeader.Timestamp, err = jsonparser.GetString(blockPayload, "[0]", "payload", "header", "channel_header", "timestamp")
		if err != nil {
			return nil, err
		}

		responseHeader.Length = 0
		_, err = jsonparser.ArrayEach(blockPayload, func(value []byte, dataType jsonparser.ValueType, offset int, err error) {
			responseHeader.Length++
			// fmt.Println(header.Length)
		})
		if err != nil {
			return nil, err
		}

		// endregion: parse timestamp and length from payload
		// region: fill blockCache

		BlockCache[responseHeader.Number] = responseHeader

		// endregion: blockCache

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
