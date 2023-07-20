// region: packages

package fabric

import (
	"context"
	"errors"
	"fmt"

	"github.com/SandorMiskey/TEx-kit/log"
	"github.com/SandorMiskey/TrustChain/rawapi/http"
	"github.com/hyperledger/fabric-gateway/pkg/client"
	"github.com/hyperledger/fabric-protos-go-apiv2/gateway"
	"github.com/valyala/fasthttp"
	"google.golang.org/grpc/status"
)

// 	"github.com/SandorMiskey/TEx-kit/log"
// 	"github.com/hyperledger/fabric-gateway/pkg/client"
// 	"github.com/hyperledger/fabric-protos-go-apiv2/gateway"
// 	"github.com/valyala/fasthttp"
// 	"google.golang.org/grpc/status"

// endregion: packages

type form struct {
	Chaincode string         `json:"Chaincode"`
	Channel   string         `json:"Channel"`
	Function  string         `json:"Function"`
	Args      []string       `json:"Args"`
	raw       *fasthttp.Args `json:"-"`
}

type request struct {
	err         error
	contract    *client.Contract
	proposal    *client.Proposal
	transaction *client.Transaction
	commit      *client.Commit
	network     *client.Network
	form        *form
	response    *http.Response
}

type message struct {
	ID     string      `json:"ID"`
	Status string      `json:"Status"`
	Result interface{} `json:"Result"`
	Form   *form       `json:"Form"`
}

type messageError struct {
	message
	Details []map[string]string `json:"Details"`
	Type    string              `json:"Type"`
}

// func (r *request) error(err interface{}, contract *client.Contract, proposal *client.Proposal, network *client.Network) {
func (r *request) error(err error) {

	// region: set r.err

	if err != nil {
		r.err = err
	}

	// endregion: r.err
	// region: logger

	logger := r.response.Logger.Out
	logger(log.LOG_DEBUG, fmt.Sprintf("%v: error in fabric request: %s", r.response.CTX.ID, r.err))

	// endregion: logger
	// region: new msg

	msg := messageError{
		message: message{
			Form: r.form,
		},
	}

	// endregion: msg
	// region: error types

	switch err := r.err.(type) {
	case *client.EndorseError:
		msg.message.ID = err.TransactionID
		msg.message.Status = fmt.Sprintf("%s", status.Code(err))
		msg.message.Result = fmt.Sprintf("%v: endorse error for transaction %s with gRPC status %v: %s", r.response.CTX.ID, msg.message.ID, msg.message.Status, err)
	case *client.SubmitError:
		msg.message.ID = err.TransactionID
		msg.message.Status = fmt.Sprintf("%s", status.Code(r.err))
		msg.message.Result = fmt.Sprintf("%v: submit error for transaction %s with gRPC status %v: %s", r.response.CTX.ID, msg.message.ID, msg.message.Status, err)
	case *client.CommitStatusError:
		msg.message.ID = err.TransactionID
		if errors.Is(err, context.DeadlineExceeded) {
			msg.message.Status = fmt.Sprintf("%s", err)
			msg.message.Result = fmt.Sprintf("%v: timeout waiting for transaction %s commit status: %s", r.response.CTX.ID, msg.message.ID, err)
		} else {
			msg.message.Status = fmt.Sprintf("%s", status.Code(err))
			msg.message.Result = fmt.Sprintf("%v: error obtaining commit status for transaction %s commit status %s: %s", r.response.CTX.ID, msg.message.ID, msg.message.Status, err)
		}
	case *client.CommitError:
		msg.message.ID = err.TransactionID
		msg.message.Status = fmt.Sprintf("%s", int32(err.Code))
		msg.message.Result = fmt.Sprintf("%v: transaction %s failed to commit with status %d: %s", r.response.CTX.ID, err.TransactionID, int32(err.Code), err)
	default:
		msg.message.ID = "-"
		msg.message.Status = fmt.Sprintf("%s", status.Code(r.err))
		msg.message.Result = fmt.Sprintf("%v: unexpected error type %T: %s", r.response.CTX.ID, err, err)
	}

	// endregion: error types
	// region: error details

	statusErr := status.Convert(r.err)
	details := statusErr.Details()
	msg.Details = make([]map[string]string, 0)
	if len(details) > 0 {
		for _, detail := range details {
			switch detail := detail.(type) {
			case *gateway.ErrorDetail:
				msg.Details = append(msg.Details, map[string]string{"address": detail.Address, "mspId": detail.MspId, "message": detail.Message})
			}
		}
	}

	// endregion: error details
	// region: closing

	msg.Type = fmt.Sprintf("%T", r.err)
	r.response.Message = msg

	logger(log.LOG_ERR, msg.message.Result)
	logger(log.LOG_DEBUG, fmt.Sprintf("%v: %#v", r.response.CTX.ID, r))

	r.response.Status = 400
	r.response.SendJSON(nil)

	// endregion: closing

}
