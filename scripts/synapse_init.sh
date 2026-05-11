#!/bin/bash

OS_TYPE="$(uname -s)"

if [[ "$OS_TYPE" == *"MINGW"* || "$OS_TYPE" == *"MSYS"* ]]; then
    echo "Определена ОС: Windows (Git Bash)"
    
    MSYS_NO_PATHCONV=1 docker run -it --rm \
        -v "//$(pwd)/matrix/data:/data" \
        -e SYNAPSE_SERVER_NAME=${SYNAPSE_SERVER_NAME} \
        -e SYNAPSE_REPORT_STATS=yes \
        matrixdotorg/synapse:v1.152.1 generate
        
    echo "Файлы успешно сгенерированы в matrix/data"

else
    echo "Определена ОС: Linux"
    
    docker run -it --rm \
        -v "$(pwd)/matrix/data:/data" \
        -e SYNAPSE_SERVER_NAME=${SYNAPSE_SERVER_NAME} \
        -e SYNAPSE_REPORT_STATS=yes \
        matrixdotorg/synapse:v1.152.1 generate

    echo "Настройка прав доступа (chown)..."
    sudo chown -R 991:991 matrix/data/
    
    echo "Файлы успешно сгенерированы и права настроены."
fi
