# syntax=docker/dockerfile:1
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2023)
#
# SPDX short identifier: MIT
ARG BASE_IMAGE=liberty_redhat
FROM ${BASE_IMAGE}

# Copy classes configuration into liberty image
COPY --chown=1001:0 classes/ /config/apps/opal-services.war/WEB-INF/classes/
COPY --chown=1001:0 server.extensions*.xml jvm.options* /config/
COPY --chown=1001:0 user.registry.xml /liberty/usr/shared/config/user.registry.xml
COPY --chown=1001:0 application/web-app-files/ /config/apps/opal-services.war/WEB-INF/

# Copy libs into liberty image
COPY --chown=1001:0 lib/ /config/apps/opal-services.war/WEB-INF/lib/

# Copy plugins into liberty image
COPY --chown=1001:0 plugins/ /config/apps/opal-services.war/plugins/

# Copy extra files into liberty image
COPY --chown=1001:0 privacyagreement.html /config/apps/opal-services.war/privacyagreement.html