#!/usr/bin/env bash

set -o pipefail
set -x

VAULT_HOME=${VAULT_HOME:-/opt/vault}
VAULT_CA_FILE="${VAULT_HOME}/config/keys/server.ca.pem"
VAULT_CERT_FILE="${VAULT_HOME}/config/keys/server.cert.pem"
VAULT_KEY_FILE="${VAULT_HOME}/config/keys/server.key.pem"

vault_token=$(vault unwrap -field=token -tls-skip-verify -address="${CA_VAULT_ADDR}" "${CA_VAULT_WRAPPED_TOKEN}")

export VAULT_TOKEN=${vault_token}

pki=$(vault write -tls-skip-verify -address="${CA_VAULT_ADDR}" -format=json "pki-ca/issue/tls-cert" "common_name=$(hostname -f)" "alt_names=localhost" "ttl=8760h" "ip_sans=$(hostname -i),127.0.0.1" "format=pem")

unset VAULT_TOKEN

echo "${pki}" | jq -r .data.certificate >  "${VAULT_CERT_FILE}"
echo "${pki}" | jq -r .data.issuing_ca  >> "${VAULT_CERT_FILE}"
echo "${pki}" | jq -r .data.private_key >  "${VAULT_KEY_FILE}"
echo "${pki}" | jq -r .data.issuing_ca  >  "${VAULT_CA_FILE}"

chmod go-wx  "${VAULT_CERT_FILE}" "${VAULT_CA_FILE}"
chmod go-rwx "${VAULT_KEY_FILE}"

exec $@
