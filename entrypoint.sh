#!/usr/bin/env bash

# Exported so they can be read from tomcat process
export ADMIN_GROUP=${ADMIN_GROUP:-admin}
export FQDN=${FQDN:-localhost:8443}
export USER_HOME=/home/tomcat

DEBUG=${DEBUG:-false}
EXTRA_JVM_ARGUMENTS=${EXTRA_JVM_ARGUMENTS:-}
CERT_VALIDITY_DAYS=${CERT_VALIDITY_DAYS:-30}

SCM_DATA="${USER_HOME}/.scm/"
SCM_REQUIRED_PLUGINS="/opt/scm-server/required-plugins"

set -o errexit -o nounset -o pipefail

main() {

    createSelfSignedCert

    initWiki

    installScmPlugins

    startTomcat "$@"
}

createSelfSignedCert() {

    keystore=/usr/local/tomcat/conf/keystore.jks
    trustStore=/etc/ssl/certs/java/cacerts
    cert=/tmp/server.cer
    host=$(echo "${FQDN}" | sed -e 's/:/\n/g' | head -1)

    if [ ! -f ${keystore} ]; then

        echo "No Keystore mounted, creating and trusting self-signed certificate for host ${host}"

        # In order to authenticate via scm-cas-plugin, we need to provide a subjectAltName otherwise we'll encounter
        # ClientTransportException: HTTP transport error: javax.net.ssl.SSLHandshakeException: java.security.cert.CertificateException: No subject alternative names present
        # See https://stackoverflow.com/a/84441845976863/

        keytool -genkey -noprompt \
         -ext san=ip:127.0.0.1 -ext san=dns:${host} \
         -alias ${host} \
         -keyalg RSA -keypass changeit -storepass changeit -keystore ${keystore} \
         -dname "CN=${host}, OU=Unknown, O=Unknown, L=Unknown, S=Unknown, C=Unknown" \
         -validity "${CERT_VALIDITY_DAYS}"

        keytool -export -alias ${host} -storepass changeit -file ${cert}  -keystore ${keystore}

        keytool -import -noprompt -v -trustcacerts -alias ${host} -file ${cert} -keystore ${trustStore} -keypass changeit -storepass changeit
    fi
}

initWiki() {

    if [ -z "$(ls -A ${USER_HOME}/.scm)" ]; then
        echo "Creating default wiki"
        cp -r /opt/scm-server/defaults/* ${USER_HOME}/.scm
    fi
}

installScmPlugins() {
    if ! [ -d "${SCM_DATA}/config" ];  then
        mkdir -p "${SCM_DATA}/config"
    fi

    # delete outdated plugins
    if [ -a "${SCM_DATA}/plugins/delete_on_update" ];  then
      rm -rf "${SCM_DATA}/plugins"
    fi

    # install required plugins
    if ! [ -d "${SCM_DATA}/plugins" ];  then
        mkdir "${SCM_DATA}/plugins"
    fi
    if { ! [ -d "${SCM_DATA}/plugins/scm-cas-plugin" ] || [ -a "${SCM_DATA}/plugins/scm-cas-plugin/uninstall" ] ; } && ! [ -a "${SCM_DATA}/plugins/scm-cas-plugin.smp" ] ;  then
        echo "Reinstalling scm-cas-plugin from default plugin folder"
        cp "${SCM_REQUIRED_PLUGINS}/scm-cas-plugin.smp" "${SCM_DATA}/plugins"
    fi
    if { ! [ -d "${SCM_DATA}/plugins/scm-script-plugin" ] || [ -a "${SCM_DATA}/plugins/scm-script-plugin/uninstall" ] ; } && ! [ -a "${SCM_DATA}/plugins/scm-script-plugin.smp" ] ;  then
        echo "Reinstalling scm-script-plugin from default plugin folder"
        cp "${SCM_REQUIRED_PLUGINS}/scm-script-plugin.smp" "${SCM_DATA}/plugins"
    fi

    echo "Finished installing SCM plugins"
}

startTomcat() {

    DEBUG_PARAM=""
    if [ "${DEBUG}" == "true" ]
    then
        export JPDA_OPTS="-agentlib:jdwp=transport=dt_socket,address=8000,server=y,suspend=n"
        DEBUG_PARAM=jpda
    fi

    # Don't set "-Dserver.name=${FQDN}", or clear pass will no longer work
    CATALINA_OPTS="-Dsonia.scm.init.script.d=/opt/scm-server/init.script.d -Dsonia.scm.skipAdminCreation=true "
    export CATALINA_OPTS="${CATALINA_OPTS} -Dfqdn=${FQDN} ${EXTRA_JVM_ARGUMENTS} $*"
    echo "Set CATALINA_OPTS: ${CATALINA_OPTS}"

    local SCM_RESTART_EVENT=42
    while catalina.sh ${DEBUG_PARAM} run ; scm_exit_code=$? ; [[ ${scm_exit_code} -eq ${SCM_RESTART_EVENT} ]] ; do
      echo Got exit code ${scm_exit_code} -- restarting SCM-Manager
    done
    echo Got exit code ${scm_exit_code} -- exiting
    exit ${scm_exit_code}

    # TODO use "startup.sh -security"?
    #exec su-exec tomcat  startup.sh -security
    # Never exit
    #while true; do sleep 10000; done
}

main "$@"
