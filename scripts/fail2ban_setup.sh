#!/bin/bash

echo "Установка и настройка системы защиты Fail2ban..."

sudo pacman -Syu fail2ban --noconfirm

if [ -f fail2ban/jail.local ]; then
    sudo cp fail2ban/jail.local /etc/fail2ban/jail.local
    echo "Конфигурация jail.local успешно скопирована."
else
    echo "Ошибка: Файл fail2ban/jail.local не найден в репозитории!"
    exit 1
fi

sudo systemctl enable --now fail2ban

echo "Служба Fail2ban успешно запущена и работает."