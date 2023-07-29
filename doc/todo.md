# todo

* rawapi static: dynamic host and ports (service name everywhere)
* swarm init/join/... -> tcSwarm.sh
* remote peers
  * docker swarm manager redundancy?
    * ssh config
      * manager -> manager1
      * new node -> manager2
      * worker2 -> manager3
      * worker1 still worker1
      * worker4 -> worker2
      * worker3 still worker3
    * aws console
      * todo
        * instance list: name, tags
        * elastic ip list: name, tags
        * security group
      * hosts:
        * manager -> manager1
        * new node -> manager2
        * worker2 -> manager3
        * worker1 still worker1
        * worker4 -> worker2
        * worker3 still worker3
    * hostname
      * manager -> manager1
      * new node -> manager2
      * worker2 -> manager3
      * worker1 still worker1
      * worker4 -> worker2
      * worker3 still worker3
    * /etc/hosts
      * manager -> manager1
      * new node -> manager2
      * worker2 -> manager3
      * worker1 still worker1
      * worker4 -> worker2
      * worker3 still worker3
    * tcConf.sh, tcGenesis.sh SwarmLeave() and SwarmJoin()
      * manager -> manager1
      * new node -> manager2
      * worker2 -> manager3
      * worker1 still worker1
      * worker4 -> worker2
      * worker3 still worker3
    * doc/ports.md
  * GlusterFS?
    * manager*, remove additional ebs from worker1
    * recreate cluster
      * format xfs: mkfs.xfs -i size=512 /dev/device
    * authentication
      * [https://access.redhat.com/documentation/en-us/red_hat_gluster_storage/3.4/html/administration_guide/chap-accessing_data_-_setting_up_clients#Mounting_Volumes_Using_Native_Client]
      * for manager
      * subdir for workers (see 6.1.3.4. Manually Mounting Sub-directories Using Native Client)
    * mount redundancy (backupvolfile-server=server-name)
    * permissions?
  * dependencies
    * test on workers
    * docker
    * check if mount point with data is available
  * move workers
    * managers pre-set by hand
    * workers
      * check/create mount point
      * mount work dir
* put p2s and p3s back in tcChaincodeInit.sh
* put mgmt and metrics (and basic?) back in tcGenesis.sh
* orderer restart? stress test
* move HTTPS cert and key from tcGwInit.sh to templates/swarm/20_{TC_ORG1_STACK}.yaml

* swagger
* get by tx_id, block# via qscc [https://stackoverflow.com/questions/67263579/retrieve-block-number-and-transaction-id-from-query-to-hyperledger-fabric]
* SASC leftover (doc/legacy_to_port)
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
