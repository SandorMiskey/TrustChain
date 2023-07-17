// region: packages

package main

import (
	"fmt"
	"log/syslog"
	"net"
	"os"
	"strconv"
	"sync"

	"github.com/SandorMiskey/TEx-kit/cfg"
	"github.com/SandorMiskey/TEx-kit/log"
	"github.com/SandorMiskey/TrustChain/rawapi/fabric"

	// "github.com/davecgh/go-spew/spew"
	"github.com/buaazp/fasthttprouter"
	"github.com/valyala/fasthttp"
)

// endregion: packages
// region: global variables

var (
	// Db     *db.Db
	Config    cfg.Config
	Logger    log.Logger
	OrgConfig fabric.OrgSetup
	OrgSetup  *fabric.OrgSetup
)

const (
	LOG_ERR    syslog.Priority = log.LOG_ERR
	LOG_NOTICE syslog.Priority = log.LOG_NOTICE
	LOG_INFO   syslog.Priority = log.LOG_INFO
	LOG_DEBUG  syslog.Priority = log.LOG_DEBUG
	LOG_EMERG  syslog.Priority = log.LOG_EMERG
)

// endregion: globals

func main() {

	// region: config and cli flags

	Config = *cfg.NewConfig(os.Args[0])
	flagSet := Config.NewFlagSet(os.Args[0])
	flagSet.Entries = map[string]cfg.Entry{
		// "dbAddr":        {Desc: "database address", Type: "string", Def: "/app/mgmt.db"},
		// "dbName":        {Desc: "database name", Type: "string", Def: "mgmt"},
		// "dbPasswd":      {Desc: "database user password", Type: "string", Def: ""},
		// "dbPasswd_file": {Desc: "database user password", Type: "string", Def: ""},
		// "dbType":        {Desc: "db type as in TEx-kit/db/db.go", Type: "int", Def: 4},
		// "dbUser":        {Desc: "database user", Type: "string", Def: "mgmt"},

		"tc_rawapi_http_enabled":        {Desc: "enable http", Type: "bool", Def: true},
		"tc_rawapi_http_name":           {Desc: "server name in response header", Type: "string", Def: "TrustChain backend"},
		"tc_rawapi_http_port":           {Desc: "http port", Type: "int", Def: 5998},
		"tc_rawapi_http_static_enabled": {Desc: "enable serving static files", Type: "bool", Def: false},
		"tc_rawapi_http_static_root":    {Desc: "path to static files", Type: "string", Def: "/tmp"},
		"tc_rawapi_http_static_index":   {Desc: "index file to serve during directory access", Type: "string", Def: "index.html"},
		"tc_rawapi_http_static_error":   {Desc: "location to redirect in case of 404", Type: "string", Def: "index.html"},

		"tc_rawapi_https_enabled":   {Desc: "enable https", Type: "bool", Def: true},
		"tc_rawapi_https_port":      {Desc: "https port", Type: "int", Def: 5999},
		"tc_rawapi_https_cert":      {Desc: "https certificate", Type: "string", Def: ""},
		"tc_rawapi_https_cert_file": {Desc: "https certificate file", Type: "string", Def: ""},
		"tc_rawapi_https_key":       {Desc: "private key for HTTPS certificate", Type: "string", Def: ""},
		"tc_rawapi_https_key_file":  {Desc: "httpTLSKey file", Type: "string", Def: ""},

		"tc_rawapi_http_logAllErrors":       {Desc: "enable http", Type: "bool", Def: true},
		"tc_rawapi_http_maxRequestBodySize": {Desc: "http max request body size ", Type: "int", Def: 4 * 1024 * 1024},
		"tc_rawapi_http_networkProto":       {Desc: "network protocol must be 'tcp', 'tcp4', 'tcp6', 'unix' or 'unixpacket'", Type: "string", Def: "tcp"},

		"tc_rawapi_LogLevel": {Desc: "Logger min severity", Type: "int", Def: 7},

		"tc_rawapi_orgName":      {Desc: "TC_RAWAPI_ORGNAME", Type: "string", Def: "te-food-endorsers"},
		"tc_rawapi_MSPID":        {Desc: "TC_RAWAPI_MSPID", Type: "string", Def: "te-food_endorsersMSP"},
		"tc_rawapi_certPath":     {Desc: "TC_RAWAPI_CERTPATH", Type: "string", Def: "/users/User1@org1.example.com/msp/signcerts/cert.pem"},
		"tc_rawapi_keyPath":      {Desc: "TC_RAWAPI_KEYPATH", Type: "string", Def: "/users/User1@org1.example.com/msp/keystore/"},
		"tc_rawapi_TLSCertPath":  {Desc: "TC_RAWAPI_TLSCERTPATH", Type: "string", Def: "/peers/peer0.org1.example.com/tls/ca.crt"},
		"tc_rawapi_peerEndpoint": {Desc: "TC_RAWAPI_PEERENDPOINT", Type: "string", Def: "localhost:7051"},
		"tc_rawapi_gatewayPeer":  {Desc: "TC_RAWAPI_GATEWAYPEER", Type: "string", Def: "peer0.org1.example.com"},
	}

	err := flagSet.ParseCopy()
	if err != nil {
		panic(err)
	}

	// endregion: cli flags
	// region: logger

	logLevel := syslog.Priority(Config.Entries["tc_rawapi_LogLevel"].Value.(int))

	Logger = *log.NewLogger()
	defer Logger.Close()
	_, _ = Logger.NewCh(log.ChConfig{Severity: &logLevel})

	// endregion: logger
	// region: db

	/*
		if db.DbType(Config.Entries["dbType"].Value.(int)) == db.Postgres {
			db.Defaults = db.DefaultsPostgres // TODO: this goes to TEx-kit/db/db.go
		}

		dbConfig := db.Config{
			Addr:   Config.Entries["dbAddr"].Value.(string),
			DBName: Config.Entries["dbName"].Value.(string),
			Logger: Logger,
			// Params: nil,
			Passwd: Config.Entries["dbPasswd"].Value.(string),
			Type:   db.DbType(Config.Entries["dbType"].Value.(int)),
			User:   Config.Entries["dbUser"].Value.(string),
		}

		Db, err = dbConfig.Open()
		defer Db.Close()

		if err != nil {
			Logger.Out(LOG_EMERG, err)
			panic(err)
		}
	*/

	// endregion: db
	// region: fabric gw

	OrgConfig = fabric.OrgSetup{
		OrgName:      Config.Entries["tc_rawapi_orgName"].Value.(string),
		MSPID:        Config.Entries["tc_rawapi_MSPID"].Value.(string),
		CertPath:     Config.Entries["tc_rawapi_certPath"].Value.(string),
		KeyPath:      Config.Entries["tc_rawapi_keyPath"].Value.(string),
		TLSCertPath:  Config.Entries["tc_rawapi_TLSCertPath"].Value.(string),
		PeerEndpoint: Config.Entries["tc_rawapi_peerEndpoint"].Value.(string),
		GatewayPeer:  Config.Entries["tc_rawapi_gatewayPeer"].Value.(string),
		Logger:       Logger,
	}

	OrgSetup, err = fabric.Initialize(OrgConfig)
	if err != nil {
		Logger.Out(LOG_EMERG, fmt.Sprintf("error initializing setup for %s: %s", OrgConfig.OrgName, err))
		panic(err)
	}
	Logger.Out(LOG_DEBUG, fmt.Sprintf("%+v\n", OrgSetup))

	// web.Serve(web.OrgSetup(*orgSetup))

	// endregion: fabric gw
	// region: http routing

	// region: routers

	httpRouterActual := fasthttprouter.New()
	if Config.Entries["tc_rawapi_http_static_enabled"].Value.(bool) {
		httpFS := &fasthttp.FS{
			Root:       Config.Entries["tc_rawapi_http_static_root"].Value.(string),
			IndexNames: []string{Config.Entries["tc_rawapi_http_static_index"].Value.(string)},
			PathNotFound: func(ctx *fasthttp.RequestCtx) {
				Logger.Out(LOG_NOTICE, "dead end", ctx)
				ctx.Redirect(Config.Entries["tc_rawapi_http_static_error"].Value.(string), 303)
			},
			Compress:           true,
			AcceptByteRange:    true,
			GenerateIndexPages: false,
		}

		httpRouterActual.NotFound = httpFS.NewRequestHandler()
	}

	httpRouterPre := fasthttprouter.New()
	httpRouterPre.NotFound = func(ctx *fasthttp.RequestCtx) {
		Logger.Out(LOG_DEBUG, fmt.Sprintf("%s request on %s from %s with content type '%s' and body '%s' (%s)", ctx.Method(), ctx.Path(), ctx.RemoteAddr(), ctx.Request.Header.Peek("Content-Type"), ctx.PostBody(), ctx))
		Logger.Out(LOG_INFO, fmt.Sprintf("%v: %v", ctx.ID, ctx))
		httpRouterActual.Handler(ctx)
	}

	//  endregion: routers
	// region: routes

	httpRouterActual.GET("/debug", debugConfigGET)
	httpRouterActual.GET("/debug/Config", debugConfigGET)
	httpRouterActual.GET("/debug/OrgConfig", debugOrgConfigGET)
	httpRouterActual.GET("/debug/OrgSetup", debugOrgSetupGET)

	httpRouterActual.POST("/invoke", OrgSetup.Invoke)

	// endregion: routes

	// endregion: http routing
	// region: http and https

	var wg sync.WaitGroup

	if Config.Entries["tc_rawapi_http_enabled"].Value.(bool) {
		http := &fasthttp.Server{
			// Logger:             Logger,
			Handler:            httpRouterPre.Handler,
			LogAllErrors:       Config.Entries["tc_rawapi_http_logAllErrors"].Value.(bool),
			MaxRequestBodySize: Config.Entries["tc_rawapi_http_maxRequestBodySize"].Value.(int),
			Name:               Config.Entries["tc_rawapi_http_name"].Value.(string),
		}
		ln, err := net.Listen(Config.Entries["tc_rawapi_http_networkProto"].Value.(string), ":"+strconv.Itoa(Config.Entries["tc_rawapi_http_port"].Value.(int)))
		if err != nil {
			Logger.Out(LOG_ERR, "error while opening http listener", err)
		} else {
			wg.Add(1)
			go func() {
				Logger.Out(LOG_INFO, "listening for HTTP requests", Config.Entries["tc_rawapi_http_networkProto"].Value, Config.Entries["tc_rawapi_http_port"].Value)
				http.Serve(ln)
			}()
		}
	}

	if Config.Entries["tc_rawapi_https_enabled"].Value.(bool) {
		https := &fasthttp.Server{
			// Logger:          Logger,
			Handler:            httpRouterPre.Handler,
			LogAllErrors:       Config.Entries["tc_rawapi_http_logAllErrors"].Value.(bool),
			MaxRequestBodySize: Config.Entries["tc_rawapi_http_maxRequestBodySize"].Value.(int),
			Name:               Config.Entries["tc_rawapi_http_name"].Value.(string),
		}
		ln, err := net.Listen(Config.Entries["tc_rawapi_http_networkProto"].Value.(string), ":"+strconv.Itoa(Config.Entries["tc_rawapi_https_port"].Value.(int)))
		if err != nil {
			Logger.Out(LOG_ERR, "error while opening https listener", err)
		} else {

			wg.Add(1)
			go func() {
				Logger.Out(LOG_INFO, "listening for HTTPS requests", Config.Entries["tc_rawapi_http_networkProto"].Value, Config.Entries["tc_rawapi_https_port"].Value)
				https.ServeTLSEmbed(ln, []byte(Config.Entries["tc_rawapi_https_cert"].Value.(string)), []byte(Config.Entries["tc_rawapi_https_key"].Value.(string)))
			}()
		}
	}

	wg.Wait()

	// endregion: http and https

}

func debugConfigGET(ctx *fasthttp.RequestCtx) {
	ctx.SetStatusCode(200)
	ctx.SetContentType("application/json")
	ctx.SetBodyString(fmt.Sprintf("%+v\n", Config))
}
func debugOrgConfigGET(ctx *fasthttp.RequestCtx) {
	ctx.SetStatusCode(200)
	ctx.SetContentType("application/json")
	ctx.SetBodyString(fmt.Sprintf("%+v\n", OrgConfig))
}
func debugOrgSetupGET(ctx *fasthttp.RequestCtx) {
	ctx.SetStatusCode(200)
	ctx.SetContentType("application/json")
	ctx.SetBodyString(fmt.Sprintf("%+v\n", OrgSetup))
}
