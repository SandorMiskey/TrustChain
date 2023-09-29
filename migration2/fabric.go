package main

import (
	"github.com/SandorMiskey/TEx-kit/cfg"
	"github.com/SandorMiskey/TrustChain/migration2/fabric"
	"github.com/hyperledger/fabric-gateway/pkg/client"
)

func fabricClient(c *cfg.Config) *fabric.Client {
	client := fabric.Client{
		CertPath:     c.Entries[OPT_FAB_CERT].Value.(string),
		GatewayPeer:  c.Entries[OPT_FAB_GATEWAY].Value.(string),
		KeyPath:      c.Entries[OPT_FAB_KEYSTORE].Value.(string),
		MSPID:        c.Entries[OPT_FAB_MSPID].Value.(string),
		PeerEndpoint: c.Entries[OPT_FAB_ENDPOINT].Value.(string),
		TLSCertPath:  c.Entries[OPT_FAB_TLSCERT].Value.(string),
	}
	err := client.Init()
	if err != nil {
		helperPanic(err.Error())
	}

	Lout(LOG_DEBUG, "fabric client instance", client)
	return &client
}

// func fabricContract(c *cfg.Config, client *fabric.Client) *client.Contract {
// 	network := fabricNetwork(c, client)
// 	contract := network.GetContract(c.Entries[OPT_FAB_CC].Value.(string))
// 	return contract
// }

func fabricNetwork(c *cfg.Config, client *fabric.Client) *client.Network {
	return client.Gateway.GetNetwork(c.Entries[OPT_FAB_CHANNEL].Value.(string))
}
