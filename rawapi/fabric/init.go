package fabric

import (
	"crypto/x509"
	"errors"
	"fmt"
	"path"
	"time"

	"io/ioutil"

	"github.com/SandorMiskey/TEx-kit/log"
	"github.com/SandorMiskey/TrustChain/rawapi/http"
	"github.com/hyperledger/fabric-gateway/pkg/client"
	"github.com/hyperledger/fabric-gateway/pkg/identity"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"
)

type OrgSetup struct {
	OrgName      string          `json:"OrgName"`
	MSPID        string          `json:"MSPID"`
	CertPath     string          `json:"CertPath"`
	KeyPath      string          `json:"KeyPath"`
	TLSCertPath  string          `json:"TLSCertPath"`
	PeerEndpoint string          `json:"PeerEndpoint"`
	GatewayPeer  string          `json:"GatewayPeer"`
	gateway      *client.Gateway `json:"-"`
	Logger       *log.Logger     `json:"-"`
}

// Initialize the setup for the organization.
func (setup *OrgSetup) Init() (*OrgSetup, error) {

	// region: check for logger

	if setup.Logger == nil {
		return setup, errors.New("OrgSetup.Init() needs a logger")
	}
	logger := setup.Logger.Out

	// endregion: logger

	logger(log.LOG_INFO, fmt.Sprintf("initializing connection for %s...", setup.OrgName))

	clientConnection, err := setup.newGrpcConnection()
	if err != nil {
		return setup, err
	}
	id, err := setup.newIdentity()
	if err != nil {
		return setup, err
	}
	sign, err := setup.newSign()
	if err != nil {
		return setup, err
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
		return setup, err
	}
	setup.gateway = gateway
	logger(log.LOG_INFO, "initialization complete")
	return setup, nil
}

func (setup *OrgSetup) validate(response *http.Response) error {
	if setup.Logger == nil || setup.gateway == nil {
		return errors.New("fabric.OrgSetup.Invoke() needs a logger and a gateway, fabric.OrgSetup.Init() first")

		// response.Status = 500
		// response.Message = "fabric.OrgSetup.Invoke() needs a logger and a gateway, fabric.OrgSetup.Init() first"
		// response.Send(nil)
		// return errors.New(response.Message.(string))
	}
	return nil
}

// newGrpcConnection creates a gRPC connection to the Gateway server.
func (setup *OrgSetup) newGrpcConnection() (*grpc.ClientConn, error) {
	certificate, err := loadCertificate(setup.TLSCertPath)
	if err != nil {
		return nil, err
	}

	certPool := x509.NewCertPool()
	certPool.AddCert(certificate)
	transportCredentials := credentials.NewClientTLSFromCert(certPool, setup.GatewayPeer)

	connection, err := grpc.Dial(setup.PeerEndpoint, grpc.WithTransportCredentials(transportCredentials))
	if err != nil {
		return nil, fmt.Errorf("failed to create gRPC connection: %w", err)
	}

	return connection, nil
}

// newIdentity creates a client identity for this Gateway connection using an X.509 certificate.
func (setup *OrgSetup) newIdentity() (*identity.X509Identity, error) {
	certificate, err := loadCertificate(setup.CertPath)
	if err != nil {
		return nil, err
	}

	id, err := identity.NewX509Identity(setup.MSPID, certificate)
	if err != nil {
		return nil, err
	}

	return id, nil
}

// newSign creates a function that generates a digital signature from a message digest using a private key.
func (setup *OrgSetup) newSign() (identity.Sign, error) {
	files, err := ioutil.ReadDir(setup.KeyPath)
	if err != nil {
		return nil, fmt.Errorf("failed to read private key directory: %w", err)
	}
	privateKeyPEM, err := ioutil.ReadFile(path.Join(setup.KeyPath, files[0].Name()))

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
