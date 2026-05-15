#!/bin/bash

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

    sudo tee -a "$CONFIG_PATH" > /dev/null <<EOF

database:
  name: psycopg2
  args:
    user: ${DB_USER}
    password: ${POSTGRES_PASSWORD}
    database: ${DB_NAME}
    host: ${DB_HOST}
    cp_min: 5
    cp_max: 10

enable_registration: true
enable_registration_captcha: true
recaptcha_siteverify_api: "https://www.google.com/recaptcha/api/siteverify"
recaptcha_public_key: "${RECAPTCHA_PUBLIC_KEY}"
recaptcha_private_key: "${RECAPTCHA_PRIVATE_KEY}"
EOF

    echo "Файл homeserver.yaml успешно обновлен."
else
    echo "Ошибка: Базовый конфигурационный файл не найден."
    exit 1
fi

echo "Выполняется полная очистка закешированных томов Postgres..."
docker compose down -v
sudo rm -rf matrix/postgres_data/

OS_TYPE="$(uname -s)"
if [[ "$OS_TYPE" != *"MINGW"* && "$OS_TYPE" != *"MSYS"* ]]; then
    sudo chown -R 991:991 matrix/data/
fi

sudo mkdir -p /home/r9888/NextcloudData
sudo chown -R 33:33 /home/r9888/NextcloudData

echo "Перезапуск всех Docker-контейнеров стека..."
docker compose up -d

echo "Ожидание готовности PostgreSQL для Synapse..."
until [ "$(docker inspect -f '{{.State.Health.Status}}' synapse_db)" == "healthy" ]; do
    sleep 2
done

echo "Ожидание запуска веб-интерфейса Synapse..."
sleep 15

chmod +x scripts/create_admin.sh
./scripts/create_admin.sh

echo "Ожидание завершения первичной установки Nextcloud..."
until [ "$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/nextcloud/status.php)" = "200" ]; do
    sleep 2
done

echo "Применение настроек Nextcloud..."
docker compose exec -u www-data nextcloud php occ config:system:set trusted_domains 2 --value="${SYNAPSE_SERVER_NAME}"
docker compose exec -u www-data nextcloud php occ config:system:set trusted_proxies 0 --value='172.16.0.0/12'
docker compose exec -u www-data nextcloud php occ config:system:set maintenance_window_start --value=2 --type=int
docker compose exec -u www-data nextcloud php occ background:job:set cron
docker compose exec -u www-data nextcloud php occ config:system:set default_phone_region --value='RU'
docker compose exec -u www-data nextcloud php occ config:system:set filelocking.enabled --value=true --type=boolean
docker compose exec -u www-data nextcloud php occ config:system:set memcache.local --value='\OC\Memcache\APCu'
docker compose exec -u www-data nextcloud php occ maintenance:repair --include-expensive --no-interaction
docker compose exec -u www-data nextcloud php occ maintenance:update:htaccess

echo "Настройка cron для Nextcloud..."
CRON_JOB="*/5 * * * * docker compose exec -u www-data nextcloud php -f /var/www/html/cron.php"
if ! sudo crontab -l 2>/dev/null | grep -qF "$CRON_JOB"; then
    (sudo crontab -l 2>/dev/null; echo "$CRON_JOB") | sudo crontab -
    echo "Cron-задание добавлено."
else
    echo "Cron-задание уже существует."
fi

echo "Все службы успешно запущены и настроены!"