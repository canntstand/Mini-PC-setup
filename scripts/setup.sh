#!/bin/bash
set -e

chmod +x scripts/synapse_init.sh
./scripts/synapse_init.sh

CONFIG_PATH="matrix/data/homeserver.yaml"

if [ -f "$CONFIG_PATH" ]; then
    echo "Модификация файла homeserver.yaml силами Bash..."
    
    if [ -f .env ]; then
        export $(grep -v '^#' .env | xargs)
    fi

    DB_USER=${POSTGRES_USER:-synapse_user}
    DB_NAME=${POSTGRES_DB_SYNAPSE:-synapse}
    DB_HOST=${POSTGRES_HOST:-synapse_db}

    sudo sed -i '/port: 8008/,/type: http/ { /type: http/ a\    x_forwarded: true
    }' "$CONFIG_PATH"

    sudo sed -i '/listeners:/,$d' "$CONFIG_PATH"

    sudo tee -a "$CONFIG_PATH" > /dev/null <<EOF
listeners:
  - port: 8008
    tls: false
    type: http
    x_forwarded: true
    resources:
      - names:
          - client
          - federation
        compress: false

database:
  name: psycopg2
  args:
    user: ${DB_USER}
    password: ${POSTGRES_PASSWORD}
    database: ${DB_NAME}
    host: ${DB_HOST}
    cp_min: 5
    cp_max: 10

report_stats: false
enable_registration: true
enable_registration_captcha: true
recaptcha_siteverify_api: "https://google.com"
recaptcha_public_key: "${RECAPTCHA_PUBLIC_KEY}"
recaptcha_private_key: "${RECAPTCHA_PRIVATE_KEY}"
EOF
    echo "Файл homeserver.yaml успешно обновлен."
else
    echo "Ошибка: Базовый конфигурационный ... файл не найден."
    exit 1
fi

OS_TYPE="$(uname -s)"
if [[ "$OS_TYPE" != *"MINGW"* && "$OS_TYPE" != *"MSYS"* ]]; then
    sudo chown -R 991:991 matrix/data/
fi

sudo mkdir -p /home/r9888/NextcloudData
sudo chown -R 33:33 /home/r9888/NextcloudData

echo "Запуск Docker-контейнеров стека..."
docker compose up -d

echo "Ожидание инициализации всех сервисов (60 секунд)..."
sleep 60

chmod +x scripts/create_admin.sh
./scripts/create_admin.sh

echo "Запуск автоматической установки ядра Nextcloud..."
docker compose exec -u www-data nextcloud php occ maintenance:install \
  --database="pgsql" \
  --database-name="${POSTGRES_DB_NEXTCLOUD}" \
  --database-host="nextcloud_db" \
  --database-user="${POSTGRES_USER}" \
  --database-pass="${POSTGRES_PASSWORD}" \
  --admin-user="${ADMIN_USER}" \
  --admin-pass="${ADMIN_PASSWORD}" --no-interaction || echo "Nextcloud уже установлен."

echo "Применение настроек Nextcloud..."
docker compose exec -u www-data nextcloud php occ config:system:set trusted_domains 2 --value="${SYNAPSE_SERVER_NAME}" || echo "Предупреждение: не удалось установить trusted_domains"
docker compose exec -u www-data nextcloud php occ config:system:set trusted_proxies 0 --value='172.16.0.0/12'
docker compose exec -u www-data nextcloud php occ config:system:set maintenance_window_start --value=2 --type=int
docker compose exec -u www-data nextcloud php occ background:job:set cron
docker compose exec -u www-data nextcloud php occ config:system:set default_phone_region --value='RU'
docker compose exec -u www-data nextcloud php occ config:system:set filelocking.enabled --value=true --type=boolean
docker compose exec -u www-data nextcloud php occ config:system:set memcache.local --value='\OC\Memcache\APCu'
docker compose exec -u www-data nextcloud php occ maintenance:repair --include-expensive --no-interaction
docker compose exec -u www-data nextcloud php occ maintenance:update:htaccess

echo "Настройка cron для Nextcloud..."
PROJECT_DIR=$(pwd)
CRON_JOB="*/5 * * * * cd $PROJECT_DIR && /usr/bin/docker compose exec -u www-data nextcloud php -f /var/www/html/cron.php"
if ! sudo crontab -l 2>/dev/null | grep -qF "$PROJECT_DIR"; then
    (sudo crontab -l 2>/dev/null; echo "$CRON_JOB") | sudo crontab -
    echo "Cron-задание добавлено."
else
    echo "Cron-задание уже существует."
fi

echo "Все службы успешно запущены и настроены!"