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
	DefaultBundleKeyName string = "bundle_id"
	DefaultBundleKeyPos  int    = 0
	DefaultBundleKeyType string = "string"
	DefaultFabChannel    string = "trustchain-test"
	DefaultFabClient     string = "org1-client"
	DefaultFabEndpoint   string = "localhost:7051"
	DefaultFabGw         string = "localhost"
	DefaultFabTry        int    = 10
	DefaultFabMspId      string = "Org1MSP"
	DefaultHttpApikey    string = ""
	DefaultHttpPort      int    = 5088
	DefaultLoglevel      int    = 7
	DefaultPathCert      string = "./cert.pem"
	DefaultPathKeystore  string = "./keystore"
	DefaultPathTlsCert   string = "./tlscert.pem"

	Logger *log.Logger
	Lout   func(s ...interface{}) *[]error

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

	STATUS_CONFIRM_ERROR_PREFIX string = "CONFIRM_ERROR_"
	STATUS_CONFIRM_ERROR_TXID   string = STATUS_CONFIRM_ERROR_PREFIX + "TXID"
	STATUS_CONFIRM_ERROR_CLIENT string = STATUS_CONFIRM_ERROR_PREFIX + "CLIENT"
	STATUS_CONFIRM_ERROR_HEADER string = STATUS_CONFIRM_ERROR_PREFIX + "HEADER"
	STATUS_CONFIRM_OK           string = "CONFIRM_OK"
	STATUS_PARSE_ERROR          string = "PARSE_ERROR"
	STATUS_SUBMIT_ERROR_PREFIX  string = "SUBMIT_ERROR_"
	STATUS_SUBMIT_ERROR_INVOKE  string = STATUS_SUBMIT_ERROR_PREFIX + "INVOKE"
	STATUS_SUBMIT_ERROR_KEY     string = STATUS_SUBMIT_ERROR_PREFIX + "KEY"
	STATUS_SUBMIT_ERROR_TXID    string = STATUS_SUBMIT_ERROR_PREFIX + "TXID"
	STATUS_SUBMIT_OK            string = "SUBMIT_OK"

	TC_FAB_CHANNEL  string = "TC_CHANNEL1_NAME"
	TC_FAB_CLIENT   string = "TC_ORG1_CLIENT"
	TC_FAB_ENDPOINT string = "TC_RAWAPI_PEERENDPOINT"
	TC_FAB_GW       string = "TC_RAWAPI_GATEWAYPEER"
	TC_FAB_MSPID    string = "TC_RAWAPI_MSPID"
	TC_HTTP_APIKEY  string = "TC_HTTP_API_KEY"
	TC_HTTP_PORT    string = "TC_RAWAPI_HTTP_PORT"
	// TC_LATOR_BIND    string = "TC_RAWAPI_LATOR_BIND"
	// TC_LATOR_PORT    string = "TC_RAWAPI_LATOR_PORT"
	// TC_LATOR_WHICH   string = "TC_RAWAPI_LATOR_WHICH"
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

		envCmd := exec.Command("bash", "-c", "source "+rc+" ; echo '<<<ENVIRONMENT>>>' ; env")
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
					os.Setenv(kv[0], kv[1])

					switch kv[0] {
					case TC_FAB_CHANNEL:
						DefaultFabChannel = kv[1]
					case TC_FAB_CLIENT:
						DefaultFabClient = kv[1]
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
					// case TC_LATOR_BIND:
					// 	DefaultLatorBind = kv[1]
					// case TC_LATOR_PORT:
					// 	_, err := strconv.Atoi(kv[1])
					// 	if err == nil {
					// 		DefaultLatorPort, _ = strconv.Atoi(kv[1])
					// 	}
					// case TC_LATOR_WHICH:
					// 	DefaultLatorWhich = kv[1]
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
		"channel":  {Desc: "[string] as channel id, default is $TC_CHANNEL1_NAME if set", Type: "string", Def: DefaultFabChannel},
		"loglevel": {Desc: "loglevel as syslog.Priority, default is $TC_RAWAPI_LOGLEVEL if set", Type: "int", Def: DefaultLoglevel},
		"out":      {Desc: "path for output, empty means stdout", Type: "string", Def: ""},
	}

	// endregion: cfg/fs, common args
	// region: evaluate mode

	var modeExec ModeFunction

	if len(os.Args) == 1 {
		usage := helperUsage(nil)
		usage()
		helperPanic("missing mode selector")
	}

	switch os.Args[1] {
	case "confirm", "c":
		fs.Entries["cert"] = cfg.Entry{Desc: "path to client pem certificate to populate the wallet with", Type: "string", Def: DefaultPathCert}
		fs.Entries["chaincode"] = cfg.Entry{Desc: "chaincode to invoke", Type: "string", Def: "qscc"}
		fs.Entries["endpoint"] = cfg.Entry{Desc: "fabric endpoint", Type: "string", Def: DefaultFabEndpoint}
		fs.Entries["function"] = cfg.Entry{Desc: "function of --chaincode", Type: "string", Def: "GetBlockByTxID"}
		fs.Entries["gateway"] = cfg.Entry{Desc: "default gateway", Type: "string", Def: DefaultFabGw}
		fs.Entries["in"] = cfg.Entry{Desc: "file, which contains the output of previous submit attempt, empty means stdin", Type: "string", Def: ""}
		fs.Entries["keystore"] = cfg.Entry{Desc: "path to client keystore", Type: "string", Def: DefaultPathKeystore}
		fs.Entries["mspid"] = cfg.Entry{Desc: "fabric MSPID", Type: "string", Def: DefaultFabMspId}
		fs.Entries["try"] = cfg.Entry{Desc: "number of invoke tries", Type: "int", Def: DefaultFabTry}
		fs.Entries["tlscert"] = cfg.Entry{Desc: "path to TLS cert", Type: "string", Def: DefaultPathTlsCert}

		modeExec = modeConfirm
	case "confirmRawapi", "cr":
		fs.Entries["apikey"] = cfg.Entry{Desc: "api key, skip if not set, default is $TC_HTTP_API_KEY if set", Type: "string", Def: DefaultHttpApikey}
		fs.Entries["chaincode"] = cfg.Entry{Desc: "chaincode to query", Type: "string", Def: "qscc"}
		fs.Entries["function"] = cfg.Entry{Desc: "function of --chaincode", Type: "string", Def: "GetBlockByTxID"}
		fs.Entries["host"] = cfg.Entry{Desc: "api host in http(s)://host:port format, default port is $TC_RAWAPI_HTTP_PORT if set", Type: "string", Def: "http://localhost:" + strconv.Itoa(DefaultHttpPort)}
		fs.Entries["in"] = cfg.Entry{Desc: "| separated file with args for query, empty means stdin", Type: "string", Def: ""}
		fs.Entries["query"] = cfg.Entry{Desc: "query endpoint", Type: "string", Def: "/query"}

		modeExec = modeConfirmRawapi
	case "help", "h", "-h", "--help":
		os.Args[1] = ""
		msg := helperUsage(fs.FlagSet)
		msg()
		os.Exit(0)
	case "submit", "s":
		fs.Entries["cert"] = cfg.Entry{Desc: "path to client pem certificate to populate the wallet with", Type: "string", Def: DefaultPathCert}
		fs.Entries["chaincode"] = cfg.Entry{Desc: "chaincode to invoke", Type: "string", Def: "te-food-bundles"}
		fs.Entries["endpoint"] = cfg.Entry{Desc: "fabric endpoint", Type: "string", Def: DefaultFabEndpoint}
		fs.Entries["function"] = cfg.Entry{Desc: "function of --chaincode", Type: "string", Def: "CreateBundle"}
		fs.Entries["gateway"] = cfg.Entry{Desc: "default gateway", Type: "string", Def: DefaultFabGw}
		fs.Entries["in"] = cfg.Entry{Desc: "file, which contains the parameters of one transaction per line, separated by |, empty means stdin", Type: "string", Def: ""}
		fs.Entries["keyname"] = cfg.Entry{Desc: "the name of the field containing the unique identifier", Type: "string", Def: DefaultBundleKeyName}
		fs.Entries["keypos"] = cfg.Entry{Desc: "Nth field in -in that contains the unique identifier identified by -keyname", Type: "int", Def: DefaultBundleKeyPos}
		fs.Entries["keystore"] = cfg.Entry{Desc: "path to client keystore", Type: "string", Def: DefaultPathKeystore}
		fs.Entries["keytype"] = cfg.Entry{Desc: "type of -keyname, either 'string' or 'int'", Type: "string", Def: DefaultBundleKeyType}
		fs.Entries["mspid"] = cfg.Entry{Desc: "fabric MSPID", Type: "string", Def: DefaultFabMspId}
		fs.Entries["try"] = cfg.Entry{Desc: "number of invoke tries", Type: "int", Def: DefaultFabTry}
		fs.Entries["tlscert"] = cfg.Entry{Desc: "path to TLS cert", Type: "string", Def: DefaultPathTlsCert}

		modeExec = modeSubmit
	case "submitBatch", "sb":
		fs.Entries["cert"] = cfg.Entry{Desc: "path to client pem certificate to populate the wallet with", Type: "string", Def: DefaultPathCert}
		fs.Entries["chaincode"] = cfg.Entry{Desc: "chaincode to invoke", Type: "string", Def: "te-food-bundles"}
		fs.Entries["endpoint"] = cfg.Entry{Desc: "fabric endpoint", Type: "string", Def: DefaultFabEndpoint}
		fs.Entries["function"] = cfg.Entry{Desc: "function of --chaincode", Type: "string", Def: "CreateBundle"}
		fs.Entries["gateway"] = cfg.Entry{Desc: "default gateway", Type: "string", Def: DefaultFabGw}
		fs.Entries["in"] = cfg.Entry{Desc: ", separated list of files, which contain the | separated parameters of one transaction per line", Type: "string", Def: ""}
		fs.Entries["keyname"] = cfg.Entry{Desc: "the name of the field containing the unique identifier", Type: "string", Def: DefaultBundleKeyName}
		fs.Entries["keypos"] = cfg.Entry{Desc: "Nth field in -in that contains the unique identifier identified by -keyname", Type: "int", Def: DefaultBundleKeyPos}
		fs.Entries["keystore"] = cfg.Entry{Desc: "path to client keystore", Type: "string", Def: DefaultPathKeystore}
		fs.Entries["keytype"] = cfg.Entry{Desc: "type of -keyname, either 'string' or 'int'", Type: "string", Def: DefaultBundleKeyType}
		fs.Entries["mspid"] = cfg.Entry{Desc: "fabric MSPID", Type: "string", Def: DefaultFabMspId}
		fs.Entries["try"] = cfg.Entry{Desc: "number of invoke tries", Type: "int", Def: DefaultFabTry}
		fs.Entries["tlscert"] = cfg.Entry{Desc: "path to TLS cert", Type: "string", Def: DefaultPathTlsCert}

		modeExec = modeSubmitBatch
	case "resubmit", "r":
		shift := strconv.Itoa(reflect.TypeOf(PSV{}).NumField())
		fs.Entries["cert"] = cfg.Entry{Desc: "path to client pem certificate to populate the wallet with", Type: "string", Def: DefaultPathCert}
		fs.Entries["chaincode"] = cfg.Entry{Desc: "chaincode to invoke", Type: "string", Def: "te-food-bundles"}
		fs.Entries["endpoint"] = cfg.Entry{Desc: "fabric endpoint", Type: "string", Def: DefaultFabEndpoint}
		fs.Entries["function"] = cfg.Entry{Desc: "function of --chaincode", Type: "string", Def: "CreateBundle"}
		fs.Entries["gateway"] = cfg.Entry{Desc: "default gateway", Type: "string", Def: DefaultFabGw}
		fs.Entries["in"] = cfg.Entry{Desc: "file, which contains the output of previous submit attempt, empty means stdin", Type: "string", Def: ""}
		fs.Entries["keyname"] = cfg.Entry{Desc: "the name of the field containing the unique identifier", Type: "string", Def: DefaultBundleKeyName}
		fs.Entries["keypos"] = cfg.Entry{Desc: shift + "+Nth field in -in that contains the unique identifier identified by -keyname", Type: "int", Def: DefaultBundleKeyPos}
		fs.Entries["keystore"] = cfg.Entry{Desc: "path to client keystore", Type: "string", Def: DefaultPathKeystore}
		fs.Entries["keytype"] = cfg.Entry{Desc: "type of -keyname, either 'string' or 'int'", Type: "string", Def: DefaultBundleKeyType}
		fs.Entries["mspid"] = cfg.Entry{Desc: "fabric MSPID", Type: "string", Def: DefaultFabMspId}
		fs.Entries["try"] = cfg.Entry{Desc: "number of invoke tries", Type: "int", Def: DefaultFabTry}
		fs.Entries["tlscert"] = cfg.Entry{Desc: "path to TLS cert", Type: "string", Def: DefaultPathTlsCert}

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

	level := syslog.Priority(config.Entries["loglevel"].Value.(int))
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

}

// endregion: main
// region: modes

func modeConfirm(config *cfg.Config) {

	// region: i/o

	input := config.Entries["in"].Value.(string)
	output := config.Entries["out"].Value.(string)

	batch, sent := ioCombined(input, output, procParseBundles)
	defer sent.Close()
	Lout(LOG_INFO, "# of lines", len(*batch))

	// endregion: i/o
	// region: block cache

	// cache := make(map[string]Header)

	// endregion: block cache
	// region: process batch

	for k, item := range *batch {

		progress := fmt.Sprintf("%d/%d", k+1, len(*batch))

		// region: validate input

		if item.Status != STATUS_SUBMIT_OK && !strings.HasPrefix(item.Status, STATUS_CONFIRM_ERROR_PREFIX) {
			Lout(LOG_INFO, progress, "bypassed status", item.Status)
			ioOutputAppend(sent, item, procCompilePSV)
			continue
		}
		if !TxRegexp.MatchString(item.Txid) {
			item.Status = "STATUS_CONFIRM_ERROR_TXID"
			Lout(LOG_ERR, progress, "invalid txid", item.Txid)
			ioOutputAppend(sent, item, procCompilePSV)
			continue
		}

		// endregion: validate input
		// region: get .result.header

		// blockHeader, blockHeaderType, _, err := jsonparser.Get(resp.Body(), "result", "header")
		// if blockHeaderType != jsonparser.Object || err != nil {
		// 	item.Status = STATUS_CONFIRM_ERROR_HEADER
		// 	item.Response = err.Error()
		// 	Lout(LOG_ERR, progress, "no parsable header in response", item.Response)
		// 	helperOutputAppend(outFile, item, helperCompilePSV)
		// 	continue
		// }

		// endregion: get .result.header
		// region: parse .result.header.number

		// var responseHeader Header

		// responseHeader.Number, err = jsonparser.GetString(blockHeader, "number")
		// if err != nil {
		// 	item.Status = STATUS_CONFIRM_ERROR_HEADER
		// 	item.Response = err.Error()
		// 	Lout(LOG_ERR, progress, "cannot parse block # from header", item.Response)
		// 	helperOutputAppend(outFile, item, helperCompilePSV)
		// 	continue
		// }

		// endregion: parse .result.header.number
		// region: parse or cache

		/*
			if _, exists := blockCache[responseHeader.Number]; exists {
				responseHeader = blockCache[responseHeader.Number]
			} else {

				// region: parse .result.header

				responseHeader.DataHash, err = jsonparser.GetString(blockHeader, "data_hash")
				if err != nil {
					item.Status = STATUS_CONFIRM_ERROR_HEADER
					item.Response = err.Error()
					Lout(LOG_ERR, progress, "cannot parse data_hash from header", item.Response)
					helperOutputAppend(outFile, item, helperCompilePSV)
					continue
				}

				responseHeader.PreviousHash, err = jsonparser.GetString(blockHeader, "previous_hash")
				if err != nil {
					item.Status = STATUS_CONFIRM_ERROR_HEADER
					item.Response = err.Error()
					Lout(LOG_ERR, progress, "cannot parse previous_hash from header", item.Response)
					helperOutputAppend(outFile, item, helperCompilePSV)
					continue
				}

				// endregion: parse .result.header
				// region: get payload (.result.data.data)

				blockPayload, blockPayloadType, _, err := jsonparser.Get(resp.Body(), "result", "data", "data")
				if blockPayloadType != jsonparser.Array || err != nil {
					item.Status = STATUS_CONFIRM_ERROR_HEADER
					item.Response = err.Error()
					Lout(LOG_ERR, progress, "no parsable payload in response", item.Response)
					helperOutputAppend(outFile, item, helperCompilePSV)
					continue
				}

				// endregion: get payload
				// region: parse timestamp and length from payload

				responseHeader.Timestamp, err = jsonparser.GetString(blockPayload, "[0]", "payload", "header", "channel_header", "timestamp")
				if err != nil {
					item.Status = STATUS_CONFIRM_ERROR_HEADER
					item.Response = err.Error()
					Lout(LOG_ERR, progress, "cannot get timestamp from payload", item.Response)
					helperOutputAppend(outFile, item, helperCompilePSV)
					continue
				}

				responseHeader.Length = 0
				_, err = jsonparser.ArrayEach(blockPayload, func(value []byte, dataType jsonparser.ValueType, offset int, err error) {

					responseHeader.Length++
					// fmt.Println(header.Length)
				})
				if err != nil {
					item.Status = STATUS_CONFIRM_ERROR_HEADER
					item.Response = err.Error()
					Lout(LOG_ERR, progress, "cannot count transactions in payload", item.Response)
					helperOutputAppend(outFile, item, helperCompilePSV)
					continue
				}

				// endregion: parse timestamp and length from payload
				// region: fill blockCache

				blockCache[responseHeader.Number] = responseHeader

				// endregion: blockCache

			}
		*/

		// endregion: parse or cache
		// region: header to string

		// responseHeaderData, err := json.Marshal(responseHeader)
		// if err != nil {
		// 	item.Status = STATUS_CONFIRM_ERROR_HEADER
		// 	item.Response = err.Error()
		// 	Lout(LOG_ERR, progress, "cannot marshal header", item.Response)
		// 	helperOutputAppend(outFile, item, helperCompilePSV)
		// 	continue
		// }

		// endregion: header to string
		// region: done

		// item.Status = STATUS_CONFIRM_200
		// item.Response = string(responseHeaderData)
		// Lout(LOG_DEBUG, progress, item.Status)
		// Lout(LOG_DEBUG, progress, item.Key)
		// Lout(LOG_DEBUG, progress, item.Txid)
		// Lout(LOG_DEBUG, progress, item.Response)
		// Lout(LOG_DEBUG, progress, item.Payload)
		// helperOutputAppend(outFile, item, helperCompilePSV)
		Lout(LOG_INFO, progress, "done")

		// endregion: done

	}

	// endregion: process batch

}

func modeConfirmRawapi(config *cfg.Config) {

	// region: i/o

	inPath := config.Entries["in"].Value.(string)
	outPath := config.Entries["out"].Value.(string)

	batch, outFile := ioCombined(inPath, outPath, procParsePSV)
	defer outFile.Close()
	Lout(LOG_INFO, "# of lines", len(*batch))

	// endregion: i/o
	// region: base url

	baseurl := fasthttp.AcquireURI()
	defer fasthttp.ReleaseURI(baseurl)
	baseurl.Parse(nil, []byte(config.Entries["host"].Value.(string)+config.Entries["query"].Value.(string)))
	baseurl.QueryArgs().Add("channel", config.Entries["channel"].Value.(string))
	baseurl.QueryArgs().Add("chaincode", config.Entries["chaincode"].Value.(string))
	baseurl.QueryArgs().Add("function", config.Entries["function"].Value.(string))
	baseurl.QueryArgs().Add("proto_decode", "common.Block")
	baseurl.QueryArgs().Add("args", config.Entries["channel"].Value.(string))
	Lout(LOG_INFO, "base url", baseurl.String())

	// endregion: base url
	// region: block cache

	blockCache := make(map[string]Header)

	// endregion: block cache
	// region: process batch

	for k, item := range *batch {

		progress := fmt.Sprintf("%d/%d", k+1, len(*batch))

		// region: validate input

		if item.Status != STATUS_SUBMIT_OK && !strings.HasPrefix(item.Status, STATUS_CONFIRM_ERROR_PREFIX) {
			Lout(LOG_INFO, progress, "bypassed status", item.Status)
			ioOutputAppend(outFile, item, procCompilePSV)
			continue
		}
		if !TxRegexp.MatchString(item.Txid) {
			item.Status = "STATUS_CONFIRM_ERROR_TXID"
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
		if len(config.Entries["tc_http_api_key"].Value.(string)) != 0 {
			req.Header.Set(API_KEY_HEADER, config.Entries["tc_http_api_key"].Value.(string))
		}
		Lout(LOG_DEBUG, progress, url)

		resp := fasthttp.AcquireResponse()
		defer fasthttp.ReleaseResponse(resp)

		// endregion: prepare request
		// region: prepare client

		client := &fasthttp.Client{}
		err := client.Do(req, resp)
		if err != nil {
			item.Status = STATUS_CONFIRM_ERROR_CLIENT
			item.Response = string(err.Error())
			Lout(LOG_ERR, progress, "http client error", err)
			ioOutputAppend(outFile, item, procCompilePSV)
			continue
		}

		// endregion: prepare response
		// region: check status

		if resp.StatusCode() != fasthttp.StatusOK {
			item.Status = STATUS_CONFIRM_ERROR_PREFIX + strconv.Itoa(resp.StatusCode())
			item.Response = string(resp.Body())
			Lout(LOG_ERR, progress, "response status indicates an error", resp.StatusCode(), item.Response)
			ioOutputAppend(outFile, item, procCompilePSV)
			continue
		}

		// endregion: check status
		// region: get .result.header

		blockHeader, blockHeaderType, _, err := jsonparser.Get(resp.Body(), "result", "header")
		if blockHeaderType != jsonparser.Object || err != nil {
			item.Status = STATUS_CONFIRM_ERROR_HEADER
			item.Response = err.Error()
			Lout(LOG_ERR, progress, "no parsable header in response", item.Response)
			ioOutputAppend(outFile, item, procCompilePSV)
			continue
		}

		// endregion: get .result.header
		// region: parse .result.header.number

		var responseHeader Header

		responseHeader.Number, err = jsonparser.GetString(blockHeader, "number")
		if err != nil {
			item.Status = STATUS_CONFIRM_ERROR_HEADER
			item.Response = err.Error()
			Lout(LOG_ERR, progress, "cannot parse block # from header", item.Response)
			ioOutputAppend(outFile, item, procCompilePSV)
			continue
		}

		// endregion: parse .result.header.number
		// region: parse or cache

		if _, exists := blockCache[responseHeader.Number]; exists {
			responseHeader = blockCache[responseHeader.Number]
		} else {

			// region: parse .result.header

			responseHeader.DataHash, err = jsonparser.GetString(blockHeader, "data_hash")
			if err != nil {
				item.Status = STATUS_CONFIRM_ERROR_HEADER
				item.Response = err.Error()
				Lout(LOG_ERR, progress, "cannot parse data_hash from header", item.Response)
				ioOutputAppend(outFile, item, procCompilePSV)
				continue
			}

			responseHeader.PreviousHash, err = jsonparser.GetString(blockHeader, "previous_hash")
			if err != nil {
				item.Status = STATUS_CONFIRM_ERROR_HEADER
				item.Response = err.Error()
				Lout(LOG_ERR, progress, "cannot parse previous_hash from header", item.Response)
				ioOutputAppend(outFile, item, procCompilePSV)
				continue
			}

			// endregion: parse .result.header
			// region: get payload (.result.data.data)

			blockPayload, blockPayloadType, _, err := jsonparser.Get(resp.Body(), "result", "data", "data")
			if blockPayloadType != jsonparser.Array || err != nil {
				item.Status = STATUS_CONFIRM_ERROR_HEADER
				item.Response = err.Error()
				Lout(LOG_ERR, progress, "no parsable payload in response", item.Response)
				ioOutputAppend(outFile, item, procCompilePSV)
				continue
			}

			// endregion: get payload
			// region: parse timestamp and length from payload

			responseHeader.Timestamp, err = jsonparser.GetString(blockPayload, "[0]", "payload", "header", "channel_header", "timestamp")
			if err != nil {
				item.Status = STATUS_CONFIRM_ERROR_HEADER
				item.Response = err.Error()
				Lout(LOG_ERR, progress, "cannot get timestamp from payload", item.Response)
				ioOutputAppend(outFile, item, procCompilePSV)
				continue
			}

			responseHeader.Length = 0
			_, err = jsonparser.ArrayEach(blockPayload, func(value []byte, dataType jsonparser.ValueType, offset int, err error) {

				responseHeader.Length++
				// fmt.Println(header.Length)
			})
			if err != nil {
				item.Status = STATUS_CONFIRM_ERROR_HEADER
				item.Response = err.Error()
				Lout(LOG_ERR, progress, "cannot count transactions in payload", item.Response)
				ioOutputAppend(outFile, item, procCompilePSV)
				continue
			}

			// endregion: parse timestamp and length from payload
			// region: fill blockCache

			blockCache[responseHeader.Number] = responseHeader

			// endregion: blockCache

		}

		// endregion: parse or cache
		// region: header to string

		responseHeaderData, err := json.Marshal(responseHeader)
		if err != nil {
			item.Status = STATUS_CONFIRM_ERROR_HEADER
			item.Response = err.Error()
			Lout(LOG_ERR, progress, "cannot marshal header", item.Response)
			ioOutputAppend(outFile, item, procCompilePSV)
			continue
		}

		// endregion: header to string
		// region: done

		item.Status = STATUS_CONFIRM_OK
		item.Response = string(responseHeaderData)
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

func modeResubmit(config *cfg.Config) {

	// region: i/o

	input := config.Entries["in"].Value.(string)
	output := config.Entries["out"].Value.(string)

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

	for k, bundle := range *batch {
		progress := fmt.Sprintf("%d/%d", k+1, len(*batch))

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

	input := config.Entries["in"].Value.(string)
	output := config.Entries["out"].Value.(string)

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

	for k, bundle := range *batch {
		progress := fmt.Sprintf("%d/%d", k+1, len(*batch))
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

	// region: i/o

	input := strings.Split(config.Entries["in"].Value.(string), ",")
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

	sent := ioOutputOpen(config.Entries["out"].Value.(string))
	defer sent.Close()

	// endregion: i/o
	// region: client

	client, err := fabricClient(config)
	if err != nil {
		helperPanic("cannot init fabric gw", err.Error())
	}
	Lout(LOG_DEBUG, "fabric client", client)

	// endregion: client
	// region: process batch

	done := 1
	for i, file := range input {
		batch := ioRead(file, procParseBundles)
		for k, bundle := range *batch {
			progress := fmt.Sprintf("file %d/%d, bundle %d/%d, total %d/%d", i+1, len(input), k+1, len(*batch), done, count)
			err := fabricSubmit(config, client, &bundle)
			if err != nil {
				Lout(LOG_NOTICE, progress, err)
			} else {
				Lout(LOG_INFO, progress, "success", bundle.Key, bundle.Txid)
			}
			ioOutputAppend(sent, bundle, procCompilePSV)
			done++
		}
	}

	// endregion: process

}

// endregion: modes
// region: helpers

// region: fabric

func fabricClient(config *cfg.Config) (*fabric.Client, error) {
	client := fabric.Client{
		CertPath:     config.Entries["cert"].Value.(string),
		GatewayPeer:  config.Entries["gateway"].Value.(string),
		KeyPath:      config.Entries["keystore"].Value.(string),
		MSPID:        config.Entries["mspid"].Value.(string),
		PeerEndpoint: config.Entries["endpoint"].Value.(string),
		TLSCertPath:  config.Entries["tlscert"].Value.(string),
	}
	err := client.Init()
	if err != nil {
		return nil, err
	}

	return &client, nil
}

func fabricInvoke(config *cfg.Config, client *fabric.Client, args []string) (*fabric.Response, *fabric.ResponseError) {

	request := fabric.Request{
		Chaincode: config.Entries["chaincode"].Value.(string),
		Channel:   config.Entries["channel"].Value.(string),
		Function:  config.Entries["function"].Value.(string),
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

// func fabricQuery(config *cfg.Config, client, args []string) (*fabric.Response, *fabric.ResponseError) {
// 	request := fabric.Request{
// 		Chaincode: config.Entries["chaincode"].Value.(string),
// 		Channel:   config.Entries["channel"].Value.(string),
// 		Function:  config.Entries["function"].Value.(string),
// 		Args:      args,
// 	}
// 	Lout(LOG_DEBUG, "fabric query request", request)

// 	return nil, nil
// }

func fabricSubmit(config *cfg.Config, client *fabric.Client, bundle *PSV) error {

	// region: shorten variables coming from config

	keypos := config.Entries["keypos"].Value.(int)
	keyname := config.Entries["keyname"].Value.(string)
	keytype := config.Entries["keytype"].Value.(string)

	try := config.Entries["try"].Value.(int)

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

	var response *fabric.Response
	var responseErr *fabric.ResponseError

	for cnt := 1; cnt <= try; cnt++ {
		response, responseErr = fabricInvoke(config, client, bundle.Payload)
		if responseErr == nil {
			break
		}
		Lout(LOG_DEBUG, fmt.Sprintf("unsuccessful attempt %d/%d", cnt, try))
	}
	if responseErr != nil {
		bundle.Response = responseErr.Error()
		bundle.Status = STATUS_SUBMIT_ERROR_INVOKE
		return responseErr
	}
	Lout(LOG_DEBUG, "fabric invoke response", response)

	// endregion: request
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

func helperUsage(fs *flag.FlagSet) func() {
	return func() {
		fmt.Println("usage:")
		if len(os.Args[1]) == 0 {
			fmt.Println("  " + os.Args[0] + " [mode] <options>")
			fmt.Println("")
			fmt.Println("modes:")

			format := "  %-18s  %s\n"
			fmt.Printf(format, "confirm (c)", "iterates over the output of submit/resubmit and query via fabric sdk for block number and data hash against qscc's GetBlockByTxID()")
			fmt.Printf(format, "confirmRawapi (cr)", "iterates over the output of submit/resubmit and query via Rawapi for block number and data hash against qscc's GetBlockByTxID()")
			fmt.Printf(format, "help (h)", "produces this")
			// fmt.Printf(format, "psv2json", "convert PSV format to JSON for server-side batch processing")
			fmt.Printf(format, "resubmit (r)", "iterates over the output of submit and retries unsuccessful attempts")
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
				fmt.Println("Before evaluation, the file corresponding to $TC_PATH_RC is read (if it is set and the file exists) and the environment variables are taken into account when")
				fmt.Println("setting some default values and parsing cli. Parameters can also be passed via env. variables, like `CHANNEL=foo` instead of '-channel=foo', order of")
				fmt.Println("precedence:")
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

// endregion: helpers
