# syntax=docker/dockerfile:1
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022)
#
# SPDX short identifier: MIT
ARG BASE_IMAGE=i2a_tools_redhat
FROM ${BASE_IMAGE}

USER root

COPY --chown="${USER}" etltoolkit /opt/i2/etltoolkit/

WORKDIR /opt/i2/etltoolkit/

USER $USERNAME
