#!/usr/bin/env bash
# Based on https://github.com/Unidata/tomcat-docker/blob/dee2d221b046b05689a4180a6a80e321549abf0a/entrypoint.sh

set -o errexit -o nounset -o pipefail

USER_ID=${USERID:-1000}
GROUP_ID=${GROUP_ID:-1000}

# Tomcat user
# -S              Create a system group/user
addgroup -g ${GROUP_ID} -S tomcat && \
# -D              Do not assign a password
adduser -u ${USER_ID} -S -D -H -s /sbin/nologin -G tomcat tomcat

# Change CATALINA_HOME ownership to tomcat user and tomcat group
echo "Setting ownership for tomcat folders"
chown -R tomcat:tomcat ${CATALINA_HOME} && \
chown -R tomcat:tomcat /home/tomcat && \
# Restrict permissions on conf
chmod 400 ${CATALINA_HOME}/conf/*

sync
exec su-exec tomcat "$@"