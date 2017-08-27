#!/usr/bin/env bash

PROJECT_NAME=tls

function build_images() {
    docker build --tag simon-wenmouth/vault:0.8.1 --rm --force-rm images/vault
    docker build --tag simon-wenmouth/consul:0.9.2 --rm --force-rm images/consul
}

function container_start() {
    docker-compose -p "${PROJECT_NAME}" up -d "$@"
}

function container_wait_until_healthy() {
    local service_name=$1
    local time_limit="$((SECONDS + 60))"
    local status="undefined"
    while [ "$SECONDS" -le "$time_limit" ]; do
        status=$(docker inspect --format='{{.State.Health.Status}}' "${PROJECT_NAME}_${service_name}_1")
        echo "[INFO] ${service_name} status: ${status}"
        if [ "${status}" == "healthy" ]; then
            break
        fi
        sleep 10
    done
}

function vault_wait_until_property_value() {
    set +e
    local service_name=$1
    local time_limit="$((SECONDS + 60))"
    while [ "$SECONDS" -le "$time_limit" ]; do
        json=$(docker exec "${PROJECT_NAME}_${service_name}_1" bash -c 'curl --insecure --fail --silent "https://localhost:8200/v1/sys/health?uninitcode=200&sealedcode=200&standbyok=true"')
        if [[ $? -eq 0 ]]; then
            val=$(echo "${json}" | jq -r ".${2}")
            if [[ "${val}" == "${3}" ]]; then
                break
            fi
        fi
        sleep 10
    done
    set -e
}

function vault_init() {
    local service_name=$1
    local addr="https://${2}:8200"
    local cert="/opt/vault/config/keys/server.ca.pem"
    docker exec "${PROJECT_NAME}_${service_name}_1" bash -c "vault init -address=${addr} -ca-cert=${cert} -key-shares=1 -key-threshold=1"
}

function vault_unseal() {
    local service_name=$1
    local addr="https://${2}:8200"
    local cert="/opt/vault/config/keys/server.ca.pem"
    docker exec "${PROJECT_NAME}_${service_name}_1" bash -c "vault unseal -address=${addr} -ca-cert=${cert} ${3}"
}

function ca() {
    container_start ca
    vault_wait_until_property_value 'ca' 'initialized' 'false'
    ca_init=$(vault_init 'ca' 'localhost')
    ca_key=$(echo "${ca_init}" | grep '^Unseal Key 1:' | sed -e 's/Unseal Key 1: \(.*\)$/\1/')
    ca_token=$(echo "${ca_init}" | grep '^Initial Root Token:' | sed -e 's/Initial Root Token: \(.*\)$/\1/')
    vault_unseal 'ca' 'localhost' "${ca_key}"
    docker exec "${PROJECT_NAME}_ca_1" bash /opt/vault/bin/ca-initialize.sh "${ca_token}"
}

function ca_exec() {
    local subcommand=$1
    shift
    local service_name='ca'
    local addr="https://ca.dc.consul:8200"
    local cert="/opt/vault/config/keys/server.ca.pem"
    docker exec "${PROJECT_NAME}_${service_name}_1" bash -c "vault ${subcommand} -address=${addr} -ca-cert=${cert} $*"
}

function consul_server() {
    local wrapped_token=$1
    echo "VAULT_ADDR=https://ca.dc.consul:8200"  > .env-consul-server
    echo "VAULT_WRAPPED_TOKEN=${wrapped_token}" >> .env-consul-server
    container_start 'consul-server'
    container_wait_until_healthy 'consul-server'
}

function consul_client() {
    local wrapped_token=$1
    echo "VAULT_ADDR=https://ca.dc.consul:8200"  > .env-consul-client
    echo "VAULT_WRAPPED_TOKEN=${wrapped_token}" >> .env-consul-client
    container_start 'consul-client'
    container_wait_until_healthy 'consul-client'
}

function intermediate_ca() {
    echo "CA_VAULT_ADDR=https://ca.dc.consul:8200"  > .env-vault
    echo "CA_VAULT_WRAPPED_TOKEN=${1}" >> .env-vault
    container_start vault
    vault_wait_until_property_value 'vault' 'initialized' 'false'
    ica_init=$(vault_init 'vault' 'localhost')
    ica_key=$(echo "${ica_init}" | grep '^Unseal Key 1:' | sed -e 's/Unseal Key 1: \(.*\)$/\1/')
    ica_token=$(echo "${ica_init}" | grep '^Initial Root Token:' | sed -e 's/Initial Root Token: \(.*\)$/\1/')
    vault_unseal 'vault' 'localhost' "${ica_key}"
    docker exec "${PROJECT_NAME}_vault_1" bash /opt/vault/bin/intermediate-initialize.sh "${2}" "${ica_token}"
}

command=$1

shift

rm .env-consul-client .env-consul-server .env-vault

touch .env-consul-client .env-consul-server .env-vault

case "${command}" in
    build)
        build_images
        ;;
    up)
        set -e
        # start the ca
        ca
        # start the consul agent (server)
        role_name=consul
        role_id=$(ca_exec read -field=role_id "auth/approle/role/${role_name}/role-id")
        secret_id=$(ca_exec write -f --field=secret_id "auth/approle/role/${role_name}/secret-id")
        wrapped_token=$(ca_exec write -wrap-ttl=1h -field=wrapping_token auth/approle/login "role_id=${role_id}" "secret_id=${secret_id}")
        consul_server "${wrapped_token}"
        # start the consul agent (client)
        wrapped_token=$(ca_exec write -wrap-ttl=1h -field=wrapping_token auth/approle/login "role_id=${role_id}" "secret_id=${secret_id}")
        consul_client "${wrapped_token}"
        # start the intermediate certificate authority
        role_name=vault
        role_id=$(ca_exec read -field=role_id "auth/approle/role/${role_name}/role-id")
        secret_id=$(ca_exec write -f --field=secret_id "auth/approle/role/${role_name}/secret-id")
        wrapped_token_1=$(ca_exec write -wrap-ttl=1h -field=wrapping_token auth/approle/login "role_id=${role_id}" "secret_id=${secret_id}")
        wrapped_token_2=$(ca_exec write -wrap-ttl=1h -field=wrapping_token auth/approle/login "role_id=${role_id}" "secret_id=${secret_id}" )
        intermediate_ca "${wrapped_token_1}" "${wrapped_token_2}"
        ;;
    down)
        docker-compose -p "${PROJECT_NAME}" down --volumes
        ;;
    *)
        echo "Unknown command: ${command}"
        ;;
esac
