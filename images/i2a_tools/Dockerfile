# syntax=docker/dockerfile:1
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022)
#
# SPDX short identifier: MIT
FROM registry.access.redhat.com/ubi8/ubi-minimal:8.6
ARG I2ANALYZE_VERSION

COPY --from=adoptopenjdk/openjdk11:ubi-jre "/opt/java/openjdk" "/opt/java/openjdk"
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG I2ANALYZE_VERSION

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

ENV JAVA_HOME="/opt/java/openjdk" \
  PATH="/opt/java/openjdk/bin:$PATH"

ARG USERNAME=i2analyze
ARG USER_UID=1001
ARG USER_GID=$USER_UID

RUN useradd $USERNAME

RUN groupmod --gid $USER_GID $USERNAME \
  && usermod --uid $USER_UID --gid $USER_GID $USERNAME \
  && chown -R $USER_UID:$USER_GID /home/$USERNAME

COPY --chown=$USER_UID:$USER_GID docker-entrypoint.sh /opt/docker-entrypoint.sh
COPY --chown=$USER_UID:$USER_GID environment.sh /opt/environment.sh
COPY --chown=$USER_UID:$USER_GID tools/ /opt/

RUN mkdir -p /opt/configuration /opt/databaseScripts/generated /var/i2a-data /simulatedKeyStore \
  && chown -R $USER_UID:$USER_GID /opt/configuration \
  /opt/databaseScripts/generated \
  /var/i2a-data \
  /simulatedKeyStore

ENV TOOLKIT_DIR=/opt \
  USER="${USERNAME}"

USER $USERNAME

ENTRYPOINT ["/opt/docker-entrypoint.sh"]
