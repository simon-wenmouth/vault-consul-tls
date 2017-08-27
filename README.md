# Mutual TLS - Vault and Consul

The purpose of this repository is to demonstrate what seems to be
a problem with mutual TLS communication between Vault and Consul.

In particular, Vault is not responding with its certificate upon
receipt of the Consul servers "client certificate request".

## Steps to Reproduce

You create the Docker images with the following command.

```bash
./docker-compose.sh build
```

Once the images are built you start the various containers by running
the following command.

```bash
./docker-compose.sh up
```

Upon completion, you can then inspect the Vault logs demonstrating
a communications error between itself and Consul.

```bash
docker logs tls_consul-client_1
```

The Vault startup logs are as follows.

```
==> Vault server configuration:

                     Cgo: disabled
         Cluster Address: https://172.19.0.12:8201
              Listener 1: tcp (addr: "0.0.0.0:8200", cluster address: "172.19.0.12:8201", tls: "enabled")
               Log Level: trace
                   Mlock: supported: true, enabled: false
        Redirect Address: https://172.19.0.12:8200
                 Storage: consul (HA available)
                 Version: Vault v0.8.1
             Version Sha: 8d76a41854608c547a233f2e6292ae5355154695

==> Vault server started! Log data will stream in below:

2017/08/27 05:19:20.319318 [DEBUG] physical/consul: config path set: path=vault/
2017/08/27 05:19:20.319491 [DEBUG] physical/consul: config disable_registration set: disable_registration=false
2017/08/27 05:19:20.319503 [DEBUG] physical/consul: config service set: service=vault
2017/08/27 05:19:20.319507 [DEBUG] physical/consul: config service_tags set: service_tags=
2017/08/27 05:19:20.319511 [DEBUG] physical/consul: config check_timeout set: check_timeout=5s
2017/08/27 05:19:20.319530 [DEBUG] physical/consul: config address set: address=consul-client.dc.consul:8500
2017/08/27 05:19:20.319537 [DEBUG] physical/consul: config scheme set: scheme=https
2017/08/27 05:19:20.319539 [DEBUG] physical/consul: config token set
2017/08/27 05:19:20.321205 [DEBUG] physical/consul: configured TLS
2017/08/27 05:19:20.321271 [DEBUG] physical/consul: max_parallel set: max_parallel=128
2017/08/27 05:19:20.321323 [TRACE] physical/cache: creating LRU cache: size=32000
2017/08/27 05:19:20.324530 [TRACE] cluster listener addresses synthesized: cluster_addresses=[172.19.0.12:8201]
2017/08/27 05:19:20.333866 [WARN ] physical/consul: reconcile unable to talk with Consul backend: error=service registration failed: Put https://consul-client.dc.consul:8500/v1/agent/service/register: remote error: tls: bad certificate
```

### Verification of the x509 Certificates

The containers have the directories in `etc` mounted to their configuration
directories.  Once the containers have started you'll have the various x509
certificates on the host machine for testing purposes.

In a new terminal, run the following command to start a TLS server process
using the `consul-client` certificates.

```bash
cd ./etc/consul-client/keys
openssl s_server -CAfile agent.ca.pem -cert agent.cert.pem -key agent.key.pem -Verify 1 -www
```

In another terminal, you can verify that the Vault certificates are valid
by running the following command.

```bash
cd ./etc/vault/keys
openssl s_client -CAfile server.ca.pem -cert server.cert.pem -key server.key.pem -verify 1 -connect localhost:4433
```

The server transcript is as follows.

```
$> openssl s_server -CAfile agent.ca.pem -cert agent.cert.pem -key agent.key.pem -Verify 1 -www
verify depth is 1, must return a certificate
Using default temp DH parameters
Using default temp ECDH parameters
ACCEPT
depth=1 /CN=ca.dc.consul
verify return:1
depth=0 /CN=consul-client.dc.consul
verify return:1
ACCEPT
^C
```

The client transcript is as follows.

```
$ openssl s_client -CAfile server.ca.pem -cert server.cert.pem -key server.key.pem -verify 1 -connect localhost:4433
verify depth is 1
CONNECTED(00000003)
depth=1 /CN=ca.dc.consul
verify return:1
depth=0 /CN=consul-client.dc.consul
verify return:1
---
Certificate chain
 0 s:/CN=consul-client.dc.consul
   i:/CN=ca.dc.consul
 1 s:/CN=ca.dc.consul
   i:/CN=ca.dc.consul
---
Server certificate
-----BEGIN CERTIFICATE-----
 ... snip ...
-----END CERTIFICATE-----
subject=/CN=consul-client.dc.consul
issuer=/CN=ca.dc.consul
---
Acceptable client certificate CA names
/CN=ca.dc.consul
---
SSL handshake has read 2314 bytes and written 2250 bytes
---
New, TLSv1/SSLv3, Cipher is DHE-RSA-AES256-SHA
Server public key is 2048 bit
Secure Renegotiation IS supported
Compression: NONE
Expansion: NONE
SSL-Session:
    Protocol  : TLSv1
    Cipher    : DHE-RSA-AES256-SHA
    Session-ID: 85C068CD9B00E6478E507126AC5B036D0F195FD727F68ED82FF9A32B27208558
    Session-ID-ctx: 
    Master-Key: 1AA57ADBACF509226672AFD78241AAA9C1468AD2B67642C307142181EA2E54B217C8C07441C43CE4C0D576564C78852E
    Key-Arg   : None
    Start Time: 1503886642
    Timeout   : 300 (sec)
    Verify return code: 0 (ok)
---
^C
```

### Empty Response to the Client Certificate Request

To log the TLS handshake between the `vault` container and the
`consul-client` container, we change the `command` of the
latter in the `docker-compose.yml` from this (line 57):

```yaml
command: consul agent -data-dir=/opt/consul/data -config-dir=/opt/consul/config
```

to this:

```yaml
command: openssl s_server -CAfile /opt/consul/config/keys/agent.ca.pem -cert /opt/consul/config/keys/agent.cert.pem -key /opt/consul/config/keys/agent.key.pem -Verify 1 -msg -state -www -accept 8500
healthcheck:
  test: /usr/bin/true
```

To inspect the TLS handshake run the following commands.

```bash
./docker-compose.sh down
./docker-compose.sh up
docker logs tls_consul-client_1
```

The `openssl s_server` transcript is as follows.

```
+ exec openssl s_server -CAfile /opt/consul/config/keys/agent.ca.pem -cert /opt/consul/config/keys/agent.cert.pem -key /opt/consul/config/keys/agent.key.pem -Verify 1 -msg -state -www -accept 8500
verify depth is 1, must return a certificate
Using default temp DH parameters
Using default temp ECDH parameters
ACCEPT
SSL_accept:before/accept initialization
SSL_accept:SSLv3 read client hello A
<<< TLS 1.2 Handshake [length 00bb], ClientHello
    01 00 00 b7 03 03 a4 39 78 52 a6 17 00 1d cb 06
    ... snip ...
    74 74 70 2f 31 2e 31 00 12 00 00
>>> TLS 1.2 Handshake [length 0059], ServerHello
    02 00 00 55 03 03 59 a3 84 a4 d5 d2 47 a9 10 99
    ... snip ...
    00 00 0b 00 04 03 00 01 02
SSL_accept:SSLv3 write server hello A
>>> TLS 1.2 Handshake [length 06b2], Certificate
    0b 00 06 ae 00 06 ab 00 03 79 30 82 03 75 30 82
    ... snip ...
    a9 7e 34 5c 97 a9 d5 6d da 64 78 4b 7d 3e d9 8c
SSL_accept:SSLv3 write certificate A
    bd 14 21 71 09 09 88 4f 5b 5d 81 50 cf 72 f7 e4
    ... snip ...
    1c 5e ca 18 c8 b4 67 e4 64 05 28 25 15 e0 f0 ff
    49 1a
>>> TLS 1.2 Handshake [length 014d], ServerKeyExchange
    0c 00 01 49 03 00 17 41 04 51 e5 98 12 cf 17 09
    ... snip ...
    d2 d5 cf cc be fa 12 92 77 f0 cc 45 17
>>> TLS 1.2 Handshake [length 0049], CertificateRequest
    0d 00 00 41 03 01 02 40 00 1e 06 01 06 02 06 03
    05 01 05 02 05 03 04 01 04 02 04 03 03 01 03 02
    03 03 02 01 02 02 02 03 00 1b 00 19 30 17 31 15
    30 13 06 03 55 04 03 13 0c 63 61 2e 64 63 2e 63
    6f 6e 73 75 6c 0e 00 00 00
SSL_accept:SSLv3 write key exchange A
SSL_accept:SSLv3 write certificate request A
SSL_accept:SSLv3 flush data
<<< TLS 1.2 Handshake [length 0007], Certificate
    0b 00 00 03 00 00 00
>>> TLS 1.2 Alert [length 0002], fatal handshake_failure
    02 28
SSL3 alert write:fatal:handshake failure
SSL_accept:error in SSLv3 read client certificate B
SSL_accept:error in SSLv3 read client certificate B
140541868337056:error:140890C7:SSL routines:SSL3_GET_CLIENT_CERTIFICATE:peer did not return a certificate:s3_srvr.c:3321:
ACCEPT
```

### Disabling Mutual TLS

If we update `etc/consul-server/02-ssl.json` and `etc/consul-client/02-ssl.json`
replacing: 

```json
{
  "verify_incoming": true,
  "verify_outgoing": true,
  "ca_file": "/opt/consul/config/keys/agent.ca.pem",
  "cert_file": "/opt/consul/config/keys/agent.cert.pem",
  "key_file": "/opt/consul/config/keys/agent.key.pem"
}
```

with:

```json
{
  "verify_incoming_rpc": true,
  "verify_incoming_https": false,
  "verify_outgoing": true,
  "ca_file": "/opt/consul/config/keys/agent.ca.pem",
  "cert_file": "/opt/consul/config/keys/agent.cert.pem",
  "key_file": "/opt/consul/config/keys/agent.key.pem"
}
```

then Vault is able to successfully use Consul as its storage mechanism. 

## Container Inventory

### ca

The container `ca` is the root certificate authority for the project
and uses the file storage backend.

The entrypoint for the container (`ca-entrypoint.sh`) creates a bootstrap
SSL certificate before starting Vault (such that TLS is enabled).

Once the Vault process is running we run the initialize / unseal commands
and proceed to configure the container.  We generate a new CA certificate
and issue a leaf certificate to be used by Vault itself.  We then reload
the configuration by running `kill -SIGHUP` (see: `ca-initialize.sh`).

Once the configuration is reloaded we enable the `approle` backend and
configure two roles.

- `consul`: tokens may request a private key and certificate.
- `vault`: tokens may request a private key and certificate and request
  the signing of an intermediate ca (csr).

The ca container is intended to allow us to operate a Consul cluster with
TLS encryption enabled (`verify_incoming=true` and `verify_outgoing=true`)
as the storage backend to a Vault cluster (also having TLS enabled) in the
absence of pre-existing PKI infrastructure.

### consul-server

The container `consul-server` is a Consul agent running in server mode
whose purpose is to provide the the storage backend for Vault. 

### consul-client

The container `consul-client` is a "local" Consul agent running in client
mode through which Vault communicates with the Consul server process. 

### vault

The container `vault` is an intermediate ca which uses the `consul-server`
service as a storage backend (via `consul-client`).
