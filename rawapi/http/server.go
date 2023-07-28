package http

import (
	"errors"
	"net"
	"strconv"
	"sync"

	"github.com/SandorMiskey/TEx-kit/log"
	"github.com/buaazp/fasthttprouter"
	"github.com/valyala/fasthttp"
)

// "github.com/SandorMiskey/TEx-kit/cfg"
// "github.com/SandorMiskey/TrustChain/rawapi/fabric"
// // "github.com/davecgh/go-spew/spew"

type ServerSetup struct {
	HttpEnabled        bool                   `json:"HttpEnabled"`
	HttpPort           int                    `json:"HttpPort"`
	HttpsEnabled       bool                   `json:"HttpsEnabled"`
	HttpsPort          int                    `json:"HttpsPort"`
	HttpsCert          string                 `json:"HttpsCert"`
	HttpsKey           string                 `json:"HttpsKey"`
	LogAllErrors       bool                   `json:"LogAllErrors"`
	Logger             *log.Logger            `json:"-"`
	MaxRequestBodySize int                    `json:"MaxRequestBodySize"`
	Name               string                 `json:"Name"`
	NetworkProto       string                 `json:"NetworkProto"`
	Router             *fasthttprouter.Router `json:"-"`
	WaitGroup          *sync.WaitGroup        `json:"-"`
}

func (setup *ServerSetup) ServerLaunch() (*ServerSetup, error) {

	// region: check

	if setup.Logger == nil {
		return setup, errors.New("http.ServerLaunch() needs a logger")
	}
	logger := setup.Logger.Out

	// endregion: check

	// region: http

	if setup.HttpEnabled {
		http := &fasthttp.Server{
			// Logger:             setup.Logger,
			Handler:            setup.Router.Handler,
			LogAllErrors:       setup.LogAllErrors,
			MaxRequestBodySize: setup.MaxRequestBodySize,
			Name:               setup.Name,
		}
		ln, err := net.Listen(setup.NetworkProto, ":"+strconv.Itoa(setup.HttpPort))
		if err != nil {
			logger(log.LOG_ERR, "error while opening http listener", err)
			return nil, err
		} else {
			if setup.WaitGroup != nil {
				setup.WaitGroup.Add(1)
			}
			go func() {
				logger(log.LOG_INFO, "listening for HTTP requests", setup.NetworkProto, setup.HttpPort)
				http.Serve(ln)
			}()
		}
	}

	// endregion: http
	// region: https

	if setup.HttpsEnabled {
		https := &fasthttp.Server{
			// Logger:          Logger,
			Handler:            setup.Router.Handler,
			LogAllErrors:       setup.LogAllErrors,
			MaxRequestBodySize: setup.MaxRequestBodySize,
			Name:               setup.Name,
		}
		ln, err := net.Listen(setup.NetworkProto, ":"+strconv.Itoa(setup.HttpsPort))
		if err != nil {
			logger(log.LOG_ERR, "error while opening https listener", err)
			return setup, err
		} else {
			if setup.WaitGroup != nil {
				setup.WaitGroup.Add(1)
			}
			go func() {
				logger(log.LOG_INFO, "listening for HTTPS requests", setup.NetworkProto, setup.HttpsPort)
				https.ServeTLSEmbed(ln, []byte(setup.HttpsCert), []byte(setup.HttpsKey))
			}()
		}
	}

	// endregion: https

	return setup, nil
}
