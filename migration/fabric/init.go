// region: packages

package fabric

import (
	"crypto/x509"
	"fmt"
	"io/ioutil"
	"path"
	"time"

	"github.com/hyperledger/fabric-gateway/pkg/client"
	"github.com/hyperledger/fabric-gateway/pkg/identity"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/credentials"
)

// endregion: packages
// region: types

type Client struct {
	CertPath     string `json:"CertPath"`
	GatewayPeer  string `json:"GatewayPeer"`
	KeyPath      string `json:"KeyPath"`
	MSPID        string `json:"MSPID"`
	PeerEndpoint string `json:"PeerEndpoint"`
	TLSCertPath  string `json:"TLSCertPath"`

	gateway *client.Gateway `json:"-"`
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

// endregion: types
// region: init client

func Init(c *Client) error {

	clientConnection, err := c.newGrpcConnection()
	if err != nil {
		return err
	}
	id, err := c.newIdentity()
	if err != nil {
		return err
	}
	sign, err := c.newSign()
	if err != nil {
		return err
	}

	gateway, err := client.Connect(
		id,
		client.WithSign(sign),
		client.WithClientConnection(clientConnection),
		client.WithEvaluateTimeout(5*time.Second),
		client.WithEndorseTimeout(15*time.Second),
		client.WithSubmitTimeout(5*time.Second),
		client.WithCommitStatusTimeout(1*time.Minute),
	)
	if err != nil {
		return err
	}

	c.gateway = gateway
	return nil
}

func (c *Client) Init() error {
	err := Init(c)
	return err
}

// endregion: init client
// region: helpers

// newGrpcConnection creates a gRPC connection to the Gateway server.
func (c *Client) newGrpcConnection() (*grpc.ClientConn, error) {
	certificate, err := loadCertificate(c.TLSCertPath)
	if err != nil {
		return nil, err
	}

	certPool := x509.NewCertPool()
	certPool.AddCert(certificate)
	transportCredentials := credentials.NewClientTLSFromCert(certPool, c.GatewayPeer)

	connection, err := grpc.Dial(c.PeerEndpoint, grpc.WithTransportCredentials(transportCredentials))
	if err != nil {
		return nil, fmt.Errorf("failed to create gRPC connection: %w", err)
	}

	return connection, nil
}

// newIdentity creates a client identity for this Gateway connection using an X.509 certificate.
func (c *Client) newIdentity() (*identity.X509Identity, error) {
	certificate, err := loadCertificate(c.CertPath)
	if err != nil {
		return nil, err
	}

	id, err := identity.NewX509Identity(c.MSPID, certificate)
	if err != nil {
		return nil, err
	}

	return id, nil
}

// newSign creates a function that generates a digital signature from a message digest using a private key.
func (c *Client) newSign() (identity.Sign, error) {
	files, err := ioutil.ReadDir(c.KeyPath)
	if err != nil {
		return nil, fmt.Errorf("failed to read private key directory: %w", err)
	}
	privateKeyPEM, err := ioutil.ReadFile(path.Join(c.KeyPath, files[0].Name()))

	if err != nil {
		return nil, fmt.Errorf("failed to read private key file: %w", err)
	}

	privateKey, err := identity.PrivateKeyFromPEM(privateKeyPEM)
	if err != nil {
		return nil, err
	}

	sign, err := identity.NewPrivateKeySign(privateKey)
	if err != nil {
		return nil, err
	}

	return sign, nil
}

func loadCertificate(filename string) (*x509.Certificate, error) {
	certificatePEM, err := ioutil.ReadFile(filename)
	if err != nil {
		return nil, fmt.Errorf("failed to read certificate file: %w", err)
	}
	return identity.CertificateFromPEM(certificatePEM)
}

// endregion: helpers
