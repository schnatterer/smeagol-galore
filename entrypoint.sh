#!/usr/local/bin/dumb-init /bin/bash

# Exported so they can be read from tomcat or dehydrated processes

export ADMIN_GROUP=${ADMIN_GROUP:-admin}
export HTTP_PORT=${HTTP_PORT:-8080}
export HTTPS_PORT=${HTTPS_PORT:-8443}
export FQDN=${FQDN:-$(if [[ "$HTTPS_PORT" -eq 443 ]]; then echo -n "localhost"; else echo -n "localhost:${HTTPS_PORT}"; fi)}
DEBUG=${DEBUG:-false}
STAGING=${STAGING:-false}
EXTRA_JVM_ARGUMENTS=${EXTRA_JVM_ARGUMENTS:-}
CERT_VALIDITY_DAYS=${CERT_VALIDITY_DAYS:-30}

export USER_HOME=/home/tomcat
SCM_DATA="${USER_HOME}/.scm/"
SCM_REQUIRED_PLUGINS="/opt/scm-server/required-plugins"

# Cert handling
export DOMAIN=$(echo "${FQDN}" | sed -e 's/:/\n/g' | head -1)
export CERT_DIR="/config/certs"
CERT_DIR_WITH_DOMAIN=${CERT_DIR}/${DOMAIN}
cert=${CERT_DIR_WITH_DOMAIN}/cert.pem
pk=${CERT_DIR_WITH_DOMAIN}/privkey.pem
ca=${CERT_DIR_WITH_DOMAIN}/fullchain.pem
ENABLE_LETSENCRYPT=${ENABLE_LETSENCRYPT:-'false'}

trustStore=/opt/java/openjdk/lib/security/cacerts
ipAddress=$(hostname -I | awk '{print $1}')

NO_COLOR=${NO_COLOR:-''}

set -o errexit -o nounset -o pipefail

function main() {

    createSelfSignedCert

    initWiki

    installScmPlugins
    
    if [[ "${ENABLE_LETSENCRYPT}" != "false" ]]; then
         LOCAL_HTTP_PORT=${HTTP_PORT}
         fetchCerts &
    fi

    startTomcat "$@"
}

function createSelfSignedCert() {

    if [[ ! -f "${cert}" ]]; then

        echo "No TLS cert mounted at ${cert}, creating and trusting self-signed certificate for host ${DOMAIN}"
        
        # In order to authenticate via scm-cas-plugin, we need to provide a subjectAltName otherwise we'll encounter
        # ClientTransportException: HTTP transport error: javax.net.ssl.SSLHandshakeException: java.security.cert.CertificateException: No subject alternative names present
        # See https://stackoverflow.com/a/84441845976863/

        CWD=$(pwd)
        TMPDIR="$(mktemp -d)"
        mkdir -p "${CERT_DIR_WITH_DOMAIN}"
        cd "${TMPDIR}"
        # Create CA
        openssl req -newkey rsa:4096 -keyout ca.pk.pem -x509 -new -nodes -out "${ca}" \
          -subj "/OU=Unknown/O=Unknown/L=Unknown/ST=unknown/C=DE" -days "${CERT_VALIDITY_DAYS}"

        subjectAltName="$(printf "subjectAltName=IP:127.0.0.1,IP:%s,DNS:%s" "${ipAddress}" "${DOMAIN}")"
        openssl req -new -newkey rsa:4096 -nodes -keyout "${pk}" -out csr.pem \
               -subj "/CN=${DOMAIN}/OU=Unknown/O=Unknown/L=Unknown/ST=unknown/C=DE" \
               -config <(cat /etc/ssl/openssl.cnf <(printf "\n[SAN]\n%s" "${subjectAltName}"))

        # Sign Cert
        # Due to a bug in openssl, extensions are not transferred to the final signed x509 cert
        # https://www.openssl.org/docs/man1.1.0/man1/x509.html#BUGS
        # So add them while signing. The one added with "req" will probably be ignored.
        openssl x509 -req -in csr.pem -CA "${ca}" -CAkey ca.pk.pem -CAcreateserial -out "${cert}" -days "${CERT_VALIDITY_DAYS}" \
                -extensions v3_ca -extfile <(printf "\n[v3_ca]\n%s" "${subjectAltName}")
                
        # Trust cert internally
        addCurrentCertToTrustStore
        
        # Return to former working dir, in order not to change tomcat's working directory
        cd "${CWD}"
        # Remove CA private key (this is not for production!) and cert requests.
        rm -rf "${TMPDIR}"
    fi
}

function addCurrentCertToTrustStore() {
    local keytoolArgs="-noprompt -trustcacerts -alias ${DOMAIN} -keystore ${trustStore} -keypass changeit -storepass changeit"
    
    # If domain exists, delete it (e.g. replace sel-signed by letsencrypt cert)
    keytool -delete ${keytoolArgs} > /dev/null || true 
    
    keytool -import ${keytoolArgs} -file "${cert}"
}

function initWiki() {

    if [ -z "$(ls -A ${USER_HOME}/.scm)" ]; then
        echo "Creating default wiki"
        cp -r /opt/scm-server/defaults/* ${USER_HOME}/.scm
    fi
}

function installScmPlugins() {
    if ! [ -d "${SCM_DATA}/config" ];  then
        mkdir -p "${SCM_DATA}/config"
    fi

    # delete outdated plugins
    if [ -f "${SCM_DATA}/plugins/delete_on_update" ];  then
      ( ls -1 "${SCM_DATA}/plugins/" || true ) | grep -e "scm-.*-plugin" > "${SCM_DATA}/installed_plugins_before_update.lst" || true
      rm -rf "${SCM_DATA}/plugins"
    fi

    echo "install required plugins"
    if ! [ -d "${SCM_DATA}/plugins" ];  then
      mkdir "${SCM_DATA}/plugins"
    fi
    
    find ${SCM_REQUIRED_PLUGINS} -iname '*.smp' -type f -printf "%f\n" | while read -r pluginFile; do
        plugin="${pluginFile/.smp/}"
        echo "Processing plugin ${plugin}"
        
        if { ! [[ -d "${SCM_DATA}/plugins/${plugin}" ]] || [[ -f "${SCM_DATA}/plugins/${plugin}/uninstall" ]]; } \
            && ! [[ -f "${SCM_DATA}/plugins/${pluginFile}" ]]; then
              
          echo "Reinstalling ${plugin} from default plugin folder"
          cp "${SCM_REQUIRED_PLUGINS}/${pluginFile}" "${SCM_DATA}/plugins"
        fi
    done

    echo "Finished installing SCM plugins"
}

function startTomcat() {

    DEBUG_PARAM=""
    if [[ "${DEBUG}" == "true" ]];     then
        DEBUG_PARAM="-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:8000"
    fi
    
    if [[ "$HTTPS_PORT" -le 1024 || "${HTTP_PORT}" -le 1024 ]]; then
        AUTHBIND="authbind --deep"
     else 
        AUTHBIND=""
     fi

    # Don't set "-Dserver.name=${FQDN}", or clear pass will no longer work
    CATALINA_OPTS="-Dhttp.port=${HTTP_PORT} \
                   -Dhttps.port=${HTTPS_PORT} \
                   -Ddomain=${DOMAIN} \
                   -Dsonia.scm.init.script.d=/opt/scm-server/init.script.d \
                   -Dsonia.scm.skipAdminCreation=true \
                   -Dsonia.scm.lifecycle.restart-strategy=exit \
                   -Dsonia.scm.restart.exit-code=42"

    export CATALINA_OPTS="${CATALINA_OPTS} ${DEBUG_PARAM} ${EXTRA_JVM_ARGUMENTS} $*"
    echo "Set CATALINA_OPTS: ${CATALINA_OPTS}"

    export JAVA_OPTS="-Djava.awt.headless=true -XX:+UseG1GC -Dfile.encoding=UTF-8"
    # Load Tomcat Native library
    export LD_LIBRARY_PATH="/usr/local/lib:${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    
    local SCM_RESTART_EVENT=42
    while ${AUTHBIND} java ${CATALINA_OPTS} -jar /app/app.jar ; scm_exit_code=$? ; [[ ${scm_exit_code} -eq ${SCM_RESTART_EVENT} ]] ; do
      echo Got exit code ${scm_exit_code} -- restarting SCM-Manager
    done
    echo Got exit code ${scm_exit_code} -- exiting
    exit ${scm_exit_code}
}

function fetchCerts() {

    if [[ "${STAGING}" == "true" ]]; then
        echo 'CA="https://acme-staging-v02.api.letsencrypt.org/directory"' >> /etc/dehydrated/config
    fi
   
    green "Letsencrypt: Waiting for tomcat to become ready on localhost:${LOCAL_HTTP_PORT}"
    until $(curl -s -o /dev/null --head --fail localhost:"${LOCAL_HTTP_PORT}"); do sleep 1; done
    green "Tomcat is ready for letsencrypt"

    trap 'SIG_INT_RECEIVED="true" && green "Stopping certificate process"' INT 
    
    SIG_INT_RECEIVED='false'
    
    while [[ "${SIG_INT_RECEIVED}" == 'false' ]]; do
        green "Trying to fetch certificates"
        dehydrated --domain ${DOMAIN} --cron --accept-terms --out ${CERT_DIR} && exitCode=$? || exitCode=$?
        if [[ "${exitCode}" > 0 ]]; then
            red "Fetching certificates failed"
        elif [[ "${STAGING}" == "true" ]]; then
            green "Adding fetched letencrypt staging certificate to internal truststore"
            # Otherwise internal communication with CAS will fail
            addCurrentCertToTrustStore
        fi
        green "Waiting for a day before checking on certificate again."
        sleep 86400
    done
}

function green() {
    if [[ -z ${NO_COLOR} ]]; then
        echo -e "${GREEN}$@${DEFAULT_COLOR}"
    else 
        echo "$@"
    fi
}

function red() {
    if [[ -z ${NO_COLOR} ]]; then
        echo -e "${RED}$@${DEFAULT_COLOR}"
    else 
        echo "$@"
    fi
}

GREEN='\033[0;32m'
RED='\033[0;31m'
DEFAULT_COLOR='\033[0m'

main "$@"
