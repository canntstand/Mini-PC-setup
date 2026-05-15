#!/bin/bash

if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

if [ -z "$SYNAPSE_SERVER_NAME" ]; then
    echo "Ошибка: переменная SYNAPSE_SERVER_NAME не задана в .env"
    exit 1
fi

OS_TYPE="$(uname -s)"

if [[ "$OS_TYPE" == *"MINGW"* || "$OS_TYPE" == *"MSYS"* ]]; then
    echo "Определена ОС: Windows (Git Bash)"
    MSYS_NO_PATHCONV=1 docker run -i --rm \
        -v "//$(pwd)/matrix/data:/data" \
        -e SYNAPSE_SERVER_NAME=${SYNAPSE_SERVER_NAME} \
        -e SYNAPSE_REPORT_STATS=no \
        matrixdotorg/synapse:v1.152.1 generate
else
    echo "Определена ОС: Linux"
    docker run -i --rm \
        -v "$(pwd)/matrix/data:/data" \
        -e SYNAPSE_SERVER_NAME=${SYNAPSE_SERVER_NAME} \
        -e SYNAPSE_REPORT_STATS=no \
        matrixdotorg/synapse:v1.152.1 generate
fi