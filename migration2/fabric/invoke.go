package fabric

import (
	"github.com/hyperledger/fabric-gateway/pkg/client"
)

func Invoke(r *Request) (*Response, *ResponseError) {

	// region: proposal

	proposal, err := r.Contract.NewProposal(r.Function, client.WithArguments(r.Args...))
	if err != nil {
		return nil, Error(err)
	}

	// endregion: proposal
	// region: endorse

	transaction, err := proposal.Endorse()
	if err != nil {
		return nil, Error(err)
	}

	// endregion: endorse
	// region: commit

	commit, err := transaction.Submit()
	if err != nil {
		return nil, Error(err)
	}

	// endregion: commit
	// region: response

	response := &Response{
		Txid:   commit.TransactionID(),
		Result: transaction.Result(),
	}

	return response, nil

	// endregion: response

}

func (r *Request) Invoke() (*Response, *ResponseError) {
	return Invoke(r)
}
