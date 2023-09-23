package fabric

func Query(c *Client, r *Request) (*Response, *ResponseError) {

	// region: fetch

	network := c.Gateway.GetNetwork(r.Channel)
	contract := network.GetContract(r.Chaincode)

	result, err := contract.EvaluateTransaction(r.Function, r.Args...)
	if err != nil {
		return nil, Error(err)
	}

	// endregion: fetch
	// region: response

	response := &Response{
		Result: result,
	}
	return response, nil

	// endregion: response

}

func (c *Client) Query(r *Request) (*Response, *ResponseError) {
	return Invoke(c, r)
}

func (r *Request) Query(c *Client) (*Response, *ResponseError) {
	return Invoke(c, r)
}
