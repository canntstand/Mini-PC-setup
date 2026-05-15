#!/bin/bash
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

echo "Регистрация администратора Synapse из .env..."

echo "Ожидание доступности Synapse API..."
until curl -s -f -o /dev/null http://127.0.0.1:8008/_matrix/client/versions; do
    sleep 2
done

docker compose exec -i synapse register_new_matrix_user \
    -c /data/homeserver.yaml \
    -u "$ADMIN_USER" \
    -p "$ADMIN_PASSWORD" \
    --admin \
    http://127.0.0.1:8008

echo "Пользователь $ADMIN_USER зарегистрирован как администратор."