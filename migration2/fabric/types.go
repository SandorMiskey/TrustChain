package fabric

import (
	"github.com/hyperledger/fabric-gateway/pkg/client"
	"google.golang.org/grpc"
)

type Client struct {
	CertPath     string `json:"CertPath"`
	GatewayPeer  string `json:"GatewayPeer"`
	KeyPath      string `json:"KeyPath"`
	MSPID        string `json:"MSPID"`
	PeerEndpoint string `json:"PeerEndpoint"`
	TLSCertPath  string `json:"TLSCertPath"`

	Connection *grpc.ClientConn `json:"-"`
	Gateway    *client.Gateway  `json:"-"`
	// Lator   *Lator          `json:"-"`
}

// type LatorExe func([]byte, string) ([]byte, error)

// type Lator struct {
// 	Bind   string           `json:"bind"`
// 	Port   int              `json:"port"`
// 	Which  string           `json:"which"`
// 	Exe    LatorExe         `json:"-"`
// 	cmd    *exec.Cmd        `json:"-"`
// 	client *fasthttp.Client `json:"-"`
// }

// type Request struct {
// 	Chaincode string   `json:"chaincode"`
// 	Channel   string   `json:"channel"`
// 	Function  string   `json:"function"`
// 	Args      []string `json:"args"`
// }

// type ResponseError struct {
// 	Details []map[string]string `json:"details"`
// 	Err     error               `json:"-"`
// 	Message string              `json:"message"`
// 	Status  codes.Code          `json:"status"`
// 	Type    string              `json:"type"`
// 	Txid    string              `json:"tx_id"`
// }

// type Response struct {
// 	Txid   string `json:"tx_id"`
// 	Result []byte `json:"result"`
// 	// Error  Error       `json:"error"`
// }
