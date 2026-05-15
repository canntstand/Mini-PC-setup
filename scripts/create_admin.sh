#!/bin/bash

if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

echo "Регистрируем администратора ${ADMIN_USER}..."

docker exec -it synapse register_new_matrix_user \
    -u "${ADMIN_USER}" -p "${ADMIN_PASSWORD}" \
    -a -c /data/homeserver.yaml http://localhost:8008