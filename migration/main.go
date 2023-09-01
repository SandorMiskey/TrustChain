// region: packages

package main

import (
	"flag"
	"fmt"
	"log/syslog"
	"os"

	"github.com/SandorMiskey/TEx-kit/cfg"
	"github.com/SandorMiskey/TEx-kit/log"
	"github.com/SandorMiskey/TrustChain/migration/psv"
	// "github.com/davecgh/go-spew/spew"
)

// endregion: packages
// region: global, const

var (
	config cfg.Config
	mode   string
	logger log.Logger
	// db     *db.Db
	// server http.ServerSetup
	// router http.RouterSetup
)

const (
	LOG_ERR    syslog.Priority = log.LOG_ERR
	LOG_NOTICE syslog.Priority = log.LOG_NOTICE
	LOG_INFO   syslog.Priority = log.LOG_INFO
	LOG_DEBUG  syslog.Priority = log.LOG_DEBUG
	LOG_EMERG  syslog.Priority = log.LOG_EMERG
)

// endregion: const

func main() {

	// region: check mode

	if len(os.Args) == 1 {
		fmt.Fprintln(os.Stderr, "missing mode selector")
		usage := helperUsage(nil)
		usage()
		os.Exit(1)
	}
	mode = os.Args[1]

	// endregion: check mode
	// region: cfg/fs, common args

	config = *cfg.NewConfig(os.Args[0])

	cfg.FlagSetArguments = os.Args[2:]
	cfg.FlagSetUsage = helperUsage
	fs := config.NewFlagSet(os.Args[0] + " " + os.Args[1])
	fs.Entries = map[string]cfg.Entry{
		"chaincode":       {Desc: "chaincode name for query or invoke", Type: "string", Def: "te-food-bundles"},
		"channel":         {Desc: "set [string] as channel id", Type: "string", Def: "trustchain-test"},
		"func":            {Desc: "function of --chaincode", Type: "string", Def: "trustchain-test"},
		"host":            {Desc: "api host in http(s)://host:port format", Type: "string", Def: "http://localhost:5088"},
		"output":          {Desc: "path for output", Type: "string", Def: "/dev/stdout"},
		"tc_http_api_key": {Desc: "api key, skip if not set", Type: "string", Def: ""},
		"loglevel":        {Desc: "loglevel as syslog.Priority", Type: "int", Def: 7},
	}

	// endregion: cfg/fs, common args
	// region: evaluate mode

	switch mode {
	case "confirm":
		fs.Entries["bundle"] = cfg.Entry{Desc: "| separated file with args for query, empty means stdin", Type: "string", Def: ""}
		fs.Entries["overwrite"] = cfg.Entry{Desc: "over write output file if exists, appends if false", Type: "bool", Def: false}
		fs.Entries["query"] = cfg.Entry{Desc: "query endpoint", Type: "string", Def: "/query"}
		helperParseFS(fs)
		helperSetLogger()
		defer logger.Close()
		modeConfirm()
	case "help":
		mode = ""
		msg := helperUsage(fs.FlagSet)
		msg()
		os.Exit(0)
	case "submit":
		// 	commonPrintf "  -i --invoke [name]     invoke endpoint for submit, default: \"${setArgs[invoke]}\""
		// 	commonPrintf "  -k --key [name]        jq's path to unique id in input, default: \"${setArgs[key]}\""
		// 	commonPrintf "  -p --position [N]      field which contains JSON with -k, default: \"${setArgs[position]}\""
		// 	commonPrintf "  -t --txid [path]       jq's path for transaction id, default: \"${setArgs[txid]}\""
		fmt.Println("submit")
	case "resubmit":
		fmt.Println("resubmit")
	default:
		fmt.Fprintln(os.Stderr, "invalid mode '"+os.Args[1]+"'")
		mode = ""
		usage := helperUsage(fs.FlagSet)
		usage()
		os.Exit(1)
	}

	// endregion: evaluate mode

}

func modeConfirm() {
	logger.Out(LOG_INFO, "confirm mode")

	in := config.Entries["bundle"].Value.(string)

	if in == "/dev/stdin" {
		fmt.Println("stdin")
	} else {
		psv.Read()
	}
}

// region: helpers

func helperParseFS(fs *cfg.FlagSet) {
	err := fs.ParseCopy()
	if err != nil {
		logger.Out(LOG_EMERG, err)
		panic("")
	}
}

func helperSetLogger() {
	level := syslog.Priority(config.Entries["loglevel"].Value.(int))
	if level < LOG_INFO {
		log.ChDefaults.Welcome = nil
		log.ChDefaults.Bye = nil
	} else {
		welcome := fmt.Sprintf("%s (level: %v)", *log.ChDefaults.Welcome, level)
		log.ChDefaults.Welcome = &welcome
	}
	logger = *log.NewLogger()
	_, _ = logger.NewCh(log.ChConfig{Severity: &level})
}

func helperUsage(fs *flag.FlagSet) func() {
	return func() {
		fmt.Println("usage:")
		if len(mode) == 0 {
			fmt.Println("  " + os.Args[0] + " [mode] <options>")
			fmt.Println("")
			fmt.Println("modes:")
			fmt.Println("  confirm    iterates over the output of submit/resubmit and query for block number and data hash against qscc's GetBlockByTxID()")
			fmt.Println("  resubmit   iterates over the output of submit and resubmits unsuccessful submits")
			fmt.Println("  submit     iterates over input batch and submit line by line")
			fmt.Println("")
			fmt.Println("use `" + os.Args[0] + " [mode] --help` for mode specific details")
		} else {
			fmt.Println("  " + os.Args[0] + " " + mode + " <options>")
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
