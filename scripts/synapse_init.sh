#!/bin/bash
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

if [ -z "$SYNAPSE_SERVER_NAME" ] || [ -z "$RECAPTCHA_PUBLIC_KEY" ] || [ -z "$RECAPTCHA_PRIVATE_KEY" ] || [ -z "$POSTGRES_PASSWORD" ]; then
    echo "Ошибка: Проверьте переменные SYNAPSE_SERVER_NAME, RECAPTCHA_PUBLIC_KEY, RECAPTCHA_PRIVATE_KEY и POSTGRES_PASSWORD в .env"
    exit 1
fi

OS_TYPE="$(uname -s)"
CONFIG_PATH="matrix/data/homeserver.yaml"

if [[ "$OS_TYPE" == *"MINGW"* || "$OS_TYPE" == *"MSYS"* ]]; then
    echo "Определена ОС: Windows (Git Bash)"
    MSYS_NO_PATHCONV=1 docker run -it --rm \
        -v "//$(pwd)/matrix/data:/data" \
        -e SYNAPSE_SERVER_NAME=${SYNAPSE_SERVER_NAME} \
        -e SYNAPSE_REPORT_STATS=yes \
        matrixdotorg/synapse:v1.152.1 generate
else
    echo "Определена ОС: Linux"
    docker run -it --rm \
        -v "$(pwd)/matrix/data:/data" \
        -e SYNAPSE_SERVER_NAME=${SYNAPSE_SERVER_NAME} \
        -e SYNAPSE_REPORT_STATS=yes \
        matrixdotorg/synapse:v1.152.1 generate
fi

if [ -f "$CONFIG_PATH" ]; then
    echo "Модификация файла homeserver.yaml..."

    python3 -c "
import os

path = '$CONFIG_PATH'
with open(path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
inside_database = False
db_inserted = False
xf_inserted = False

# Сборка новых параметров из .env
db_user = os.getenv('POSTGRES_USER', 'synapse_user')
db_pass = os.getenv('POSTGRES_PASSWORD')
db_name = os.getenv('POSTGRES_DB_SYNAPSE', 'synapse')
db_host = os.getenv('POSTGRES_HOST', 'db')

postgres_block = f'''database:
  name: psycopg2
  args:
    user: {db_user}
    password: {db_pass}
    database: {db_name}
    host: {db_host}
    cp_min: 5
    cp_max: 10
'''

for line in lines:
    # 1. Замена блока database
    if line.strip().startswith('database:'):
        inside_database = True
        if not db_inserted:
            new_lines.append(postgres_block)
            db_inserted = True
        continue
    if inside_database:
        # Пропускаем вложенные аргументы старой БД sqlite3
        if line.startswith(' ') or line.strip() == '':
            continue
        else:
            inside_database = False

    # 2. Поиск порта 8008 для вставки x_forwarded (без дублирования)
    if 'port: 8008' in line:
        xf_inserted = True
    if xf_inserted and 'type: http' in line:
        new_lines.append(line)
        new_lines.append('    x_forwarded: true\n')
        xf_inserted = False
        continue

    # Исключаем дублирование x_forwarded, если оно уже записалось ранее
    if line.strip() == 'x_forwarded: true':
        continue

    new_lines.append(line)

# 3. Добавление блока регистрации и правильной ссылки капчи в конец файла
captcha_block = f'''
enable_registration: true
enable_registration_captcha: true
recaptcha_siteverify_api: \"https://www.google.com/recaptcha/api/siteverify\"
recaptcha_public_key: \"{os.getenv('RECAPTCHA_PUBLIC_KEY')}\"
recaptcha_private_key: \"{os.getenv('RECAPTCHA_PRIVATE_KEY')}\"
'''
new_lines.append(captcha_block)

with open(path, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print('Конфигурация успешно обновлена.')
"
else
    echo "Ошибка: Файл $CONFIG_PATH не найден!"
    exit 1
fi

if [[ "$OS_TYPE" != *"MINGW"* && "$OS_TYPE" != *"MSYS"* ]]; then
    echo "Настройка прав доступа (chown) для Linux..."
    sudo chown -R 991:991 matrix/data/
fi