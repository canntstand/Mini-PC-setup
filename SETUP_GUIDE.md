⚠️ Важно: все команды выполняются из корня проекта на СЕРВЕРЕ, если не указано иное (на клиенте).

# Подготовка
1. sudo systemctl enable --now docker
2. sudo systemctl enable --now containerd
3. git clone https://github.com/canntstand/Mini-PC-setup.git
4. Зарегаться в Tuna, подготовить токен
4. Настроить все переменные в .env (имя сервера должно совпадать с купленным доменным именем).

# Synapse (Matrix)
1. Зарегистрировать капчу на Google reCAPTCHA Admin. Выбрать CAPTCHAv2 (флажок "Я не робот") и обязательно отключить "Verify the origin of reCAPTCHA solutions". Скопировать ключи.
2. chmod +x scripts/synapse_init.sh && ./scripts/synapse_init.sh
3. В сгенерированном matrix/data/homeserver.yaml задать:
    - enable_registration: true
    - enable_registration_captcha: true
    - recaptcha_public_key: <публичный_ключ>
    - recaptcha_private_key: <приватный_ключ>
4. В docker-compose.yaml в tuna-ssh заменить frolov-ssh на свое название зарезервированное на сайте tuna в ports + нужно верифицировать домен там же
4. docker compose up -d
5. chmod +x scripts/create_admin.sh && ./scripts/create_admin.sh

# SSH (Безопасность)
1. sudo systemctl enable --now ssh
2. На клиенте: ssh-keygen -t ed25519 -C "main-pc-access"
3. На клиенте: ssh-copy-id server-user@server-ip (ввести пароль сервера один последний раз)
4. Проверить вход без пароля с клиента. На сервере открыть конфиг: sudo nano /etc/ssh/sshd_config
5. Выставить параметры:
    - PasswordAuthentication no
    - PermitRootLogin no
    - MaxAuthTries 3
    - PermitEmptyPasswords no

6. sudo systemctl restart ssh
7. sudo pacman -Syu fail2ban --noconfirm
8. sudo mv fail2ban/jail.local /etc/fail2ban/jail.local
9. sudo systemctl enable --now fail2ban

# Добавление нового устройства к SSH (Например, телефона или рабочего ПК)
1. На новом устройстве: Сгенерировать ключ: ssh-keygen -t ed25519 -C "new-device-access"
2. Любым безопасным способом переслать строку из файла .pub нового устройства на ваш основной ПК или сервер.
3. На сервере: nano ~/.ssh/authorized_keys
4. Перейти в самый конец файла, создать новую строку и вставить туда публичный ключ нового устройства. Сохранить файл.