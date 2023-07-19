package http

import (
	"errors"
	"fmt"

	"github.com/SandorMiskey/TEx-kit/log"
	"github.com/buaazp/fasthttprouter"
	"github.com/valyala/fasthttp"
)

type RouterSetup struct {
	Logger        *log.Logger            `json:"-"`
	Router        *fasthttprouter.Router `json:"-"`
	Routes        *fasthttprouter.Router `json:"-"`
	StaticEnabled bool                   `json:"StaticEnabled"`
	StaticRoot    string                 `json:"StaticRoot"`
	StaticIndex   string                 `json:"StaticIndex"`
	StaticError   string                 `json:"StaticError"`
}

func (setup *RouterSetup) RouterInit() (*RouterSetup, error) {

	// region: check for logger

	if setup.Logger == nil {
		return setup, errors.New("http.RouterInit() needs a logger!")
	}
	logger := setup.Logger.Out

	// endregion: logger

	httpRouterActual := fasthttprouter.New()
	if setup.StaticEnabled {
		httpFS := &fasthttp.FS{
			Root:       setup.StaticRoot,
			IndexNames: []string{setup.StaticIndex},
			PathNotFound: func(ctx *fasthttp.RequestCtx) {
				logger(log.LOG_INFO, fmt.Sprintf("%v: dead end: %s", ctx.ID, ctx))
				ctx.Redirect(setup.StaticError, 303)
			},
			Compress:           true,
			AcceptByteRange:    true,
			GenerateIndexPages: false,
		}
		httpRouterActual.NotFound = httpFS.NewRequestHandler()
	} else {
		httpRouterActual.NotFound = func(ctx *fasthttp.RequestCtx) {
			logger(log.LOG_INFO, fmt.Sprintf("%v: no such route: %s", ctx.ID, ctx))
			ctx.SetStatusCode(404)
			ctx.SetBodyString("Not found")
		}
	}

	setup.Logger.Out(log.LOG_DEBUG, fmt.Sprintf("httpRouterActual: %+v\n", httpRouterActual))

	httpRouterPre := fasthttprouter.New()
	httpRouterPre.NotFound = func(ctx *fasthttp.RequestCtx) {
		logger(log.LOG_DEBUG, fmt.Sprintf("%v: %s request on %s from %s with content type '%s' and body '%s' (%s)", ctx.ID, ctx.Method(), ctx.Path(), ctx.RemoteAddr(), ctx.Request.Header.Peek("Content-Type"), ctx.PostBody(), ctx))
		logger(log.LOG_INFO, fmt.Sprintf("%v: %v", ctx.ID, ctx))
		httpRouterActual.Handler(ctx)

	}
	logger(log.LOG_DEBUG, fmt.Sprintf("httpRouterPre: %+v\n", httpRouterPre))

	setup.Routes = httpRouterActual
	setup.Router = httpRouterPre
	return setup, nil
}
