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
// region: global, const

var (
	// Db     *db.Db
	config cfg.Config
	logger log.Logger
	org    fabric.OrgSetup
	server http.ServerSetup
	router http.RouterSetup
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

	// region: config and cli flags

	config := *cfg.NewConfig(os.Args[0])
	flagSet := config.NewFlagSet(os.Args[0])
	flagSet.Entries = map[string]cfg.Entry{
		// "dbAddr":        {Desc: "database address", Type: "string", Def: "/app/mgmt.db"},
		// "dbName":        {Desc: "database name", Type: "string", Def: "mgmt"},
		// "dbPasswd":      {Desc: "database user password", Type: "string", Def: ""},
		// "dbPasswd_file": {Desc: "database user password", Type: "string", Def: ""},
		// "dbType":        {Desc: "db type as in TEx-kit/db/db.go", Type: "int", Def: 4},
		// "dbUser":        {Desc: "database user", Type: "string", Def: "mgmt"},

		"tc_rawapi_key":      {Desc: "api key, skip if not set", Type: "string", Def: ""},
		"tc_rawapi_key_file": {Desc: "api key from file", Type: "string", Def: ""},

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

		"tc_rawapi_lator_which": {Desc: "path to configtxlator (if empty, will dump protobuf as base64 encoded string)", Type: "string", Def: "/usr/local/bin/configtxlator"},
		"tc_rawapi_lator_bind":  {Desc: "address to bind configtxlator's rest api to", Type: "string", Def: "127.0.0.1"},
		"tc_rawapi_lator_port":  {Desc: "port where configtxlator will listen", Type: "int", Def: 1337},

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

	logLevel := syslog.Priority(config.Entries["tc_rawapi_LogLevel"].Value.(int))

	logger = *log.NewLogger()
	defer logger.Close()
	_, _ = logger.NewCh(log.ChConfig{Severity: &logLevel})

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
	// region: configtxlator

	lator := fabric.Lator{
		Bind:  config.Entries["tc_rawapi_lator_bind"].Value.(string),
		Port:  config.Entries["tc_rawapi_lator_port"].Value.(int),
		Which: config.Entries["tc_rawapi_lator_which"].Value.(string),
	}
	_, err = lator.Init()
	if err != nil {
		logger.Out(LOG_EMERG, "error initializing configtxlator instance", err, lator)
		panic(err)
	}
	logger.Out(LOG_DEBUG, "configtxlator instance", lator)

	// endregion: configtxlator
	// region: fabric gw

	org = fabric.OrgSetup{
		CertPath:     config.Entries["tc_rawapi_certPath"].Value.(string),
		GatewayPeer:  config.Entries["tc_rawapi_gatewayPeer"].Value.(string),
		KeyPath:      config.Entries["tc_rawapi_keyPath"].Value.(string),
		Logger:       &logger,
		Lator:        &lator,
		MSPID:        config.Entries["tc_rawapi_MSPID"].Value.(string),
		OrgName:      config.Entries["tc_rawapi_orgName"].Value.(string),
		PeerEndpoint: config.Entries["tc_rawapi_peerEndpoint"].Value.(string),
		TLSCertPath:  config.Entries["tc_rawapi_TLSCertPath"].Value.(string),
	}
	logger.Out(LOG_DEBUG, "OrgSetup", org)

	_, err = org.Init()
	if err != nil {
		logger.Out(LOG_EMERG, fmt.Sprintf("error initializing setup for %s: %s", org.OrgName, err))
		panic(err)
	}
	logger.Out(LOG_DEBUG, fmt.Sprintf("OrgInstance: %+v\n", org))

	// endregion: fabric gw
	// region: http routing

	// region: router

	router = http.RouterSetup{
		Logger:        &logger,
		Key:           config.Entries["tc_rawapi_key"].Value.(string),
		StaticEnabled: config.Entries["tc_rawapi_http_static_enabled"].Value.(bool),
		StaticRoot:    config.Entries["tc_rawapi_http_static_root"].Value.(string),
		StaticIndex:   config.Entries["tc_rawapi_http_static_index"].Value.(string),
		StaticError:   config.Entries["tc_rawapi_http_static_error"].Value.(string),
	}
	logger.Out(LOG_DEBUG, fmt.Sprintf("RouterSetup: %+v\n", router))

	_, err = router.RouterInit()
	if err != nil {
		logger.Out(LOG_EMERG, fmt.Sprintf("error in http:RouterInit(): %s (%+v)", err, router))
		panic(err)
	}
	logger.Out(LOG_DEBUG, fmt.Sprintf("RouterInstance: %+v\n", router))

	// endregion: router
	// region: routes

	Routes := router.Routes

	Routes.POST("/invoke", org.Invoke)
	Routes.GET("/query", org.Query)
	Routes.GET("/debug", debugSupersetGET)
	Routes.GET("/dummy", func(ctx *fasthttp.RequestCtx) {
		r := &http.Response{
			CTX:     ctx,
			Logger:  &logger,
			Status:  200,
			Message: fmt.Errorf("dummy text"),
		}
		r.Send(nil)
	})

	// endregion: routes

	// endregion: http routing
	// region: http and https

	var wg sync.WaitGroup

	server = http.ServerSetup{
		HttpEnabled:        config.Entries["tc_rawapi_http_enabled"].Value.(bool),
		HttpPort:           config.Entries["tc_rawapi_http_port"].Value.(int),
		HttpsEnabled:       config.Entries["tc_rawapi_https_enabled"].Value.(bool),
		HttpsPort:          config.Entries["tc_rawapi_https_port"].Value.(int),
		HttpsCert:          config.Entries["tc_rawapi_https_cert"].Value.(string),
		HttpsKey:           config.Entries["tc_rawapi_https_key"].Value.(string),
		LogAllErrors:       config.Entries["tc_rawapi_http_logAllErrors"].Value.(bool),
		Logger:             &logger,
		MaxRequestBodySize: config.Entries["tc_rawapi_http_maxRequestBodySize"].Value.(int),
		Name:               config.Entries["tc_rawapi_http_name"].Value.(string),
		NetworkProto:       config.Entries["tc_rawapi_http_networkProto"].Value.(string),
		Router:             router.Router,
		WaitGroup:          &wg,
	}
	logger.Out(LOG_DEBUG, fmt.Sprintf("ServerSetup: %+v\n", server))

	_, err = server.ServerLaunch()
	if err != nil {
		logger.Out(LOG_EMERG, fmt.Sprintf("error initializing server for %s: %s", server.Name, err))
		panic(err)
	}
	logger.Out(LOG_DEBUG, fmt.Sprintf("ServerInstance: %+v\n", server))

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
			Config: &config,
			Org:    &org,
			Server: &server,
			Router: &router,
		},
		Logger: &logger,
		CTX:    ctx,
	}
	response.SendJSON(nil)
}

// endregion: debug endpoint
