#!/usr/bin/env bash
# Based on https://github.com/Unidata/tomcat-docker/blob/dee2d221b046b05689a4180a6a80e321549abf0a/entrypoint.sh

export USER_ID=${USERID:-1000}
export GROUP_ID=${GROUP_ID:-1000}
export ADMIN_GROUP=${ADMIN_GROUP:-admin}
export FQDN=${FQDN:-localhost:8443}
export USER_HOME=/home/tomcat
DEBUG=${DEBUG:-false}
EXTRA_JVM_ARGUMENTS=${EXTRA_JVM_ARGUMENTS:-}

set -o errexit -o nounset -o pipefail

main() {

    createUserAndGroup

    setTomcatFoldersOwnership

    startTomcat

}

createUserAndGroup() {

    echo "Creating tomcat user with UID:GID=${USER_ID}:${GROUP_ID}"
    # -S              Create a system group/user
    addgroup -g ${GROUP_ID} -S tomcat && \
    # -D              Do not assign a password
    adduser -u ${USER_ID} -S -D -H -s /sbin/nologin -G tomcat tomcat
}

setTomcatFoldersOwnership() {

    # Change CATALINA_HOME ownership to tomcat user and tomcat group
    echo "Setting ownership for tomcat folders"
    chown -R tomcat:tomcat ${CATALINA_HOME} && \
    chown -R tomcat:tomcat ${USER_HOME} && \
    # Restrict permissions on conf
    chmod 400 ${CATALINA_HOME}/conf/*

    sync
}

startTomcat() {
    
    DEBUG_PARAM=""
    if [ "${DEBUG}" == "true" ]
    then
        export JPDA_OPTS="-agentlib:jdwp=transport=dt_socket,address=8000,server=y,suspend=n"
        DEBUG_PARAM=jpda
    fi
    export CATALINA_OPTS="${EXTRA_JVM_ARGUMENTS} -Dsonia.scm.init.script.d=/opt/scm-server/init.script.d"
    exec su-exec tomcat catalina.sh ${DEBUG_PARAM} run

    # TODO use "startup.sh -security"?
    #exec su-exec tomcat  startup.sh -security
    # Never exit
    #while true; do sleep 10000; done
}

main
