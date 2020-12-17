# (C) Copyright IBM Corporation 2018, 2020.
#
# This program and the accompanying materials are made available under the
# terms of the Eclipse Public License 2.0 which is available at
# http://www.eclipse.org/legal/epl-2.0.
#
# SPDX-License-Identifier: EPL-2.0
ARG BASE_IMAGE
FROM ${BASE_IMAGE}

ARG USERNAME=i2analyze
ARG USER_UID
ARG USER_GID=$USER_UID

USER root

COPY etltoolkit /opt/ibm/etltoolkit/

RUN chown -R $USER_UID:$USER_GID /opt/ibm/etltoolkit \
  && chmod +x /opt/ibm/etltoolkit

WORKDIR /opt/ibm/etltoolkit/

USER $USERNAME

ENTRYPOINT [ "/opt/docker-entrypoint.sh" ]