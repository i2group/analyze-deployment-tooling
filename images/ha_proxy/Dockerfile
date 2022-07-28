# syntax=docker/dockerfile:1
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022)
#
# SPDX short identifier: MIT

FROM haproxy:2.2
LABEL maintainer="i2 Group"

ARG USER=haproxy
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupmod --gid $USER_GID $USER \
  && usermod --uid $USER_UID --gid $USER_GID $USER \
  && chown -R $USER_UID:$USER_GID /opt \
  /usr/local/etc/haproxy

USER root
RUN apt-get update \
  && apt-get -y install \
  sudo

# Add sudo
RUN echo "haproxy ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

USER ${USER}

COPY docker-entrypoint.sh /opt/docker-entrypoint.sh
COPY environment.sh /opt/environment.sh

VOLUME ["/usr/local/etc/haproxy"]

ENTRYPOINT ["/opt/docker-entrypoint.sh"]
CMD ["haproxy", "-f", "/usr/local/etc/haproxy/haproxy.cfg"]