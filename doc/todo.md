# todo

## now

* prerequisites
  * checkout TrustChain
  * fabric binaries
  * set .env
    * m1
      * tlsca
      * registry
      * orderer ca
      * orderer 1
      * endorsers ca
      * endorsers peer1 + db
    * m2
      * orderer 2
      * supernodes ca
      * supernodes peer1 + db
    * m3
      * orderer 3
      * masternodes ca
      * masternodes peer1 + db
    * w1
      * masternodes peer2 + db
      * masternodes peer3 + db
    * w2
      * supernodes peer2 + db
      * supernodes peer3 + db
* backup
  * GlusterFS backup volume
    * create volume on w1+w2
    * mount volume on m1 under m1:/srv/backup
  * rsync
    * /srv/TrustChain -> /srv/Backup
    * 3x /mnt/GlusterData/WAL -> /srv/Backup
* CSV processor
* stress test

## later

* tcGlusterServers.sh
  * auth.allow
  * fstab backupvolfile-server
  * mkdir WAL
* TC_ORDERER1_(O1|O2|O3)_WAL -> GlusterFS
* SASC leftover (doc/legacy_to_port), backport github/common.sh
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
