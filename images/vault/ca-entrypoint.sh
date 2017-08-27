#!/usr/bin/env bash

set -e
set -u
set -x

VAULT_HOME=${VAULT_HOME:-/opt/vault}
VAULT_CERT_FILE="${VAULT_HOME}/config/keys/server.cert.pem"
VAULT_KEY_FILE="${VAULT_HOME}/config/keys/server.key.pem"
VAULT_CA_FILE="${VAULT_HOME}/config/keys/server.ca.pem"

rm -f "${VAULT_CERT_FILE}" "${VAULT_CA_FILE}" "${VAULT_KEY_FILE}"

bootstrap_dir="${VAULT_HOME}/config/keys/bootstrap"
host=$(hostname -s)
domain=$(hostname -d)
ca_subject="/C=US/ST=IL/L=Chicago/O=GitHub/OU=Issues/CN=ca"
cert_subject="/C=US/ST=IL/L=Chicago/O=GitHub/OU=Issues/CN=${host}"

cp "${VAULT_HOME}/bin/openssl.cnf" "${bootstrap_dir}"

cd "${bootstrap_dir}"

rm -Rf certs csr crl newcerts private index.txt index.txt.attr index.txt.old serial serial.old
mkdir certs csr crl newcerts private
touch index.txt
echo 1000 > serial

openssl genrsa -out private/ca.key.pem 4096
openssl req -config openssl.cnf -key private/ca.key.pem -subj "${ca_subject}" -new -x509 -days 7300 -sha256 -extensions v3_ca -out certs/ca.cert.pem
openssl genrsa -out "private/${host}.${domain}.key.pem" 2048
openssl req -config openssl.cnf -key "private/${host}.${domain}.key.pem" -subj "${cert_subject}" -new -sha256 -out "csr/${host}.${domain}.csr.pem"
openssl ca -config openssl.cnf -batch -extensions server_cert -days 375 -notext -md sha256 -in "csr/${host}.${domain}.csr.pem" -out "certs/${host}.${domain}.cert.pem"

cp "${bootstrap_dir}/certs/${host}.${domain}.cert.pem" "${VAULT_CERT_FILE}"
cp "${bootstrap_dir}/private/${host}.${domain}.key.pem" "${VAULT_KEY_FILE}"
cp "${bootstrap_dir}/certs/ca.cert.pem" "${VAULT_CA_FILE}"

chmod go-wx "${VAULT_CERT_FILE}" "${VAULT_CA_FILE}"
chmod go-rwx "${VAULT_KEY_FILE}"

exec $@
