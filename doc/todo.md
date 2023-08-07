# todo

* private docker registry
* remote peers
  * move payload to managers
    * all initial launch on manager1
    * move service to SERVICE_WORKER
  * GlusterFS?
    * permissions?
    * authentication
      * [https://access.redhat.com/documentation/en-us/red_hat_gluster_storage/3.4/html/administration_guide/chap-accessing_data_-_setting_up_clients#Mounting_Volumes_Using_Native_Client]
      * [https://docs.gluster.org/en/main/Administrator-Guide/Tuning-Volume-Options/] 
      * for manager
      * subdir for workers (see 6.1.3.4. Manually Mounting Sub-directories Using Native Client)
  * dependencies
    * test on workers
    * docker
    * check if mount point with data is available
  * move payload to workers
    * workers
      * check/create mount point
      * mount work dir
  * update docs/hosts_and_ports.md
* orderer restart? stress test
* move HTTPS cert and key from tcGwInit.sh to templates/swarm/20_{TC_ORG1_STACK}.yaml
* put p2s and p3s back in tcChaincodeInit.sh
* put mgmt and metrics (and basic?) back in tcGenesis.sh

* swagger
* common uid/gid on managers and workers on-the-fly
* get by tx_id, block# via qscc [https://stackoverflow.com/questions/67263579/retrieve-block-number-and-transaction-id-from-query-to-hyperledger-fabric]
* SASC leftover (doc/legacy_to_port)
* more dependency check
  * glusterd
  * mount.glusterfs
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
