#!/usr/bin/env bash

set -o pipefail
set -e
set -x

ca_wrapped_token=$1

vault_token=$2

VAULT_HOME=${VAULT_HOME:-/opt/vault}

# unwrap the token from the ca

export VAULT_CACERT="${VAULT_HOME}/config/keys/server.ca.pem"

ca_token=$(vault unwrap -address="https://ca.$(hostname -d):8200" -field=token "${ca_wrapped_token}")

# configure the intermediate and generate an intermediate csr

export VAULT_ADDR="https://$(hostname -f):8200"

export VAULT_TOKEN=${vault_token}

mount=pki-ica

csr="${VAULT_HOME}/config/keys/intermediate.csr.pem"

vault mount "-path=${mount}" pki

vault mount-tune -max-lease-ttl=87600h "${mount}"

vault write -field=csr "${mount}/intermediate/generate/internal" "common_name=$(hostname -f)" ttl=8760h "ip_sans=$(hostname -i)"  > "${csr}"

# sign the intermediate csr

export VAULT_ADDR="https://ca.$(hostname -d):8200"

export VAULT_TOKEN=${ca_token}

certificate_bundle="${VAULT_HOME}/config/keys/intermediate-bundle.json"

certificate="${VAULT_HOME}/config/keys/intermediate.cert.pem"

issuing_ca="${VAULT_HOME}/config/keys/intermediate.issuing_ca.pem"

ca_chain="${VAULT_HOME}/config/keys/intermediate.ca_chain.pem"

vault write -format=json "pki-ca/root/sign-intermediate" "csr=@${csr}" use_csr_values=true format=pem_bundle > "${certificate_bundle}"

jq -r '.data.certificate' "${certificate_bundle}" > "${certificate}"
jq -r '.data.issuing_ca'  "${certificate_bundle}" > "${issuing_ca}"
jq -r '.data.ca_chain'    "${certificate_bundle}" > "${ca_chain}"

# set the signed certificate

export VAULT_ADDR="https://$(hostname -f):8200"

export VAULT_TOKEN=${vault_token}

vault write "${mount}/intermediate/set-signed" "certificate=@${certificate}"
