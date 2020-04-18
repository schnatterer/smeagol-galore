#!/usr/bin/env bash

# Exported so they can be read from tomcat process
export ADMIN_GROUP=${ADMIN_GROUP:-admin}
export USER_HOME=/home/tomcat
export HTTP_PORT=${HTTP_PORT:-8080}
export HTTPS_PORT=${HTTPS_PORT:-8443}
export FQDN=${FQDN:-"localhost:${HTTPS_PORT}"}

DEBUG=${DEBUG:-false}
EXTRA_JVM_ARGUMENTS=${EXTRA_JVM_ARGUMENTS:-}
CERT_VALIDITY_DAYS=${CERT_VALIDITY_DAYS:-30}

SCM_DATA="${USER_HOME}/.scm/"
SCM_REQUIRED_PLUGINS="/opt/scm-server/required-plugins"
TOMCAT_BIN_DIR=/opt/bitnami/tomcat/bin

set -o errexit -o nounset -o pipefail

main() {

    createSelfSignedCert

    initWiki

    installScmPlugins

    startTomcat "$@"
}

createSelfSignedCert() {

    cert=/config/certs/crt.pem
    pk=/config/certs/pk.pem
    ca=/config/certs/ca.crt.pem
    trustStore=/opt/bitnami/java/lib/security/cacerts
    host=$(echo "${FQDN}" | sed -e 's/:/\n/g' | head -1)

    if [[ ! -f "${cert}" ]]; then

        echo "No TLS cert mounted, creating and trusting self-signed certificate for host ${host}"

        # In order to authenticate via scm-cas-plugin, we need to provide a subjectAltName otherwise we'll encounter
        # ClientTransportException: HTTP transport error: javax.net.ssl.SSLHandshakeException: java.security.cert.CertificateException: No subject alternative names present
        # See https://stackoverflow.com/a/84441845976863/

        CWD=$(pwd)
        TMPDIR="$(mktemp -d)"
        cd "${TMPDIR}"
        # Create CA
        openssl req -newkey rsa:4096 -keyout ca.pk.pem -x509 -new -nodes -out ${ca} \
          -subj "/OU=Unknown/O=Unknown/L=Unknown/ST=unknown/C=DE"  -days "${CERT_VALIDITY_DAYS}"

        # Create Cert
        openssl req -new -newkey rsa:4096 -nodes -keyout ${pk} -out csr.pem \
               -subj "/CN=${host}/OU=Unknown/O=Unknown/L=Unknown/ST=unknown/C=DE" \
               -reqexts SAN \
               -config <(cat /etc/ssl/openssl.cnf \
                   <(printf "\n[SAN]\nsubjectAltName=IP:127.0.0.1,DNS:%s" "${host}"))

        # Sign Cert
        openssl x509 -req -in csr.pem -CA ${ca} -CAkey ca.pk.pem -CAcreateserial -out ${cert} -days "${CERT_VALIDITY_DAYS}"
        # Trust cert internally
        keytool -import -noprompt -v -trustcacerts -alias ${host} -file ${cert} -keystore ${trustStore} -keypass changeit -storepass changeit
        # Return to former workind dir, in order not to change tomcat's working directory
        cd "${CWD}"
        # ReRemove CA private key (this is not for production!) and cert requests.
        rm -rf "${TMPDIR}"
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
    CATALINA_OPTS="-Dhttp.port=${HTTP_PORT} \
                   -Dhttps.port=${HTTPS_PORT} \
                   -Dsonia.scm.init.script.d=/opt/scm-server/init.script.d \
                   -Dsonia.scm.skipAdminCreation=true \
                   -Dsonia.scm.lifecycle.restart-strategy=exit \
                   -Dsonia.scm.restart.exit-code=42"

    export CATALINA_OPTS="${CATALINA_OPTS} ${EXTRA_JVM_ARGUMENTS} $*"
    echo "Set CATALINA_OPTS: ${CATALINA_OPTS}"

    JAVA_HOME="/opt/bitnami/java"
    export JAVA_HOME

    JAVA_OPTS="-Djava.awt.headless=true -XX:+UseG1GC -Dfile.encoding=UTF-8"
    export JAVA_OPTS

    # Load Tomcat Native library
    LD_LIBRARY_PATH="/opt/bitnami/tomcat/lib:${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    export LD_LIBRARY_PATH

    local SCM_RESTART_EVENT=42
    while ${TOMCAT_BIN_DIR}/catalina.sh ${DEBUG_PARAM} run ; scm_exit_code=$? ; [[ ${scm_exit_code} -eq ${SCM_RESTART_EVENT} ]] ; do
      echo Got exit code ${scm_exit_code} -- restarting SCM-Manager
    done
    echo Got exit code ${scm_exit_code} -- exiting
    exit ${scm_exit_code}
}

main "$@"
