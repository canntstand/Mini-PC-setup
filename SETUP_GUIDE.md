⚠️ Важно: все команды выполняются из корня проекта на СЕРВЕРЕ (мини-ПК), если не указано иное.
# Подготовка

   1. sudo systemctl enable --now docker
   2. sudo systemctl enable --now containerd

# Synapse (Matrix)

   1. Настроить все переменные в .env (указать имя сервера, совпадающее с купленным доменным именем).
   2. Зарегистрировать капчу на Google reCAPTCHA Admin. Выбрать CAPTCHAv2 (флажок "Я не робот") и обязательно отключить "Verify the origin of reCAPTCHA solutions". Скопировать ключи.
   3. chmod +x scripts/synapse_init.sh && ./scripts/synapse_init.sh
   4. В сгенерированном matrix/data/homeserver.yaml задать:
   * enable_registration: true
      * enable_registration_captcha: true
      * recaptcha_public_key: <публичный_ключ>
      * recaptcha_private_key: <приватный_ключ>
   5. docker compose up -d
   6. chmod +x scripts/create_admin.sh && ./scripts/create_admin.sh

# Tuna Tunnel

   1. curl -sSLf https://get.tuna.am | sh
   2. tuna config save-token <ваш_токен>
   3. В файле tuna/tuna.yml указать настройки домена и проброс портов Matrix (8080) и SSH (22).
   4. mkdir -p ${HOME}/.config/tuna && mv tuna/tuna.yml ${HOME}/.config/tuna/tuna.yml
   5. Настроить автозапуск службы в системе: tuna service install
   6. sudo systemctl enable --now tuna

# SSH (Безопасность)

1. sudo systemctl enable --now ssh

⚠️ СЛЕДУЮЩИЕ ШАГИ 2–3 ВЫПОЛНЯЮТСЯ НА ВАШЕМ ОСНОВНОМ ПК/НОУТБУКЕ (КЛИЕНТЕ):
2. На клиенте: ssh-keygen -t ed25519 -C "main-pc-access"
3. На клиенте: ssh-copy-id server-user@server-ip (ввести пароль сервера один последний раз)
⚠️ ВОЗВРАЩАЕМСЯ В ТЕРМИНАЛ СЕРВЕРА (МИНИ-ПК):
4. Проверить вход без пароля с клиента. На сервере открыть конфиг: sudo nano /etc/ssh/sshd_config
5. Выставить параметры:
    - PasswordAuthentication no
    - PermitRootLogin no
    - MaxAuthTries 3
    - PermitEmptyPasswords no

6. sudo systemctl restart ssh
7. sudo apt update && sudo apt install fail2ban -y
8. sudo mv fail2ban/jail.local /etc/fail2ban/jail.local
9. sudo systemctl enable --now fail2ban

# Добавление нового устройства к SSH (Например, телефона или рабочего ПК)

   1. На новом устройстве: Сгенерировать ключ: ssh-keygen -t ed25519 -C "new-device-access"
   2. Любым безопасным способом переслать строку из файла .pub нового устройства на ваш основной ПК или сервер.
   3. На сервере: nano ~/.ssh/authorized_keys
   4. Перейти в самый конец файла, создать новую строку и вставить туда публичный ключ нового устройства. Сохранить файл.