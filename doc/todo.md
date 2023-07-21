# todo

* chaincode + api
  * SetLogger
  * static check
  * queries
  * bundle id -> int
  * UpdateBundle
    * validate data_base64 vs data_hash
  * CreateBundle
    * validate data_base64 vs data_hash
  * create, update result  -> bundle.json
  * query tx_id -> null
* copy api and chaincode -> templates
* update postman collection -> doc
* remote peers
* put p2s and p3s back in tcChaincodeInit.sh
* put mgmt and metrics (and basic?) back in tcGenesis.sh
* orderer restart? stress test
* The enrollment certificate will expire on 2024-07-19 21:43:00

* swagger
* get by tx_id, block# [https://stackoverflow.com/questions/67263579/retrieve-block-number-and-transaction-id-from-query-to-hyperledger-fabric]
* SASC leftover (doc/legacy_to_port)
* tls ca checklist [https://hyperledger-fabric-ca.readthedocs.io/en/latest/deployguide/ca-config.html]
* operations:
  * (tls)ca "Operation Server Listening on 127.0.0.1:9443"
  * set mutual tls authentication
  * operations org ca?
  * operationscerts in localMSP dirs
* CSR in fabric-ca-server config (and in -client config?)
* what if orderer1-admin not admin @tls-ca
* renames?
  * Cn -> CAn
  * Dn -> DBn
  * Pn -> PEERn
  * On -> ORDERERn
  * Sn -> SERVICEn
