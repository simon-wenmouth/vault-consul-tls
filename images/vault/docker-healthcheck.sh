#!/usr/bin/env bash

set -o pipefail
set -u
set -e
set -x

VAULT_HOME=${VAULT_HOME:-/opt/vault}

VAULT_ADDR="https://$(hostname -f):8200"

VAULT_CACERT="--cacert ${VAULT_HOME}/config/keys/server.ca.pem --cert ${VAULT_HOME}/config/keys/server.cert.pem --key ${VAULT_HOME}/config/keys/server.key.pem"

health=$(curl --fail --silent ${VAULT_CACERT} "${VAULT_ADDR}/v1/sys/health?standbyok=true")

is_sealed=$(echo "${health}" | jq -r .sealed)

[[ "${is_sealed}" == "false" ]] || exit 1
