package http

import (
	"encoding/json"
	"fmt"

	"github.com/SandorMiskey/TEx-kit/log"
	"github.com/valyala/fasthttp"
)

// "github.com/buaazp/fasthttprouter"
// "github.com/valyala/fasthttp"

type Response struct {
	ContentType string               `json:"ContentType"`
	CTX         *fasthttp.RequestCtx `json:"-"`
	Logger      *log.Logger          `json:"-"`
	Status      int                  `json:"Status"`
	Message     interface{}          `json:"Message"`
	err         error                `json:"-"`
}

func (r *Response) Send(msg interface{}) error {

	// region: param

	if msg != nil {
		r.Message = msg
	}

	// endregion: param
	// region: check content type

	if r.ContentType == "" {
		r.ContentType = "text/plain"
	}

	// endregion: content type
	// region: logger

	if r.Logger == nil {
		r.Logger = log.NewLogger()
		defer r.Logger.Close()
		_, _ = r.Logger.NewCh()
		r.Logger.Out("there was no r.Logger, so launched a default one")
	}
	logger := r.Logger.Out

	// endregion: logger
	// region: status

	if r.Status == 0 {
		r.Status = 200
	}

	// endregion: status
	// region: CTX

	if r.CTX != nil {
		r.CTX.SetContentType(r.ContentType)
		r.CTX.SetStatusCode(r.Status)

		switch v := r.Message.(type) {
		case string:
			logger(log.LOG_DEBUG, fmt.Sprintf("%v: r.Message type is string: %s", r.CTX.ID, r.Message.(string)))
			r.CTX.SetBodyString(r.Message.(string))
		case error:
			logger(log.LOG_DEBUG, fmt.Sprintf("%v: r.Message type is error: %s", r.CTX.ID, r.Message.(error).Error()))
			r.CTX.SetBodyString(r.Message.(error).Error())
		case []byte:
			logger(log.LOG_DEBUG, fmt.Sprintf("%v: r.Message type is []byte: %s", r.CTX.ID, r.Message.([]byte)))
			r.CTX.SetBody(r.Message.([]byte))
		default:
			err := fmt.Errorf("%v: unexpected type of content: %T (%s)", r.CTX.ID, v, r.Message)
			r.error(err)
			return r.err
		}

		logger(log.LOG_INFO, fmt.Sprintf("%v: response is given with content type: %s, status: %v", r.CTX.ID, r.ContentType, r.Status))
		return nil
	} else {
		err := fmt.Errorf("no fasthttp.RequestCtx")
		r.error(err)
		return r.err
	}

	// endregion: CTX
}

func (r *Response) SendJSON(msg interface{}) error {
	var err error = nil

	if msg != nil {
		r.Message = msg
	}
	r.Message, err = json.Marshal(r.Message)
	if err != nil {
		r.error(fmt.Errorf("%v: unable to marshal json: %s (%s)", r.CTX.ID, err, r.Message))
		return r.err
	}

	r.ContentType = "application/json"
	return r.Send(nil)
}

func (r *Response) error(err error) {
	if err != nil {
		r.err = err
	}
	var msg string
	if r.CTX != nil {
		msg = fmt.Sprintf("%v: error in response: %s", r.CTX.ID, r.err)
		r.CTX.SetStatusCode(500)
		r.CTX.SetBodyString(msg)
	} else {
		msg = fmt.Sprintf("error in response: %s", r.err)
	}
	r.Logger.Out(log.LOG_ERR, msg)
	r.Logger.Out(log.LOG_DEBUG, fmt.Sprintf("%s (%v)", msg, r))
}
