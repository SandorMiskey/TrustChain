package fabric

import (
	"github.com/hyperledger/fabric-gateway/pkg/client"
)

func Invoke(c *Client, r *Request) (*Response, *ResponseError) {

	// region: proposal

	network := c.Gateway.GetNetwork(r.Channel)
	contract := network.GetContract(r.Chaincode)
	proposal, err := contract.NewProposal(r.Function, client.WithArguments(r.Args...))
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

func (c *Client) Invoke(r *Request) (*Response, *ResponseError) {
	return Invoke(c, r)
}

func (r *Request) Invoke(c *Client) (*Response, *ResponseError) {
	return Invoke(c, r)
}
