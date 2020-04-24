#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail

export FQDN=${FQDN:-localhost:8443}
host=$(echo "${FQDN}" | sed -e 's/:/\n/g' | head -1)
port=$(echo ${FQDN} | sed "s/${host}\|${host}://")

main() {

    validateScmRestApiUsesCas

    validateSmeagolUsesCas
}

validateScmRestApiUsesCas() {

    echo "$(date +"%Y-%m-%d %H:%M:%S") Trying to validate SCMM REST API uses CAS"
    
    result=$(curl -iLks -u admin:admin  https://${FQDN}/scm/api/v2/users 2>&1)

    # Validate our admin user is returned
    if echo ${result} | grep -q scm@adm.in; then
        echo "$(date +"%Y-%m-%d %H:%M:%S") validateScmRestApiUsesCas successful"
    else 
        echo "$(date +"%Y-%m-%d %H:%M:%S") validateScmRestApiUsesCas failed"
        return 1
    fi
}

validateSmeagolUsesCas() {

    echo "$(date +"%Y-%m-%d %H:%M:%S") Trying to validate Smeagol uses CAS"

    cookies=$(mktemp)
    url="https://${FQDN}/cas/login?service=https%3A%2F%2F${host}%3A${port}%2Fsmeagol%2F"
    [[ -z "${port}" ]] && url="https://${FQDN}/cas/login?service=https%3A%2F%2F${host}%2Fsmeagol%2F"  
    value=$(curl -iLks --cookie ${cookies} --cookie-jar ${cookies} ${url} \
        | grep '<input type="hidden" name="lt"' \
        | sed 's/.*value="\(.*\)".*/\1/')
        
    result=$(curl -iLks --cookie ${cookies} --cookie-jar ${cookies} \
      -H 'Content-Type: application/x-www-form-urlencoded' \
      --data "username=admin&password=admin&lt=${value}&execution=e1s1&_eventId=submit&submit=LOGIN" \
      ${url}) 
      
    # Validate the smeagol page is returned 
    if echo ${result} | grep -q '/smeagol/static/js/main.'; then
        echo "$(date +"%Y-%m-%d %H:%M:%S") validateSmeagolUsesCas successful"
    else 
        echo "$(date +"%Y-%m-%d %H:%M:%S") validateSmeagolUsesCas failed"
        return 1
    fi
}

main "$@"
