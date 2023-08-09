# todo

* worker3
  * docker pull
  * move payload
* GetBlockByTxID
  * get by tx_id, block# via qscc [https://stackoverflow.com/questions/67263579/retrieve-block-number-and-transaction-id-from-query-to-hyperledger-fabric]
* orderer restart? stress test
* put p2s and p3s back in tcChaincodeInit.sh

* SASC leftover (doc/legacy_to_port)
* swagger
* common uid/gid on managers and workers on-the-fly
* more dependency check
  * glusterd
  * mount.glusterfs
  * check on remote managers and workers
* tls ca checklist [https://hyperledger-fabric-ca.readthedocs.io/en/latest/deployguide/ca-config.html]
* operations:
  * (tls)ca "Operation Server Listening on 127.0.0.1:9443"
  * set mutual tls authentication
  * operations org ca?
  * operations certs in localMSP dirs
* CSR in fabric-ca-server config (and in -client config?)
* what if orderer1-admin not admin @tls-ca
* renames?
  * Cn -> CAn
  * Dn -> DBn
  * Pn -> PEERn
  * On -> ORDERERn
  * Sn -> SERVICEn
