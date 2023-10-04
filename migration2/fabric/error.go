package fabric

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"

	"github.com/hyperledger/fabric-gateway/pkg/client"
	"github.com/hyperledger/fabric-protos-go-apiv2/gateway"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

func Error(err error) *ResponseError {

	// region: new response

	r := &ResponseError{
		Err:  err,
		Type: fmt.Sprintf("%T", err),
	}

	// endregion: msg
	// region: error types

	switch err := err.(type) {
	case *client.EndorseError:
		r.Txid = err.TransactionID
		r.Status = status.Code(err)
		r.Message = fmt.Sprintf("endorse error for transaction %s with gRPC status %v: %s", r.Txid, r.Status, err)
	case *client.SubmitError:
		r.Txid = err.TransactionID
		r.Status = status.Code(err)
		r.Message = fmt.Sprintf("submit error for transaction %s with gRPC status %v: %s", r.Txid, r.Status, err)
	case *client.CommitStatusError:
		r.Txid = err.TransactionID
		if errors.Is(err, context.DeadlineExceeded) {
			r.Status = codes.Code(err.GRPCStatus().Code()) //??
			r.Message = fmt.Sprintf("timeout waiting for transaction %s with gRPC status %v: %s", r.Txid, r.Status, err)
		} else {
			r.Status = status.Code(err)
			r.Message = fmt.Sprintf("error obtaining commit status for transaction %s commit status %s: %s", r.Txid, r.Status, err)
		}
	case *client.CommitError:
		r.Txid = err.TransactionID
		r.Status = codes.Code(err.Code) // ???
		r.Message = fmt.Sprintf("transaction %s failed to commit with status %d: %s", r.Txid, r.Status, err)
	default:
		r.Status = status.Code(err)
		r.Message = fmt.Sprintf("unexpected error type %T: %s", err, err)
	}

	// endregion: error types
	// region: error details

	status := status.Convert(err)
	details := status.Details()
	r.Details = make([]map[string]string, 0)
	if len(details) > 0 {
		for _, detail := range details {
			switch detail := detail.(type) {
			case *gateway.ErrorDetail:
				r.Details = append(r.Details, map[string]string{"address": detail.Address, "mspId": detail.MspId, "message": detail.Message})
			}
		}
	}

	// endregion: error details

	return r

}

func (r *ResponseError) Error() string {
	raw, err := json.Marshal(r)
	if err != nil {
		return fmt.Sprintf("%#v", r)
	}
	return string(raw)
}
