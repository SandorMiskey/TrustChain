# todo

## now

* supernodes & masternodes GW
* Rawapi:
  * Lator.Exe on-the-fly
  * Lator.Exe -> raw binary
* tcRawapiBatch -> go gateway || sdk implementation
  * gateway: rawapi
  * sdk: fabric-samples
    * asset-transfer-basic/application-go
    * high-throughput/application-go
* tcRawapiBatch -> go gateway implementation over http
  * confirm: common client, req & resp [https://gist.github.com/erikdubbelboer/fe4095419fca55e2c92b3d0432ccd7fc]
  * submit
  * resubmit
* continuous batch process
* rawapi batch process
  * query
  * invoke
  * MaxRequestBodySize: math.MaxInt32
* delete legacy
  * Contabo
  * AWS (all availability zones)
  * Vultr
  * OVH

## later

* tcRawapiBatch.sh reconfirm?
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
