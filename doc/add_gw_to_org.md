# add extra gateway to org

## preparation

1. update tcConf.sh or .env, use $TC_ORG1_GW1_ as a template
2. set $TC_ORG2_GW1_TLS_PW in .env
3. make sure that client1/msp is available on node where the new gateway will run
4. mkdir $TC_ORG2_GW1_DATA
5. create and populate $TC_ORG2_GW1_ASSETS_DIR
6. mkdir $TC_ORG2_GW1_TLSMSP
7. register and enroll with TLSCA (see bellow)
8. update swarm config (docker-compose yaml)
   1. secrets
   2. services
9. update tcGwInit.sh
10. launch

## register with tlsca

```bash

source $TC_PATH_RC
 
export FABRIC_CA_CLIENT_TLS_CERTFILES=${TC_COMMON1_C1_HOME}/ca-cert.pem
export FABRIC_CA_CLIENT_HOME=${TC_COMMON1_C1_DATA}/${TC_COMMON1_C1_ADMIN}

fabric-ca-client register --id.name $TC_ORG2_GW1_TLS_NAME --id.secret $TC_ORG2_GW1_TLS_PW --id.type client -u https://0.0.0.0:${TC_COMMON1_C1_PORT}

export FABRIC_CA_CLIENT_TLS_CERTFILES=$TC_ORG2_GW1_ASSETS_TLSCERT
export FABRIC_CA_CLIENT_MSPDIR=$TC_ORG2_GW1_TLSMSP

fabric-ca-client enroll -u https://${TC_ORG2_GW1_TLS_NAME}:${TC_ORG2_GW1_TLS_PW}@0.0.0.0:${TC_COMMON1_C1_PORT} --enrollment.profile tls --csr.hosts ${TC_ORG2_GW1_FQDN},${TC_ORG2_GW1_NAME},localhost
mv ${TC_ORG2_GW1_TLSMSP}/keystore/* ${TC_ORG2_GW1_TLSMSP}/keystore/key.pem 

```
