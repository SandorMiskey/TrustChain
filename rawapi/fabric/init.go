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
	CertPath     string      `json:"CertPath"`
	GatewayPeer  string      `json:"GatewayPeer"`
	KeyPath      string      `json:"KeyPath"`
	Lator        *Lator      `json:"Lator"`
	Logger       *log.Logger `json:"-"`
	MSPID        string      `json:"MSPID"`
	OrgName      string      `json:"OrgName"`
	PeerEndpoint string      `json:"PeerEndpoint"`
	TLSCertPath  string      `json:"TLSCertPath"`

	gateway *client.Gateway `json:"-"`
}

// Initialize the setup for the organization.
func (s *OrgSetup) Init() (*OrgSetup, error) {

	// region: logger

	if s.Logger == nil {
		return s, errors.New("OrgSetup.Init() needs a logger")
	}
	logger := s.Logger.Out
	logger(log.LOG_INFO, fmt.Sprintf("initializing connection for %s...", s.OrgName))

	// endregion: logger
	// region: configtxlator

	if s.Lator.Exe == nil {
		_, err := s.Lator.Init()
		if err != nil {
			logger(log.LOG_EMERG, "error initializing configtxlator instance", err, s.Lator)
			panic(err)
		}
		logger(log.LOG_DEBUG, "configtxlator instance", s.Lator)

	}

	// endregion: configtxlator
	// region: connection and gateway

	clientConnection, err := s.newGrpcConnection()
	if err != nil {
		return s, err
	}
	id, err := s.newIdentity()
	if err != nil {
		return s, err
	}
	sign, err := s.newSign()
	if err != nil {
		return s, err
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
		return s, err
	}
	s.gateway = gateway

	// endregion: connection and gateway
	// region: out

	logger(log.LOG_INFO, "initialization complete")
	return s, nil

	// endregion: out

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
