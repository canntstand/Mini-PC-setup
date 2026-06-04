echo "Проверка автозапуска Docker..."
if ! systemctl is-enabled --quiet docker; then
    echo "Включаю автозапуск Docker..."
    sudo systemctl enable docker
fi

sudo systemctl start docker

if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
else
    echo "ОШИБКА: Файл .env не найден!"
    exit 1
fi

if ! command -v htpasswd &> /dev/null; then
    echo "Установка htpasswd для генерации bcrypt‑хеша..."
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
    else
        echo "ОШИБКА: Не удалось определить дистрибутив (файл /etc/os-release отсутствует)."
        exit 1
    fi

    if [ "$DISTRO" = "ubuntu" ] || [ "$DISTRO" = "debian" ] || [ "$DISTRO" = "pop" ] || [ "$DISTRO" = "mint" ] || [ "$DISTRO" = "linuxmint" ] || [ "$DISTRO" = "raspbian" ]; then
        sudo apt-get update -qq
        sudo apt-get install -y apache2-utils -qq
    elif [ "$DISTRO" = "rhel" ] || [ "$DISTRO" = "centos" ] || [ "$DISTRO" = "rocky" ] || [ "$DISTRO" = "almalinux" ] || [ "$DISTRO" = "fedora" ]; then
        sudo dnf install -y epel-release
        sudo dnf install -y httpd-tools
    elif [ "$DISTRO" = "arch" ] || [ "$DISTRO" = "manjaro" ]; then
        sudo pacman -Syu --noconfirm apache-tools
    elif [ "$DISTRO" = "opensuse" ] || [ "$DISTRO" = "suse" ]; then
        sudo zypper install -y apache2-utils
    elif [ "$DISTRO" = "alpine" ]; then
        sudo apk add apache2-utils
    else
        echo "ОШИБКА: Дистрибутив '$DISTRO' не поддерживается этим скриптом."
        echo "Пожалуйста, установите 'htpasswd' вручную (например, apache2-utils или httpd-tools)."
        exit 1
    fi

    if ! command -v htpasswd &> /dev/null; then
        echo "ОШИБКА: Не удалось установить htpasswd. Установите пакет вручную."
        exit 1
    fi
    echo "htpasswd успешно установлен."
fi

ENV_FILE="${ENV_FILE:-.env}"

if ! grep -q "^ADMIN_PASSWORD_HASH=" "$ENV_FILE"; then
    echo "Генерация ADMIN_PASSWORD_HASH для Gatus..."
    
    BCRYPT_HASH=$(htpasswd -bnBC 10 "" "$ADMIN_PASSWORD" | tr -d ':\n' | sed 's/\$2y\$/\$2a\$/')
    
    B64_HASH=$(echo -n "$BCRYPT_HASH" | base64 | tr -d '\n')
    
    echo "ADMIN_PASSWORD_HASH=$B64_HASH" >> "$ENV_FILE"
    echo "ADMIN_PASSWORD_HASH успешно добавлен в .env"
fi

set -a
source "$ENV_FILE"
set +a

echo "Настройка сертификатов..."
if [ ! -d "./certbot-dns-webnames" ]; then
    git clone https://github.com/regtime-ltd/certbot-dns-webnames.git ./certbot-dns-webnames
fi
curl -s -k "https://www.webnames.ru/scripts/json_domain_zone_manager.pl?action=get_config_certbot&domain=${SYNAPSE_SERVER_NAME}&apikey=${WEBNAMES_APIKEY}" -o ./certbot-dns-webnames/config.sh
chmod +x ./certbot-dns-webnames/*.sh

NEED_REAL_CERT=false
CERT_DIR="./certs/live/${SYNAPSE_SERVER_NAME}"
if [ ! -f "${CERT_DIR}/fullchain.pem" ]; then
    mkdir -p "${CERT_DIR}"
    openssl req -x509 -nodes -days 1 -newkey rsa:2048 -keyout "${CERT_DIR}/privkey.pem" -out "${CERT_DIR}/fullchain.pem" -subj "/CN=localhost"
    NEED_REAL_CERT=true
fi

if [ "$NEED_REAL_CERT" = true ]; then
    echo "Получение реального сертификата..."
    sudo docker compose -f docker-compose.remote.yaml build certbot
    rm -rf "${CERT_DIR:?}"/*
    sudo docker compose -f docker-compose.remote.yaml run --rm certbot
    sudo docker compose -f docker-compose.remote.yaml exec nginx nginx -s reload
else 
    echo "Сертификаты уже существуют!"
fi

echo "Применение системных настроек для работы VPN..."

add_sysctl_param() {
    local param="$1"
    local value="$2"
    local line="${param}=${value}"
    if grep -qxF "$line" /etc/sysctl.conf; then
        echo "Параметр $line уже присутствует в /etc/sysctl.conf"
    else
        echo "$line" | sudo tee -a /etc/sysctl.conf
        echo "Добавлен параметр $line"
    fi
}

add_sysctl_param "net.ipv4.ip_forward" "1"
add_sysctl_param "net.ipv4.conf.all.src_valid_mark" "1"
add_sysctl_param "net.ipv6.conf.all.disable_ipv6" "0"
add_sysctl_param "net.ipv6.conf.all.forwarding" "1"
add_sysctl_param "net.ipv6.conf.default.forwarding" "1"

sudo sysctl -p

if sudo iptables -C FORWARD -i wg0 -j ACCEPT 2>/dev/null; then
    echo "Правило FORWARD -i wg0 уже существует"
else
    sudo iptables -A FORWARD -i wg0 -j ACCEPT
    echo "Добавлено правило FORWARD -i wg0"
fi

if sudo iptables -C FORWARD -o wg0 -j ACCEPT 2>/dev/null; then
    echo "Правило FORWARD -o wg0 уже существует"
else
    sudo iptables -A FORWARD -o wg0 -j ACCEPT
    echo "Добавлено правило FORWARD -o wg0"
fi

if sudo iptables -t nat -C POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE 2>/dev/null; then
    echo "Правило MASQUERADE для wg0 уже существует"
else
    sudo iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE
    echo "Добавлено правило MASQUERADE для wg0"
fi

sudo docker compose -f docker-compose.remote.yaml up gatus nginx wg-easy -d