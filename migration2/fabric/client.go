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
	"google.golang.org/grpc/credentials"
)

// endregion: packages
// region: globals

var (
	EvaluateTimeout     time.Duration = 5 * time.Second
	EndorseTimeout      time.Duration = 15 * time.Second
	SubmitTimeout       time.Duration = 5 * time.Second
	CommitStatusTimeout time.Duration = 1 * time.Minute
)

// endregion: globals
// region: init client

func (c *Client) Init() (err error) {

	c.connection, err = c.newGrpcConnection()
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

	c.Gateway, err = client.Connect(
		id,
		client.WithSign(sign),
		client.WithClientConnection(c.connection),
		client.WithEvaluateTimeout(EvaluateTimeout),
		client.WithEndorseTimeout(EndorseTimeout),
		client.WithSubmitTimeout(SubmitTimeout),
		client.WithCommitStatusTimeout(CommitStatusTimeout),
	)
	if err != nil {
		return err
	}

	return nil
}

// endregion: init client
// region: close

func (c *Client) Close() {
	defer c.connection.Close()
	defer c.Gateway.Close()
}

// endregion: close
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
