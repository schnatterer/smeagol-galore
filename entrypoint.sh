#!/usr/bin/env bash

# Exported so they can be read from tomcat process
export ADMIN_GROUP=${ADMIN_GROUP:-admin}
export FQDN=${FQDN:-localhost:8443}
export USER_HOME=/home/tomcat

DEBUG=${DEBUG:-false}
EXTRA_JVM_ARGUMENTS=${EXTRA_JVM_ARGUMENTS:-}
DEFAULT_FQDN="localhost\:8443"


set -o errexit -o nounset -o pipefail

main() {

    writeFQDN

    startTomcat
}

writeFQDN() {

    files=( \
        # Note that in SCMM the FQDN is set up using the groovy scripts
        "/usr/local/tomcat/application.yml" \
        "/etc/cas/cas.properties" \
        "/usr/local/tomcat/webapps/cas/WEB-INF/deployerConfigContext.xml" \
        "/usr/local/tomcat/webapps/cas/WEB-INF/spring-configuration/uniqueIdGenerators.xml" )


    for i in "${files[@]}"
    do
        echo "Updating FQDN in ${i} (FQDN=${FQDN})"
        sed -i "s/${DEFAULT_FQDN}/${FQDN}/" ${i}
    done
}

startTomcat() {

    DEBUG_PARAM=""
    if [ "${DEBUG}" == "true" ]
    then
        export JPDA_OPTS="-agentlib:jdwp=transport=dt_socket,address=8000,server=y,suspend=n"
        DEBUG_PARAM=jpda
    fi

    export CATALINA_OPTS="${EXTRA_JVM_ARGUMENTS} -Dsonia.scm.init.script.d=/opt/scm-server/init.script.d"
    catalina.sh ${DEBUG_PARAM} run

    # TODO use "startup.sh -security"?
    #exec su-exec tomcat  startup.sh -security
    # Never exit
    #while true; do sleep 10000; done
}

main "$@"
