package fabric

func Query(r *Request) (*Response, *ResponseError) {

	// region: fetch

	result, err := r.Contract.EvaluateTransaction(r.Function, r.Args...)
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

func (r *Request) Query() (*Response, *ResponseError) {
	return Invoke(r)
}
