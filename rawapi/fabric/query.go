// region: packages

package fabric

import (
	"encoding/json"
	"fmt"
	"io"
	"os/exec"

	"github.com/SandorMiskey/TEx-kit/log"
	"github.com/SandorMiskey/TrustChain/rawapi/http"

	"github.com/valyala/fasthttp"
	// "google.golang.org/protobuf/proto"
	// pb "github.com/hyperledger/fabric-protos-go/peer"
	// "github.com/golang/protobuf/dynamic"
	// "github.com/golang/protobuf/proto"
	// "github.com/hyperledger/fabric-gateway/pkg/client"
)

// endregion: packages

//
// Invoke handles chaincode invoke requests.
//

func (setup *OrgSetup) Query(ctx *fasthttp.RequestCtx) {

	// region: request and response

	response := &http.Response{
		CTX:    ctx,
		Logger: setup.Logger,
	}
	request := &request{
		response: response,
	}

	// endregion: request and response
	// region: check for gateway and logger

	request.err = setup.validate(response)
	if request.err != nil {
		return
	}
	logger := setup.Logger.Out
	logger(log.LOG_DEBUG, "received query request has .Logger and .gateway")

	// endregion: logger
	// region: form values

	request.form = &form{
		Chaincode:   string(ctx.FormValue("chaincode")),
		Channel:     string(ctx.FormValue("channel")),
		Function:    string(ctx.FormValue("function")),
		ProtoDecode: string(ctx.FormValue("proto_decode")),
		raw:         ctx.QueryArgs(),
	}
	request.form.raw.VisitAll(func(k, v []byte) {
		if string(k) == "args" {
			request.form.Args = append(request.form.Args, string(v))
		}
	})
	logger(log.LOG_INFO, ctx.ID(), fmt.Sprintf("query request chaincode -> %s, channel -> %s, function -> %s, args -> %s", request.form.Chaincode, request.form.Channel, request.form.Function, request.form.Args))
	logger(log.LOG_DEBUG, ctx.ID(), fmt.Sprintf("query request with raw args %#v", request))

	// TODO: validate values

	// endregion: form values
	// region: fetch result

	request.network = setup.gateway.GetNetwork(request.form.Channel)
	request.contract = request.network.GetContract(request.form.Chaincode)

	resultByte, err := request.contract.EvaluateTransaction(request.form.Function, request.form.Args...)
	if err != nil {
		request.error(err)
		return
	}
	logger(log.LOG_DEBUG, ctx.ID(), fmt.Sprintf("result type -> %T", []byte(resultByte)))

	// endregion: fetch result
	// region: prepare message

	resultMsg := &message{
		ID:     "-",
		Status: "OK",
		Form:   request.form,
		// Result: resultMap,
	}

	// endregion: prepare message
	// region: deconstruct result

	if len(request.form.ProtoDecode) > 0 {
		logger(log.LOG_DEBUG, response.CTX.ID(), "ProtoDecode", request.form.ProtoDecode)

		cmd := exec.Command("configtxlator", "proto_decode", "--input=/dev/stdin", "--type="+request.form.ProtoDecode)
		cmdIn, err := cmd.StdinPipe()
		if err != nil {
			logger(log.LOG_ERR, response.CTX.ID(), err)
			request.error(err)
			return
		}
		cmdOut, err := cmd.StdoutPipe()
		if err != nil {
			logger(log.LOG_ERR, response.CTX.ID(), err)
			request.error(err)
			return
		}
		cmd.Start()
		cmdIn.Write(resultByte)
		cmdIn.Close()
		cmdBytes, err := io.ReadAll(cmdOut)
		if err != nil {
			logger(log.LOG_ERR, response.CTX.ID(), err)
			request.error(err)
			return
		}
		cmd.Wait()
		resultByte = cmdBytes
	}

	var rawData json.RawMessage

	err = json.Unmarshal([]byte(resultByte), &rawData)
	if err != nil {
		// logger(log.LOG_WARNING, ctx.ID(), fmt.Sprintf("error processing result into even json.RawMessage -> %s -> %s", resultByte, err))
		logger(log.LOG_WARNING, response.CTX.ID(), fmt.Sprintf("error processing result into even json.RawMessage -> %s", err))
		request.error(err)
		return
	} else {
		resultMsg.Result = rawData
	}

	logger(log.LOG_DEBUG, ctx.ID(), fmt.Sprintf("result -> %s", rawData))

	// endregion: deconstruct
	// region: closing

	response.Message = resultMsg
	response.SendJSON(nil)

	// endregion: closing

}
