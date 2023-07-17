package fabric

import (
	"context"
	"errors"
	"fmt"

	"github.com/SandorMiskey/TEx-kit/log"
	"github.com/hyperledger/fabric-gateway/pkg/client"
	"github.com/hyperledger/fabric-protos-go-apiv2/gateway"
	"github.com/valyala/fasthttp"
	"google.golang.org/grpc/status"
)

// Invoke handles chaincode invoke requests.
func (setup *OrgSetup) Invoke(ctx *fasthttp.RequestCtx) {

	// region: logger

	logger := setup.Logger.Out
	logger(log.LOG_DEBUG, "received invoke request")

	// endregion: logger
	// region: form values

	chainCodeName := string(ctx.FormValue("chaincodeid"))
	channelID := string(ctx.FormValue("channelid"))
	function := string(ctx.FormValue("function"))
	argsRaw := *ctx.PostArgs()
	argsStr := make([]string, 0)
	argsRaw.VisitAll(func(k, v []byte) {
		if string(k) == "args" {
			argsStr = append(argsStr, string(v))
		}
	})

	logger(log.LOG_INFO, fmt.Sprintf("%v: invoke request chainCodeName: %s, channelID: %s, function: %s, args: %s", ctx.ID, chainCodeName, channelID, function, argsStr))
	logger(log.LOG_DEBUG, fmt.Sprintf("%v: %+v\n", ctx.ID, argsRaw))

	// TODO: validate values

	// endregion: form values
	// region: proposal

	network := setup.Gateway.GetNetwork(channelID)
	contract := network.GetContract(chainCodeName)
	txn_proposal, err := contract.NewProposal(function, client.WithArguments(argsStr...))
	if err != nil {
		msg := fmt.Sprintf("%v: error creating txn proposal: %s (%#v)", ctx.ID, err, txn_proposal)
		logger(log.LOG_ERR, msg)
		ctx.SetBodyString(msg)
		ctx.SetStatusCode(fasthttp.StatusInternalServerError)
		return
	}
	logger(log.LOG_INFO, fmt.Sprintf("%v: invoke request proposal succeeded", ctx.ID))
	logger(log.LOG_DEBUG, fmt.Sprintf("%v: network: %+v, cotract: %+v, txn_proposal %#v", ctx.ID, network, contract, *txn_proposal))

	// endregion: proposal
	// region: endorse

	txn_endorsed, err := txn_proposal.Endorse()
	if err != nil {
		fmt.Println("")
		fmt.Println("")
		fmt.Println("")
		fmt.Println("")
		fmt.Println("")
		ehandler(err, contract, txn_proposal, network)
		msg := fmt.Sprintf("%v: error endorsing txn: %+v (%+v)", ctx.ID, err, errors.Unwrap(err))
		// logger(log.LOG_ERR, msg)
		ctx.SetBodyString(msg)
		ctx.SetStatusCode(fasthttp.StatusInternalServerError)
		return
	}
	logger(log.LOG_INFO, fmt.Sprintf("%v: invoke request proposal endorsed", ctx.ID))
	logger(log.LOG_DEBUG, fmt.Sprintf("%v: txn_endorsed: %+v", ctx.ID, txn_endorsed))

	// endregion: endorse
	// region: commit

	txn_committed, err := txn_endorsed.Submit()
	if err != nil {
		msg := fmt.Sprintf("error submitting transaction: %s", err)
		logger(log.LOG_ERR, msg)
		ctx.SetBodyString(msg)
		ctx.SetStatusCode(fasthttp.StatusInternalServerError)
		return
	}
	logger(log.LOG_INFO, fmt.Sprintf("%v: invoke request commited, transaction ID: %s, response: %s, txn_commited", ctx.ID, txn_committed.TransactionID(), txn_endorsed.Result()))
	logger(log.LOG_DEBUG, fmt.Sprintf("%v: txn_committed: %+v", ctx.ID, txn_committed))

	// endregion: commit

	ctx.SetStatusCode(200)
	ctx.SetContentType("application/json")
	ctx.SetBodyString(fmt.Sprintf("Transaction ID : %s Response: %s", txn_committed.TransactionID(), txn_endorsed.Result()))
}

func ehandler(err interface{}, contract *client.Contract, proposal *client.Proposal, network *client.Network) {
	switch err := err.(type) {
	case *client.EndorseError:
		fmt.Printf("transaction %s\n", err.TransactionID)
		fmt.Printf("transaction %#v\n", err.GRPCStatus)
		fmt.Printf("err: %#v\n", err)
		fmt.Printf("status: %s\n", status.Code(err))
		fmt.Printf("contract: %#v\n", contract)
		fmt.Printf("proposal: %#v\n", proposal)
		fmt.Printf("network: %#v\n", network)

		statusErr := status.Convert(err)

		details := statusErr.Details()
		if len(details) > 0 {
			fmt.Println("Error Details:")

			for _, detail := range details {
				switch detail := detail.(type) {
				case *gateway.ErrorDetail:
					fmt.Printf("- address: %s, mspId: %s, message: %s\n", detail.Address, detail.MspId, detail.Message)
				}
			}
		}
	case *client.SubmitError:
		fmt.Printf("Submit error for transaction %s with gRPC status %v: %s\n", err.TransactionID, status.Code(err), err)
	case *client.CommitStatusError:
		if errors.Is(err, context.DeadlineExceeded) {
			fmt.Printf("Timeout waiting for transaction %s commit status: %s", err.TransactionID, err)
		} else {
			fmt.Printf("Error obtaining commit status for transaction %s with gRPC status %v: %s\n", err.TransactionID, status.Code(err), err)
		}
	case *client.CommitError:
		fmt.Printf("Transaction %s failed to commit with status %d: %s\n", err.TransactionID, int32(err.Code), err)
	default:
		panic(fmt.Errorf("unexpected error type %T: %w", err, err))
	}

}
