#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail

main() {

    waitForScm

    validateScmRestApiUsesCas

    validateSmeagolUsesCas
}

waitForScm() {

    # This takes 200s and more because of the installed plugins on first start
    for i in {1..30} # Don't wait forever
    do
        ret=$(curl -sS --insecure --connect-timeout 1 https://localhost:8443/scm 2>&1 || true)
        echo "Waiting for SCMM returned: ${ret}"
        if [ -z "${ret}" ]; then
            echo "SCMM became ready"
            break
        fi
        sleep 10

        if [ "$i" = "30" ]; then 
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
