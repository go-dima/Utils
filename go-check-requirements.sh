#!/bin/bash -e

# This script checks for possible updates of go modules from an organization.
# Run check-go-requirements.sh --help for usage

# Consts
RED="\033[0;31m"
NO_COLOR="\033[0m"
BOLD="\033[1m"
REQUIREMENTS_FILENAME="go.mod"

# Defaults
CURRENT_DIR=$(pwd)
TEMP_FILE="${CURRENT_DIR}/.temp.req"

# Functions
find_requirements() {
    # Find all required pacakges from github.com/*
    GIT_ORG="github-organization-prefix"
    DEPS=$(cat ${1} | grep -E "${GIT_ORG}v[0-9]+.[0-9]+.[0-9]+.*$" | grep -v "//" > ${TEMP_FILE})
}

create_commit() {
    # Prepare commitddd
    go mod tidy
    git add go.mod go.sum
    git commit -m 'Bump requirements versions'
}

compare_version() {
    SUFFIX="" # Reset for each requirement
    REPO=${1}
    VERSION=${2}
    REPO_URL="https://${REPO}"

    # Find latest published tag of requirement
    LATEST_VERSION=$(git ls-remote --tags --sort=version:refname ${REPO_URL} | tail -1 | awk '{print $2}' | cut -f3 -d'/')

    if [ "${VERSION}" != "${LATEST_VERSION}" ]; then
        SUFFIX="${RED}<- update me!${NO_COLOR}"
    fi

    echo -e "${REPO}: ${VERSION} is used, latest version: ${LATEST_VERSION} ${SUFFIX}"

    if [ "${UPDATE}" == "true" ]; then
        sed -i '' "s#${REPO} ${VERSION}#${REPO} ${LATEST_VERSION}#" ${REQUIREMENTS_FILE}
    fi
}

usage() {
    echo -e "\nUsage: ./check-go-requirements.sh -repo [path] <OPTIONS>"
    echo -e "\t"    "--update"      "\t"    "Change dependencies in go.mod and run go mod tidy"
    echo -e "\t"    "--commit"      "\t"    "Commit changes"
    echo -e "\t"    "--auto"        "\t"    "Update and commit"
    echo -e "\t"    "-h --help"     "\t"    "Show usage"
}

# Read options
while test $# -gt 0; do
    case "$1" in
        -r|\
        -repo)
            shift
            REPO_PATH=${1}
            shift
            ;;
        --commit)
            COMMIT=true
            shift
            ;;
        --update)
            UPDATE=true
            shift
            ;;
        --auto)
            COMMIT=true
            UPDATE=true
            shift
            ;;
        -h|\
        --help)
            usage
            shift
            exit 0
            ;;
        *)
           echo "$1 is not a recognized parameter"
           commandError
           ;;
    esac
done

###### Main ######

pushd ${REPO_PATH}

REQUIREMENTS_FILES=$(find . -iname ${REQUIREMENTS_FILENAME})

if [[ "${#REQUIREMENTS_FILES}" -eq 0 ]]; then
    echo "Couldn't find ${REQUIREMENTS_FILENAME} in `pwd`"
    exit 1
fi

if [ "${UPDATE}" != "true" ]; then
    echo -e "${BOLD}Report only, run with --update to modify, --help for more details${NO_COLOR}"
fi

for REQUIREMENTS_FILE in ${REQUIREMENTS_FILES}; do
    find_requirements ${REQUIREMENTS_FILE}

    while read req; do
        compare_version ${req}
    done <${TEMP_FILE}
done

# Clean temp files
rm ${TEMP_FILE}

if [ "${COMMIT}" == "true" ]; then
    create_commit
else
    echo -e "${BOLD}Any change won't be committed, run with --commit to save changes, --help for details${NO_COLOR}"
fi

popd
