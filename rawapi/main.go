// region: packages

package main

import (
	"fmt"
	"log/syslog"
	"os"
	"sync"

	"github.com/SandorMiskey/TEx-kit/cfg"
	"github.com/SandorMiskey/TEx-kit/log"
	"github.com/SandorMiskey/TrustChain/rawapi/fabric"
	"github.com/SandorMiskey/TrustChain/rawapi/http"

	// "github.com/davecgh/go-spew/spew"

	"github.com/valyala/fasthttp"
)

// endregion: packages
// region: global variables

var (
	// Db     *db.Db
	Config         cfg.Config
	Logger         log.Logger
	OrgInstance    fabric.OrgSetup
	ServerInstance http.ServerSetup
	RouterInstance http.RouterSetup
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

		"tc_rawapi_key": {Desc: "api key, skip if not set", Type: "string", Def: ""},

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

	OrgInstance = fabric.OrgSetup{
		OrgName:      Config.Entries["tc_rawapi_orgName"].Value.(string),
		MSPID:        Config.Entries["tc_rawapi_MSPID"].Value.(string),
		CertPath:     Config.Entries["tc_rawapi_certPath"].Value.(string),
		KeyPath:      Config.Entries["tc_rawapi_keyPath"].Value.(string),
		TLSCertPath:  Config.Entries["tc_rawapi_TLSCertPath"].Value.(string),
		PeerEndpoint: Config.Entries["tc_rawapi_peerEndpoint"].Value.(string),
		GatewayPeer:  Config.Entries["tc_rawapi_gatewayPeer"].Value.(string),
		Logger:       &Logger,
	}
	Logger.Out(LOG_DEBUG, fmt.Sprintf("OrgSetup: %+v\n", OrgInstance))

	_, err = OrgInstance.Init()
	if err != nil {
		Logger.Out(LOG_EMERG, fmt.Sprintf("error initializing setup for %s: %s", OrgInstance.OrgName, err))
		panic(err)
	}
	Logger.Out(LOG_DEBUG, fmt.Sprintf("OrgInstance: %+v\n", OrgInstance))

	// endregion: fabric gw
	// region: http routing

	// region: router

	RouterInstance = http.RouterSetup{
		Logger:        &Logger,
		Key:           Config.Entries["tc_rawapi_key"].Value.(string),
		StaticEnabled: Config.Entries["tc_rawapi_http_static_enabled"].Value.(bool),
		StaticRoot:    Config.Entries["tc_rawapi_http_static_root"].Value.(string),
		StaticIndex:   Config.Entries["tc_rawapi_http_static_index"].Value.(string),
		StaticError:   Config.Entries["tc_rawapi_http_static_error"].Value.(string),
	}
	Logger.Out(LOG_DEBUG, fmt.Sprintf("RouterSetup: %+v\n", RouterInstance))

	_, err = RouterInstance.RouterInit()
	if err != nil {
		Logger.Out(LOG_EMERG, fmt.Sprintf("error in http:RouterInit(): %s (%+v)", err, RouterInstance))
		panic(err)
	}
	Logger.Out(LOG_DEBUG, fmt.Sprintf("RouterInstance: %+v\n", RouterInstance))

	// endregion: router
	// region: routes

	Routes := RouterInstance.Routes

	Routes.POST("/invoke", OrgInstance.Invoke)
	Routes.GET("/query", OrgInstance.Query)
	Routes.GET("/debug", debugSupersetGET)
	Routes.GET("/dummy", func(ctx *fasthttp.RequestCtx) {
		r := &http.Response{
			CTX:     ctx,
			Logger:  &Logger,
			Status:  200,
			Message: fmt.Errorf("dummy text"),
		}
		r.Send(nil)
	})

	// endregion: routes

	// endregion: http routing
	// region: http and https

	var wg sync.WaitGroup

	ServerInstance = http.ServerSetup{
		HttpEnabled:        Config.Entries["tc_rawapi_http_enabled"].Value.(bool),
		HttpPort:           Config.Entries["tc_rawapi_http_port"].Value.(int),
		HttpsEnabled:       Config.Entries["tc_rawapi_https_enabled"].Value.(bool),
		HttpsPort:          Config.Entries["tc_rawapi_https_port"].Value.(int),
		HttpsCert:          Config.Entries["tc_rawapi_https_cert"].Value.(string),
		HttpsKey:           Config.Entries["tc_rawapi_https_key"].Value.(string),
		LogAllErrors:       Config.Entries["tc_rawapi_http_logAllErrors"].Value.(bool),
		Logger:             &Logger,
		MaxRequestBodySize: Config.Entries["tc_rawapi_http_maxRequestBodySize"].Value.(int),
		Name:               Config.Entries["tc_rawapi_http_name"].Value.(string),
		NetworkProto:       Config.Entries["tc_rawapi_http_networkProto"].Value.(string),
		Router:             RouterInstance.Router,
		WaitGroup:          &wg,
	}
	Logger.Out(LOG_DEBUG, fmt.Sprintf("ServerSetup: %+v\n", ServerInstance))

	_, err = ServerInstance.ServerLaunch()
	if err != nil {
		Logger.Out(LOG_EMERG, fmt.Sprintf("error initializing server for %s: %s", ServerInstance.Name, err))
		panic(err)
	}
	Logger.Out(LOG_DEBUG, fmt.Sprintf("ServerInstance: %+v\n", ServerInstance))

	wg.Wait()

	// endregion: http and https

}

// region: debug endpoint

func debugSupersetGET(ctx *fasthttp.RequestCtx) {
	type superset struct {
		Config *cfg.Config
		Org    *fabric.OrgSetup
		Server *http.ServerSetup
		Router *http.RouterSetup
	}
	response := &http.Response{
		Message: &superset{
			Config: &Config,
			Org:    &OrgInstance,
			Server: &ServerInstance,
			Router: &RouterInstance,
		},
		Logger: &Logger,
		CTX:    ctx,
	}
	response.SendJSON(nil)
}

// endregion: debug endpoint
