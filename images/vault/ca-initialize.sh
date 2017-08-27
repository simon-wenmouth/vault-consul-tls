#!/usr/bin/env bash

set -o pipefail
set -e
set -u
set -x

VAULT_HOME=${VAULT_HOME:-/opt/vault}
VAULT_CERT_FILE="${VAULT_HOME}/config/keys/server.cert.pem"
VAULT_KEY_FILE="${VAULT_HOME}/config/keys/server.key.pem"
VAULT_CA_FILE="${VAULT_HOME}/config/keys/server.ca.pem"

mount_path=pki-ca
role_name=tls-cert
ca_json="${VAULT_HOME}/config/keys/ca.json"
cert_json="${VAULT_HOME}/config/keys/cert.json"

export VAULT_ADDR=https://localhost:8200
export VAULT_CAPATH=${VAULT_CA_FILE}

vault auth "${1}"
vault mount "-path=${mount_path}" pki
vault mount-tune -max-lease-ttl=87600h "${mount_path}"
vault write -format=json "${mount_path}/root/generate/exported" "common_name=$(hostname -f)" ip_sans=127.0.0.1 alt_names=localhost ttl=87600h > "${ca_json}"
vault write "${mount_path}/roles/${role_name}" max_ttl=87600h allow_localhost=true allow_subdomains=true allowed_domains="$(hostname -d)" organisation=Wenmouth ou=Simon
vault write -format=json "${mount_path}/issue/${role_name}" "common_name=$(hostname -f)" ttl=8760h "ip_sans=$(hostname -i),127.0.0.1" alt_names="localhost" > "${cert_json}"

jq -r '.data.certificate' "${cert_json}" >  "${VAULT_CERT_FILE}"
jq -r '.data.issuing_ca'  "${cert_json}" >> "${VAULT_CERT_FILE}"
jq -r '.data.issuing_ca'  "${cert_json}" >  "${VAULT_CA_FILE}"
jq -r '.data.private_key' "${cert_json}" >  "${VAULT_KEY_FILE}"

kill -s SIGHUP 1

export VAULT_ADDR="https://$(hostname -f):8200"

vault auth-enable approle

cat <<EOF > "/tmp/${mount_path}-${role_name}-policy"
path "${mount_path}/issue/${role_name}" {
    policy = "write"
}
EOF

cat <<EOF > "/tmp/${mount_path}-intermediate-ca-policy"
path "${mount_path}/root/sign-intermediate" {
    policy = "write"
}
EOF

vault policy-write "${mount_path}-${role_name}-policy" "/tmp/${mount_path}-${role_name}-policy"
vault policy-write "${mount_path}-intermediate-ca-policy" "/tmp/${mount_path}-intermediate-ca-policy"

vault write auth/approle/role/vault  "policies=${mount_path}-${role_name}-policy,${mount_path}-intermediate-ca-policy"
vault write auth/approle/role/consul "policies=${mount_path}-${role_name}-policy"
