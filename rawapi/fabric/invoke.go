// region: packages

package fabric

import (
	"fmt"

	"github.com/SandorMiskey/TEx-kit/log"
	"github.com/SandorMiskey/TrustChain/rawapi/http"
	"github.com/hyperledger/fabric-gateway/pkg/client"
	"github.com/valyala/fasthttp"
)

// endregion: packages

//
// Invoke handles chaincode invoke requests.
//

func (setup *OrgSetup) Invoke(ctx *fasthttp.RequestCtx) {

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
	logger(log.LOG_DEBUG, "received invoke request has .Logger and .gateway")

	// endregion: logger
	// region: form values

	request.form = &form{
		Chaincode: string(ctx.FormValue("chaincode")),
		Channel:   string(ctx.FormValue("channel")),
		Function:  string(ctx.FormValue("function")),
		raw:       ctx.PostArgs(),
	}
	request.form.raw.VisitAll(func(k, v []byte) {
		if string(k) == "args" {
			request.form.Args = append(request.form.Args, string(v))
		}
	})
	logger(log.LOG_INFO, fmt.Sprintf("%v: invoke request chaincode -> %s, channel -> %s, function -> %s, args -> %s", ctx.ID, request.form.Chaincode, request.form.Channel, request.form.Function, request.form.Args))
	logger(log.LOG_DEBUG, fmt.Sprintf("%v: invoke request raw args %#v\n", ctx.ID, request.form))

	// TODO: validate values

	// endregion: form values
	// region: proposal

	request.network = setup.gateway.GetNetwork(request.form.Channel)
	request.contract = request.network.GetContract(request.form.Chaincode)
	request.proposal, request.err = request.contract.NewProposal(request.form.Function, client.WithArguments(request.form.Args...))
	if request.err != nil {
		request.error(nil)
		return
	}
	logger(log.LOG_INFO, fmt.Sprintf("%v: invoke request proposal succeeded", ctx.ID))
	logger(log.LOG_DEBUG, fmt.Sprintf("%v: invoke request details: request -> %#v", ctx.ID, request))

	// endregion: proposal
	// region: endorse

	request.transaction, request.err = request.proposal.Endorse()
	if request.err != nil {
		request.error(nil)
		return
	}
	logger(log.LOG_INFO, fmt.Sprintf("%v: invoke request proposal endorsed", ctx.ID))
	logger(log.LOG_DEBUG, fmt.Sprintf("%v: endorsed: request -> %#v", ctx.ID, request))

	// endregion: endorse
	// region: commit

	request.commit, request.err = request.transaction.Submit()
	if request.err != nil {
		request.error(nil)
		return
	}
	logger(log.LOG_INFO, fmt.Sprintf("%v: invoke request commited, transaction ID: %s, response: %s", ctx.ID, request.commit.TransactionID(), request.transaction.Result()))
	logger(log.LOG_DEBUG, fmt.Sprintf("%v: committed: request -> %#v", ctx.ID, request))

	// endregion: commit
	// region: closing

	response.Message = message{
		ID:     request.commit.TransactionID(),
		Form:   request.form,
		Status: "OK",
		Result: request.transaction.Result(),
	}
	response.SendJSON(nil)

	// endregion: closing

}
