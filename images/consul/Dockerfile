FROM centos:7.3.1611

LABEL name="Consul"
LABEL license="Mozilla Public License, version 2.0"

ARG KEYSERVER=ha.pool.sks-keyservers.net
ARG CONSUL_VERSION=0.9.2
ARG CONSUL_ZIP_URL=https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip
ARG CONSUL_SHA_URL=https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_SHA256SUMS
ARG CONSUL_SIG_URL=https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_SHA256SUMS.sig
ARG CONSUL_UID=10001
ARG CONSUL_GID=10001
ARG CONSUL_LOGIN=consul

ENV CONSUL_HOME=/opt/consul

ENV PATH=${PATH}:${CONSUL_HOME}/bin

RUN set -ex \
    && yum -y install epel-release \
    && yum -y update \
    && yum -y install openssl unzip iproute less bind-utils vim net-tools wget which nc jq \
    && yum -y remove epel-release \
    && yum clean all \
    && gpg --keyserver "${KEYSERVER}" --recv-keys 51852D87348FFC4C \
    && groupadd -g ${CONSUL_GID} ${CONSUL_LOGIN} \
    && useradd --create-home --system --shell /bin/bash --uid ${CONSUL_UID} --gid ${CONSUL_GID} ${CONSUL_LOGIN} \
    && mkdir --parents /opt/consul/{bin,data} /opt/consul/config/keys /var/run/consul \
    && cd /opt/consul \
    && curl -fSL "${CONSUL_ZIP_URL}" -o "consul_${CONSUL_VERSION}_linux_amd64.zip" \
    && curl -fSL "${CONSUL_SHA_URL}" -o "consul_${CONSUL_VERSION}.sha" \
    && curl -fSL "${CONSUL_SIG_URL}" -o "consul_${CONSUL_VERSION}.sha.sig" \
    && gpg --verify "consul_${CONSUL_VERSION}.sha.sig" "consul_${CONSUL_VERSION}.sha" \
    && grep "consul_${CONSUL_VERSION}_linux_amd64.zip" "consul_${CONSUL_VERSION}.sha" > "consul_${CONSUL_VERSION}_linux_amd64.sha" \
    && sha256sum --check "consul_${CONSUL_VERSION}_linux_amd64.sha" \
    && unzip -d bin "consul_${CONSUL_VERSION}_linux_amd64.zip" \
    && rm "consul_${CONSUL_VERSION}_linux_amd64.zip" \
    && rm "consul_${CONSUL_VERSION}_linux_amd64.sha" \
    && rm "consul_${CONSUL_VERSION}.sha" \
    && rm "consul_${CONSUL_VERSION}.sha.sig" \
    && chown -R "${CONSUL_UID}":"${CONSUL_GID}" "${CONSUL_HOME}" /var/run/consul

COPY ./consul-entrypoint.sh ./docker-healthcheck.sh /opt/consul/bin/

USER ${CONSUL_UID}

WORKDIR /opt/consul

VOLUME ["/opt/consul/config", "/opt/consul/data"]

EXPOSE 8300 8301 8301/udp 8302 8302/udp 8400 8500 8600 8600/udp

HEALTHCHECK CMD bash -c /opt/consul/bin/docker-healthcheck.sh

ENTRYPOINT ["/opt/consul/bin/consul"]
