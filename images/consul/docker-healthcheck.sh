#!/bin/bash

set -o pipefail
set -u
set -e
set -x

CONSUL_ADDR="https://$(hostname -f):8500"

CONSUL_HOME=${CONSUL_HOME:-/opt/consul}

CONSUL_CACERT="--cacert ${CONSUL_HOME}/config/keys/agent.ca.pem --cert ${CONSUL_HOME}/config/keys/agent.cert.pem --key ${CONSUL_HOME}/config/keys/agent.key.pem"

status=$(curl --silent --fail ${CONSUL_CACERT} "${CONSUL_ADDR}/v1/health/node/$(hostname)" | jq -r '.[] | select(.CheckID=="serfHealth") | .Status')

if [ "${status}" == "passing" ]; then
    exit 0
else
    exit 1
fi
