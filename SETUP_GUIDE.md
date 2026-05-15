⚠️ Важно: все команды выполняются из корня проекта на СЕРВЕРЕ, если не указано иное (на клиенте).
## Подготовка
   1. sudo systemctl enable --now docker && sudo systemctl enable --now containerd
   2. git clone https://github.com/canntstand/Mini-PC-setup
   3. Зарегистрироваться в Tuna и подготовить токен авторизации.
   4. Верифицировать домен в Tuna либо использовать домены самого Tuna, для ssh зарезервировать имя в разделе ports и поставить его в TUNA_SSH_PORT в .env
   5. Настроить все переменные в файле .env (имя сервера должно совпадать с купленным доменным именем).

## Synapse (Matrix)
   1. Зарегистрировать капчу на Google reCAPTCHA Admin. Выбрать CAPTCHAv2 (флажок "Я не робот") и обязательно отключить "Verify the origin of reCAPTCHA solutions". Скопировать полученные ключи.
   2. chmod +x scripts/setup.sh && ./scripts/setup.sh

## SSH (Безопасность)
   1. sudo systemctl enable --now ssh
   2. На клиенте (вашем ПК): ssh-keygen -t ed25519 -C "main-pc-access"
   3. На клиенте (вашем ПК): ssh-copy-id server-user@server-ip (ввести пароль сервера в последний раз).
   4. Проверить вход без пароля с клиента. На сервере открыть конфигурацию: sudo nano /etc/ssh/sshd_config
   5. Выставить и проверить параметры безопасности:
      - PasswordAuthentication no
      - PermitRootLogin no
      - MaxAuthTries 3
      - PermitEmptyPasswords no
   6. sudo systemctl restart ssh
   7. ВАЖНО: Не закрывая текущий терминал, открыть новое окно на ПК и проверить вход через ssh user@server-ip.
   8. chmod +x scripts/fail2ban_setup.sh && ./scripts/fail2ban_setup.sh

## Добавление нового устройства к SSH (Например, телефона или рабочего ПК)
   1. На новом устройстве: Сгенерировать ключ: ssh-keygen -t ed25519 -C "new-device-access"
   2. Любым безопасным способом переслать строку из файла .pub нового устройства на ваш основной ПК или сервер.
   3. На сервере: nano ~/.ssh/authorized_keys
   4. Перейти в самый конец файла, создать новую строку, вставить туда публичный ключ нового устройства и сохранить файл.
   5. Для удобства на ПК можно настроить ~/.ssh/config (указать HostName туннеля, Port из панели Tuna и User), чтобы подключаться короткой командой ssh home-server.

## Audiobookshelf, Navidrome, Nextcloud
После запуска нужно просто зайти в браузере по /music, /audiobookshelf, /nextcloud и создать пользователя, после скачать понравившийся клиент на пк/телефон, войти в аккаунт и пользоваться (остальные настройки зависят от того что нужно пользователю).