#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail

main() {
    validateScmRestApiUsesCas

    validateSmeagolUsesCas
}


validateScmRestApiUsesCas() {

    queryUsers="curl -su admin:admin --retry 3 --retry-delay 0 --insecure https://localhost:8443/scm/api/rest/users.json"
    # For some reasons this works only on the 3rd try when using SCMM's Rest API without accessing the UI. So do a little "warmup"
    ignore=$(eval ${queryUsers})
    ignore=$(eval ${queryUsers})
    # Do the actual check
    result=$(eval ${queryUsers})
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
