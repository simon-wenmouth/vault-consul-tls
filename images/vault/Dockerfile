FROM centos:7.3.1611

LABEL name="Vault"
LABEL license="Mozilla Public License, version 2.0"

ARG KEYSERVER=ha.pool.sks-keyservers.net
ARG VAULT_VERSION=0.8.1
ARG VAULT_ZIP_URL=https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip
ARG VAULT_SIG_URL=https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_SHA256SUMS.sig
ARG VAULT_SHA_URL=https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_SHA256SUMS
ARG VAULT_UID=10000
ARG VAULT_GID=10000
ARG VAULT_LOGIN=vault

ENV VAULT_HOME=/opt/vault

ENV PATH=${PATH}:${VAULT_HOME}/bin

RUN set -ex \
    && yum -y install epel-release \
    && yum -y update \
    && yum -y install openssl unzip iproute less bind-utils vim net-tools wget which nc jq \
    && yum -y remove epel-release \
    && yum clean all \
    && gpg --keyserver "${KEYSERVER}" --recv-keys 51852D87348FFC4C \
    && groupadd -g "${VAULT_GID}" "${VAULT_LOGIN}" \
    && useradd --create-home --system --shell /bin/bash --uid "${VAULT_UID}" --gid "${VAULT_GID}" "${VAULT_LOGIN}" \
    && mkdir --parents /var/log/vault "${VAULT_HOME}"/{bin,data} "${VAULT_HOME}"/config/keys/bootstrap \
    && cd "${VAULT_HOME}" \
    && curl -fSL "${VAULT_ZIP_URL}" -o "vault_${VAULT_VERSION}_linux_amd64.zip" \
    && curl -fSL "${VAULT_SHA_URL}" -o "vault_${VAULT_VERSION}.sha" \
    && curl -fSL "${VAULT_SIG_URL}" -o "vault_${VAULT_VERSION}.sha.sig" \
    && gpg --verify "vault_${VAULT_VERSION}.sha.sig" "vault_${VAULT_VERSION}.sha" \
    && grep "vault_${VAULT_VERSION}_linux_amd64.zip" "vault_${VAULT_VERSION}.sha" > "vault_${VAULT_VERSION}_linux_amd64.sha" \
    && sha256sum --check "vault_${VAULT_VERSION}_linux_amd64.sha" \
    && unzip "vault_${VAULT_VERSION}_linux_amd64.zip" -d "${VAULT_HOME}/bin/" \
    && rm "vault_${VAULT_VERSION}_linux_amd64.zip" \
    && rm "vault_${VAULT_VERSION}_linux_amd64.sha" \
    && rm "vault_${VAULT_VERSION}.sha" \
    && rm "vault_${VAULT_VERSION}.sha.sig" \
    && chown -R "${VAULT_UID}":"${VAULT_GID}" /var/log/vault "${VAULT_HOME}"

COPY ./openssl.cnf ./ca-entrypoint.sh ./ca-initialize.sh ./intermediate-entrypoint.sh ./docker-healthcheck.sh ./intermediate-initialize.sh "${VAULT_HOME}/bin/"

USER ${VAULT_UID}

WORKDIR /opt/vault/

VOLUME ["/opt/vault/config/", "/opt/vault/data/", "/var/log/vault/"]

EXPOSE 8200 8201

HEALTHCHECK CMD bash -c /opt/vault/bin/docker-healthcheck.sh

ENTRYPOINT ["/opt/vault/bin/vault"]
