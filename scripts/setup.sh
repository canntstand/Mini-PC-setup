#!/bin/bash

chmod +x scripts/synapse_init.sh
./scripts/synapse_init.sh

echo "Запуск Docker-контейнеров..."
docker compose up -d

echo "Ожидание готовности PostgreSQL для Synapse..."
until [ "$(docker inspect -f '{{.State.Health.Status}}' synapse_db)" == "healthy" ]; do
    sleep 2
done

echo "Ожидание готовности PostgreSQL для Nextcloud..."
until [ "$(docker inspect -f '{{.State.Health.Status}}' nextcloud_db)" == "healthy" ]; do
    sleep 2
done

chmod +x scripts/create_admin.sh
./scripts/create_admin.sh

echo "Ожидание завершения первичной установки Nextcloud..."
until docker compose exec -u www-data nextcloud php occ status > /dev/null 2>&1; do
    sleep 3
done

echo "Применение системных исправлений и тюнинга Nextcloud..."
docker compose exec -u www-data nextcloud php occ config:system:set trusted_domains 2 --value="${SYNAPSE_SERVER_NAME}"
docker compose exec -u www-data nextcloud php occ config:system:set trusted_proxies 0 --value='172.16.0.0/12'
docker compose exec -u www-data nextcloud php occ config:system:set maintenance_window_start --value=2 --type=int
docker compose exec -u www-data nextcloud php occ background:job:set cron
docker compose exec -u www-data nextcloud php occ config:system:set default_phone_region --value='RU'
docker compose exec -u www-data nextcloud php occ config:system:set filelocking.enabled --value=true --type=boolean
docker compose exec -u www-data nextcloud php occ config:system:set memcache.local --value='\OC\Memcache\APCu'

echo "Применение миграций Nextcloud..."
docker compose exec -u www-data nextcloud php occ maintenance:repair --include-expensive --no-interaction
docker compose exec -u www-data nextcloud php occ maintenance:update:htaccess

echo "Вся инфраструктура успешно инициализирована и настроена!"
