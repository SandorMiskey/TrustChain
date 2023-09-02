// region: packages

package main

import (
	"bufio"
	"encoding/json"
	"flag"
	"fmt"
	"log/syslog"
	"os"
	"path/filepath"
	"reflect"
	"regexp"
	"strconv"
	"strings"

	"github.com/SandorMiskey/TEx-kit/cfg"
	"github.com/SandorMiskey/TEx-kit/log"
	"github.com/buger/jsonparser"
	"github.com/valyala/fasthttp"
	// "github.com/SandorMiskey/TrustChain/migration/psv"
	// "github.com/davecgh/go-spew/spew"
)

// endregion: packages
// region: globals

var (
	Config cfg.Config
	Mode   string
	Logger *log.Logger
	Lout   func(s ...interface{}) *[]error
	// db     *db.Db
	// server http.ServerSetup
	// router http.RouterSetup
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
	STATUS_CONFIRM_200          string = "CONFIRM_200"
	STATUS_PARSE_ERROR          string = "PARSE_ERROR"
	STATUS_SUBMIT_200           string = "SUBMIT_200"

	TXID string = "^[a-fA-F0-9]{64}$"

	// TODO: msg/err
)

// endregion: constants
// region: types

type Compiler func(PSV) string

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

	// region: check mode

	if len(os.Args) == 1 {
		usage := helperUsage(nil)
		usage()
		helperPanic("missing mode selector")
	}
	Mode = os.Args[1]

	// endregion: check mode
	// region: cfg/fs, common args

	Config = *cfg.NewConfig(os.Args[0])

	cfg.FlagSetArguments = os.Args[2:]
	cfg.FlagSetUsage = helperUsage
	fs := Config.NewFlagSet(os.Args[0] + " " + os.Args[1])
	fs.Entries = map[string]cfg.Entry{
		"channel":  {Desc: "set [string] as channel id", Type: "string", Def: "trustchain-test"},
		"loglevel": {Desc: "loglevel as syslog.Priority", Type: "int", Def: 6},
		"out":      {Desc: "path for output, empty means stdout", Type: "string", Def: ""},
	}

	// endregion: cfg/fs, common args
	// region: evaluate mode

	switch Mode {
	case "confirm":
		fs.Entries["chaincode"] = cfg.Entry{Desc: "chaincode to query", Type: "string", Def: "qscc"}
		fs.Entries["function"] = cfg.Entry{Desc: "function of --chaincode", Type: "string", Def: "GetBlockByTxID"}
		fs.Entries["host"] = cfg.Entry{Desc: "api host in http(s)://host:port format", Type: "string", Def: "http://localhost:5088"}
		fs.Entries["in"] = cfg.Entry{Desc: "| separated file with args for query, empty means stdin", Type: "string", Def: ""}
		fs.Entries["overwrite"] = cfg.Entry{Desc: "over write output file if exists, appends if false", Type: "bool", Def: false}
		fs.Entries["query"] = cfg.Entry{Desc: "query endpoint", Type: "string", Def: "/query"}
		fs.Entries["tc_http_api_key"] = cfg.Entry{Desc: "api key, skip if not set", Type: "string", Def: ""}
		helperParseFS(fs)
		helperSetLogger()
		defer Logger.Close()
		Lout = Logger.Out
		modeConfirm()
	// case "confirmPsvToJson":
	// 	helperPanic("implemented yet")
	case "help", "-h", "--help":
		Mode = ""
		msg := helperUsage(fs.FlagSet)
		msg()
		os.Exit(0)
	case "submit":
		helperPanic("implemented yet")
		// "chaincode":       {Desc: "chaincode name for query or invoke", Type: "string", Def: "te-food-bundles"},
		// 	commonPrintf "  -i --invoke [name]     invoke endpoint for submit, default: \"${setArgs[invoke]}\""
		// 	commonPrintf "  -k --key [name]        jq's path to unique id in input, default: \"${setArgs[key]}\""
		// 	commonPrintf "  -p --position [N]      field which contains JSON with -k, default: \"${setArgs[position]}\""
		// 	commonPrintf "  -t --txid [path]       jq's path for transaction id, default: \"${setArgs[txid]}\""
	case "resubmit":
		helperPanic("implemented yet")
	default:
		Mode = ""
		usage := helperUsage(fs.FlagSet)
		usage()
		helperPanic("invalid mode '" + os.Args[1] + "'")
	}

	// endregion: evaluate mode

}

func modeConfirm() {
	Lout(LOG_INFO, "confirm mode")

	// region: i/o

	inPath := Config.Entries["in"].Value.(string)
	outPath := Config.Entries["out"].Value.(string)

	batch := helperRead(inPath, helperParsePSV)
	Lout(LOG_INFO, "# of lines", len(*batch))

	if len(inPath) != 0 && filepath.Clean(inPath) == filepath.Clean(outPath) {
		helperPanic("in-place update not supported yet", inPath)
	}

	outFile := helperOutputOpen(outPath)
	defer outFile.Close()

	// endregion: i/o
	// region: pre-compile txid regex

	regex, err := regexp.Compile(TXID)
	if err != nil {
		helperPanic(err.Error())
	}

	// endregion: pre-compile txid regex
	// region: base url

	baseurl := fasthttp.AcquireURI()
	defer fasthttp.ReleaseURI(baseurl)
	baseurl.Parse(nil, []byte(Config.Entries["host"].Value.(string)+Config.Entries["query"].Value.(string)))
	baseurl.QueryArgs().Add("channel", Config.Entries["channel"].Value.(string))
	baseurl.QueryArgs().Add("chaincode", Config.Entries["chaincode"].Value.(string))
	baseurl.QueryArgs().Add("function", Config.Entries["function"].Value.(string))
	baseurl.QueryArgs().Add("proto_decode", "common.Block")
	baseurl.QueryArgs().Add("args", Config.Entries["channel"].Value.(string))
	Lout(LOG_INFO, "base url", baseurl.String())

	// endregion: base url
	// region: block cache

	blockCache := make(map[string]Header)

	// endregion: block cache
	// region: process batch

	for k, item := range *batch {

		progress := fmt.Sprintf("%d/%d", k+1, len(*batch))

		// region: validate input

		if item.Status != STATUS_SUBMIT_200 && !strings.HasPrefix(item.Status, STATUS_CONFIRM_ERROR_PREFIX) {
			Lout(LOG_INFO, progress, "bypassed status", item.Status)
			helperOutputAppend(outFile, item, helperCompilePSV)
			continue
		}
		if !regex.MatchString(item.Txid) {
			item.Status = "STATUS_CONFIRM_ERROR_TXID"
			Lout(LOG_ERR, progress, "invalid txid", item.Txid)
			helperOutputAppend(outFile, item, helperCompilePSV)
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
		if len(Config.Entries["tc_http_api_key"].Value.(string)) != 0 {
			req.Header.Set(API_KEY_HEADER, Config.Entries["tc_http_api_key"].Value.(string))
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
			helperOutputAppend(outFile, item, helperCompilePSV)
			continue
		}

		// endregion: prepare response
		// region: check status

		if resp.StatusCode() != fasthttp.StatusOK {
			item.Status = STATUS_CONFIRM_ERROR_PREFIX + strconv.Itoa(resp.StatusCode())
			item.Response = string(resp.Body())
			Lout(LOG_ERR, progress, "response status indicates an error", resp.StatusCode(), item.Response)
			helperOutputAppend(outFile, item, helperCompilePSV)
			continue
		}

		// endregion: check status
		// region: get .result.header

		blockHeader, blockHeaderType, _, err := jsonparser.Get(resp.Body(), "result", "header")
		if blockHeaderType != jsonparser.Object || err != nil {
			item.Status = STATUS_CONFIRM_ERROR_HEADER
			item.Response = err.Error()
			Lout(LOG_ERR, progress, "no parsable header in response", item.Response)
			helperOutputAppend(outFile, item, helperCompilePSV)
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
			helperOutputAppend(outFile, item, helperCompilePSV)
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

		// endregion: parse or cache
		// region: header to string

		responseHeaderData, err := json.Marshal(responseHeader)
		if err != nil {
			item.Status = STATUS_CONFIRM_ERROR_HEADER
			item.Response = err.Error()
			Lout(LOG_ERR, progress, "cannot marshal header", item.Response)
			helperOutputAppend(outFile, item, helperCompilePSV)
			continue
		}

		// endregion: header to string
		// region: done

		item.Status = STATUS_CONFIRM_200
		item.Response = string(responseHeaderData)
		Lout(LOG_DEBUG, progress, item.Status)
		Lout(LOG_DEBUG, progress, item.Key)
		Lout(LOG_DEBUG, progress, item.Txid)
		Lout(LOG_DEBUG, progress, item.Response)
		Lout(LOG_DEBUG, progress, item.Payload)
		helperOutputAppend(outFile, item, helperCompilePSV)
		Lout(LOG_INFO, progress, "done")

		// endregion: done

	}

	// endregion: process batch

}

// endregion: main
// region: helpers

func helperCompilePSV(psv PSV) string {
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

func helperOutputAppend(f *os.File, psv PSV, fn Compiler) {
	line := fn(psv)
	_, err := f.WriteString(line + "\n")
	if err != nil {
		helperPanic("error appending line to file", err.Error(), f.Name(), line)
	}
}

func helperOutputOpen(f string) *os.File {

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

func helperPanic(s ...string) {
	msg := strings.Join(s, " -> ")
	if Logger != nil {
		Lout(LOG_EMERG, msg)
	}
	fmt.Fprintln(os.Stderr, msg)
	os.Exit(1)
}

func helperParseFS(fs *cfg.FlagSet) {
	err := fs.ParseCopy()
	if err != nil {
		helperPanic(err.Error())
	}
}

func helperParsePSV(scanner *bufio.Scanner) *[]PSV {

	// TODO: implement helperParseJSON

	var batch []PSV

	for scanner.Scan() {
		line := scanner.Text()
		values := strings.Split(line, "|")

		if Mode == "submit" {
			item := PSV{
				Payload: values,
			}

			batch = append(batch, item)
		} else {
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
	}

	if err := scanner.Err(); err != nil {
		helperPanic(err.Error())
	}

	return &batch
}

func helperRead(f string, fn Parser) *[]PSV {

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

func helperSetLogger() {
	level := syslog.Priority(Config.Entries["loglevel"].Value.(int))
	if level < LOG_INFO {
		log.ChDefaults.Welcome = nil
		log.ChDefaults.Bye = nil
	} else {
		welcome := fmt.Sprintf("%s (level: %v)", *log.ChDefaults.Welcome, level)
		log.ChDefaults.Welcome = &welcome
	}
	Logger = log.NewLogger()
	_, _ = Logger.NewCh(log.ChConfig{Severity: &level})
}

func helperUsage(fs *flag.FlagSet) func() {
	return func() {
		fmt.Println("usage:")
		if len(Mode) == 0 {
			fmt.Println("  " + os.Args[0] + " [mode] <options>")
			fmt.Println("")
			fmt.Println("modes:")
			fmt.Println("  confirm           iterates over the output of submit/resubmit and query for block number and data hash against qscc's GetBlockByTxID()")
			// fmt.Println("  confirmPsvToJson  iterates over the output of submit/resubmit and query for block number and data hash against qscc's GetBlockByTxID()")
			fmt.Println("  resubmit          iterates over the output of submit and resubmits unsuccessful submits")
			fmt.Println("  submit            iterates over input batch and submit line by line")
			fmt.Println("")
			fmt.Println("use `" + os.Args[0] + " [mode] --help` for mode specific details")
		} else {
			fmt.Println("  " + os.Args[0] + " " + Mode + " <options>")
			fmt.Println("")
			if fs != nil {
				fmt.Println("options:")
				fs.PrintDefaults()
			}
		}
		fmt.Println("")
	}
}

// endregion: helpers
