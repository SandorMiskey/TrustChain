# todo

## now

* stress test
* security group for tc2-test, tc2
* site specific config -> .env
* ec2
  * 1x m5a.2xlarge w/160GB root (tc2m1)
  * 2x m5a.xlarge w/80GB root (tc2m2, tc2m3)
  * 2x m5a.large 2w/30GB root (tc2w1, tc2w2)
* ebs
  * 5x 16TB cold hdd
    * 3x gluster for TC2
    * 2x in mirror for backup
* prerequisites
  * trustchain user
  * install:
    * docker
    * gluster
    * yq, jq, go
    * fabric binaries on tc2m1
  * trustchain user groups: docker, sudo
  * sudo no-password
  * .dir
  * authorized_hosts
* balance
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
* rsync backup
  * /srv/TrustChain
  * 3x /mnt/GlusterData/WAL

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
