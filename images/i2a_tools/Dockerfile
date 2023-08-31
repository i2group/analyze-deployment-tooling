# syntax=docker/dockerfile:1
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2023)
#
# SPDX short identifier: MIT

ARG BASE_IMAGE="eclipse-temurin:11-ubi9-minimal"

FROM ${BASE_IMAGE}
ARG I2ANALYZE_VERSION

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

LABEL maintainer="i2 Group" \
  com.i2group.i2analyze-version="${I2ANALYZE_VERSION}"

# Install required packages
RUN set -eux; \
  microdnf -y install \
  shadow-utils \
  findutils \
  tar \
  gzip \
  ca-certificates \
  gnupg \
  openssl; \
  microdnf clean all;

ARG USERNAME=i2analyze
ARG USER_UID=1000
ARG USER_GID=$USER_UID

ARG GOSU_VERSION=1.16

RUN [[ "$(uname -m)" != "aarch64" ]]; \
  curl -o /usr/local/bin/gosu -SL "https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-amd64" \
  || curl -o /usr/local/bin/gosu -SL "https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-arm64" \
  && chmod +x /usr/local/bin/gosu \
  # Verify that the binary works
  && gosu nobody true

RUN useradd "$USERNAME" \
  && groupmod --gid "$USER_GID" "$USERNAME" \
  && usermod --uid "$USER_UID" --gid $USER_GID "$USERNAME" \
  && chown -R "$USER_UID:$USER_GID" "/home/$USERNAME"

COPY --chown=$USERNAME docker-entrypoint.sh /opt/docker-entrypoint.sh
COPY --chown=$USERNAME environment.sh /opt/environment.sh
COPY --chown=$USERNAME tools/ /opt/
COPY --chown=$USERNAME changelog.json /opt/changelog.json

RUN mkdir -p /opt/configuration /opt/databaseScripts/generated /var/i2a-data /tmp/i2acerts \
  && chown -R $USERNAME /opt/configuration \
  /opt/databaseScripts/generated \
  /var/i2a-data \
  /tmp/i2acerts

ENV TOOLKIT_DIR=/opt \
  USER="${USERNAME}"

VOLUME [ "/simulatedKeyStore", "/opt/configuration", "/opt/databaseScripts/generated", "/var/i2a-data" ]

ENTRYPOINT ["/opt/docker-entrypoint.sh"]
