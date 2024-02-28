#!/bin/bash

usage() {
    echo -e "\nUsage: start-local-pg.sh -param <parameter>"
    echo -e "\t"    "--name <name>" "\t"    "Provide custom name for container (default: 'REPO'-'BRANCH')"
    echo -e "\t"    "--dry-run"     "\t"    "Run without executing (show commands)"
    echo -e "\t"    "-h --help"     "\t"    "Show usage"
}

update_dotenv_file() {
    DOTENV_FILE=".env.test"
    VAR_NAME=${1}
    CONNECTION_STRING=${2}

    # Check if file exists
    if [ ! -f "${DOTENV_FILE}" ]; then
        # Create file if it doesn't exist
        touch "${DOTENV_FILE}" && echo "Created ${DOTENV_FILE}"
    fi

    # Check if line exists in file
    if ! grep -q "^${VAR_NAME}=" "${DOTENV_FILE}"; then
        # Add line to file if it's not found
        echo "$VAR_NAME=${CONNECTION_STRING}" >> "${DOTENV_FILE}"
    else
        # Store new connection string in .env.test file
        sed -i '' 's#^'"${VAR_NAME}"'=.*#'"${VAR_NAME}"'='"${CONNECTION_STRING}"'#' ${DOTENV_FILE}
        env | grep -i ${VAR_NAME}
    fi
}

REPO=$(basename `git rev-parse --show-toplevel`)
BRANCH=$(git rev-parse --abbrev-ref HEAD | sed 's$-$-$g;s$/$-$g')
PG_NAME="${REPO}-${BRANCH}"
PORT=$(jot -r 1 54320 54360)

# Check if migration tool exists
which migration-tool > /dev/null 2>&1
MIGRATION_TOOL_FOUND=$?

#Read options
while test $# -gt 0; do
    case "$1" in
        --name)
            shift # skip flag
            PG_NAME=$1
            shift
            ;;
        --force)
            docker rm -f ${PG_NAME}
            shift
            ;;
        --dry-run)
            DRYRUN=true
            shift
            ;;
        -h|\
        --help)
            usage
            exit 0
            ;;
        *)
            echo "$1 is not a recognized parameter"
            usage
            exit 1
            ;;
    esac
done

echo "Starting $PG_NAME:$PORT..."
CMD="docker run --name ${PG_NAME} -e POSTGRES_DB=${REPO} -e POSTGRES_PASSWORD=mysecretpassword -p ${PORT}:5432 -d postgres:alpine3.18"

if [[ $(docker ps -f "name=${PG_NAME}" --format '{{.Names}}') == ${PG_NAME} ]]; then
  PORT=$(docker ps -f "name=${PG_NAME}" --format '{{.Ports}}' | sed -E 's/.*:(.*)->.*/\1/')
elif [[ $DRYRUN ]]; then
    echo $CMD
    exit 0
else
  eval $CMD
  sleep 2
fi

docker ps | grep ${PG_NAME}

# If running in repo directory
if [ -d "pgconf" ]; then
    # Read the config.yaml file and grep for the connectionString line
    CONECTION_STR_LINE=$(grep "connectionString:" pgconf/config.yaml)

    # Use sed to extract the variable name from the ${} syntax
    CONN_STR_VAR_NAME=$(echo "$CONECTION_STR_LINE" | sed 's/.*{\([^}]*\)}.*/\1/')
    CONNECTION_STRING="postgresql://postgres:mysecretpassword@localhost:${PORT}/${REPO}"
    export ${CONN_STR_VAR_NAME}=${CONNECTION_STRING}

    if [ $MIGRATION_TOOL_FOUND -eq 0 ]; then
        migration-tool migrate apply
    else
        echo "No migration tool, skipping..."
    fi

    update_dotenv_file ${CONN_STR_VAR_NAME} ${CONNECTION_STRING}
fi
