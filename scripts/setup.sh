#!/bin/bash
set -e

if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

chmod +x scripts/synapse_init.sh
./scripts/synapse_init.sh

CONFIG_PATH="matrix/data/homeserver.yaml"

echo "Полная перезапись конфигурации homeserver.yaml..."

sudo tee "$CONFIG_PATH" > /dev/null <<EOF
server_name: "${SYNAPSE_SERVER_NAME}"
pid_file: /data/homeserver.pid

listeners:
  - port: 8008
    resources:
      - compress: false
        names:
          - client
          - federation
    tls: false
    type: http
    x_forwarded: true

database:
  name: psycopg2
  args:
    user: ${POSTGRES_USER}
    password: ${POSTGRES_PASSWORD}
    database: ${POSTGRES_DB_SYNAPSE}
    host: synapse_db
    cp_min: 5
    cp_max: 10

log_config: "/data/${SYNAPSE_SERVER_NAME}.log.config"
media_store_path: /data/media_store
registration_shared_secret: "${SYNAPSE_REGISTRATION_SHARED_SECRET}"
report_stats: false
macaroon_secret_key: "${SYNAPSE_MACAROON_SECRET_KEY}"
form_secret: "${SYNAPSE_FORM_SECRET}"
signing_key_path: "/data/${SYNAPSE_SERVER_NAME}.signing.key"

trusted_key_servers:
  - server_name: "matrix.org"

enable_registration: true
enable_registration_captcha: true
recaptcha_siteverify_api: "https://www.google.com/recaptcha/api/siteverify"
recaptcha_public_key: "${RECAPTCHA_PUBLIC_KEY}"
recaptcha_private_key: "${RECAPTCHA_PRIVATE_KEY}"
EOF

echo "Файл homeserver.yaml успешно сгенерирован."

OS_TYPE="$(uname -s)"
if [[ "$OS_TYPE" != *"MINGW"* && "$OS_TYPE" != *"MSYS"* ]]; then
    sudo chown -R 991:991 matrix/data/
fi

sudo mkdir -p /home/r9888/NextcloudData
sudo chown -R 33:33 /home/r9888/NextcloudData

echo "Запуск Docker-контейнеров..."
docker compose up -d

echo "Ожидание запуска Synapse (15 секунд)..."
sleep 15

chmod +x scripts/create_admin.sh
./scripts/create_admin.sh

echo "Все службы успешно запущены и изолированы внутри Docker!"