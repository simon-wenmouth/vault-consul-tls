#!/usr/bin/env bash

set -o pipefail
set -x

CONSUL_HOME=${CONSUL_HOME:-/opt/consul}
CONSUL_CA_FILE="${CONSUL_HOME}/config/keys/agent.ca.pem"
CONSUL_CERT_FILE="${CONSUL_HOME}/config/keys/agent.cert.pem"
CONSUL_KEY_FILE="${CONSUL_HOME}/config/keys/agent.key.pem"

vault_token_json=$(curl --insecure --fail --silent --header "X-Vault-Token: ${VAULT_WRAPPED_TOKEN}" --request POST "${VAULT_ADDR}/v1/sys/wrapping/unwrap")

vault_token=$(echo "${vault_token_json}" | jq -r .auth.client_token)

pki_request=$(mktemp)

cat <<-EOF > "${pki_request}"
{
  "common_name": "$(hostname -f)",
  "alt_names": "localhost",
  "ttl": "8760h",
  "ip_sans": "$(hostname -i),127.0.0.1",
  "format": "pem"
}
EOF

cat "${pki_request}"

pki=$(curl --insecure --fail --request POST --header "X-Vault-Token: ${vault_token}" --data @"${pki_request}" "${VAULT_ADDR}/v1/pki-ca/issue/tls-cert")

echo "${pki}" | jq -r .data.certificate >  "${CONSUL_CERT_FILE}"
echo "${pki}" | jq -r .data.issuing_ca  >> "${CONSUL_CERT_FILE}"
echo "${pki}" | jq -r .data.private_key >  "${CONSUL_KEY_FILE}"
echo "${pki}" | jq -r .data.issuing_ca  >  "${CONSUL_CA_FILE}"

chmod go-wx  "${CONSUL_CERT_FILE}" "${CONSUL_CA_FILE}"
chmod go-rwx "${CONSUL_KEY_FILE}"

exec $@