echo "Перезапуск всех Docker-контейнеров стека..."
docker compose down -v
sudo rm -rf matrix/postgres_data/

if [[ "$OS_TYPE" != *"MINGW"* && "$OS_TYPE" != *"MSYS"* ]]; then
    sudo chown -R 991:991 matrix/data/
fi
sudo mkdir -p /home/r9888/NextcloudData
sudo chown -R 33:33 /home/r9888/NextcloudData

docker compose up -d

echo "Ожидание запуска всех сервисов (60 секунд)..."
sleep 60

chmod +x scripts/create_admin.sh
./scripts/create_admin.sh

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