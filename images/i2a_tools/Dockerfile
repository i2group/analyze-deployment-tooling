# (C) Copyright IBM Corporation 2018, 2020.
#
# This program and the accompanying materials are made available under the
# terms of the Eclipse Public License 2.0 which is available at
# http://www.eclipse.org/legal/epl-2.0.
#
# SPDX-License-Identifier: EPL-2.0
FROM adoptopenjdk/openjdk8:ubi-jre

ARG USERNAME=i2analyze
ARG USER_UID
ARG USER_GID=$USER_UID

RUN useradd $USERNAME

RUN groupmod --gid $USER_GID $USERNAME \
    && usermod --uid $USER_UID --gid $USER_GID $USERNAME \
    && chown -R $USER_UID:$USER_GID /home/$USERNAME
 
COPY docker-entrypoint.sh /opt/docker-entrypoint.sh
COPY environment.sh /opt/environment.sh
COPY tools/ /opt/

RUN chown -R $USER_UID:$USER_GID /opt/environment.sh /opt/docker-entrypoint.sh /opt/i2-tools/* /opt/scripts/*
ENV TOOLKIT_DIR=/opt

USER $USERNAME

ENTRYPOINT ["/opt/docker-entrypoint.sh"]
