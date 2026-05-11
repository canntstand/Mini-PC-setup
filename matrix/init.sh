docker run -it --rm \
    -v $(pwd)/matrix/data:/data \
    -e SYNAPSE_SERVER_NAME=${SYNAPSE_SERVER_NAME} \
    -e SYNAPSE_REPORT_STATS=yes \
    matrixdotorg/synapse:v1.152.1 generate

sudo chown -R 991:991 matrix/data/