#!/bin/bash

echo "Установка и настройка системы защиты Fail2ban..."

if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
else
    echo "Ошибка: Не удалось определить дистрибутив (отсутствует /etc/os-release)."
    exit 1
fi

case "$-" in
    *)
        if [[ "$DISTRO" == "arch" ]]; then
            echo "Обнаружен Arch Linux. Установка через pacman..."
            sudo pacman -Syu fail2ban --noconfirm

        elif [[ "$DISTRO" == "ubuntu" || "$DISTRO" == "debian" || "$DISTRO" == "pop" || "$DISTRO" == "mint" ]]; then
            echo "Обнаружен $NAME. Установка через apt..."
            sudo apt update && sudo apt install fail2ban -y

        elif [[ "$DISTRO" == "centos" || "$DISTRO" == "rhel" || "$DISTRO" == "rocky" || "$DISTRO" == "almalinux" ]]; then
            echo "Обнаружен $NAME. Установка через dnf/yum..."
            sudo dnf install epel-release -y 2>/dev/null || sudo yum install epel-release -y
            sudo dnf install fail2ban -y 2>/dev/null || sudo yum install fail2ban -y

        else
            echo "Критическая ошибка: Дистрибутив '$DISTRO' не поддерживается этим скриптом автоматической установки."
            exit 1
        fi
        ;;
esac

if [ -f fail2ban/jail.local ]; then
    sudo cp fail2ban/jail.local /etc/fail2ban/jail.local
    echo "Конфигурация jail.local успешно скопирована."
else
    echo "Ошибка: Файл fail2ban/jail.local не найден в вашем локальном репозитории!"
    exit 1
fi

sudo systemctl enable --now fail2ban

echo "Служба Fail2ban успешно запущена и работает на базе $NAME."