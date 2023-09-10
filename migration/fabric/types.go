package fabric

import (
	"github.com/hyperledger/fabric-gateway/pkg/client"
	"github.com/valyala/fasthttp"
	"google.golang.org/grpc/codes"
)

type Client struct {
	CertPath     string `json:"CertPath"`
	GatewayPeer  string `json:"GatewayPeer"`
	KeyPath      string `json:"KeyPath"`
	Lator        *Lator `json:"-"`
	MSPID        string `json:"MSPID"`
	PeerEndpoint string `json:"PeerEndpoint"`
	TLSCertPath  string `json:"TLSCertPath"`

	gateway *client.Gateway `json:"-"`
}

type LatorExe func([]byte, string) ([]byte, error)

type Lator struct {
	Bind   string           `json:"bind"`
	Port   int              `json:"port"`
	Which  string           `json:"which"`
	Exe    LatorExe         `json:"-"`
	client *fasthttp.Client `json:"-"`
}

type Request struct {
	Chaincode string   `json:"chaincode"`
	Channel   string   `json:"channel"`
	Function  string   `json:"function"`
	Args      []string `json:"args"`
}

type ResponseError struct {
	Details []map[string]string `json:"details"`
	Err     error               `json:"-"`
	Message string              `json:"message"`
	Status  codes.Code          `json:"status"`
	Type    string              `json:"type"`
	Txid    string              `json:"tx_id"`
}

type Response struct {
	Txid   string `json:"tx_id"`
	Result []byte `json:"result"`
	// Error  Error       `json:"error"`
}
