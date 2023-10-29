# todo

## now

* gluster auth.allow (tcGlusterServers.sh)

## next

* backup
* delete legacy
  * Contabo
  * AWS (all availability zones)
  * Vultr
  * OVH

## backlog

* Rawapi:
  * rewrite: use migration/fabric
  * Lator.Exe on-the-fly
  * Lator.Exe -> raw binary
  * batch process via file upload (MaxRequestBodySize: math.MaxInt32)
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
* operations:
  * (tls)ca "Operation Server Listening on 127.0.0.1:9443"
  * set mutual tls authentication
  * operations org ca?
  * operations certs in localMSP dirs
