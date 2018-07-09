#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail

main() {

    waitForScm

    validateScmRestApiUsesCas

    validateSmeagolUsesCas
}

waitForScm() {

    # This takes 200s and more because of the installed plugins on first start
    echo "$(date +"%Y-%m-%d %H:%M:%S") Waiting for SCMM to become available"
    TIMEOUT=300 
    for i in {1..${TIMEOUT}} 
    do
        if docker logs smeagol-galore 2>&1 | grep 'Reloading Context with name \[/scm\] is completed'; then
            break
        fi

        sleep 1

        if [ "$i" = "${TIMEOUT}" ]; then 
            echo "Cancel waiting for SCMM"
            return 1
         fi
    done
}

validateScmRestApiUsesCas() {

    result=$(curl -su admin:admin --retry 3 --retry-delay 0 --insecure https://localhost:8443/scm/api/rest/users.json 2>&1)
    echo "Query Users = ${result}"
    # Validate our admin user is returned
    echo ${result} | grep scm@adm.in
    echo "validateScmRestApiUsesCas successful"
}

validateSmeagolUsesCas() {
    # TODO can we do a smeagol login on CLI?
    echo "validateSmeagolUsesCas not implemented, yet"
}

main "$@"
