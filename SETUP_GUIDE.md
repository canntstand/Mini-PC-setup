1. Настроить все переменные в .env (также стоит сразу купить домен для имени сервера)
2. https://www.google.com/recaptcha/admin/create здесь настроить капчу и взять ключи (нужно выбрать CAPTCHAv2 с проверкой i'm not a robot и отключить Verify the origin of reCAPTCHA solutions)
3. Настройка проброса в интернет либо разворачивать на удаленном сервере
4. Запуск скрипта /scripts/synapse_init.sh (перед этим chmod +x scripts/synapse_init.sh)
5. В homeserver.yaml: 
    - enable_registration: true 
    - enable_registration_captcha: true
    - recaptcha_public_key: поставить полученный ключ
    - recaptcha_private_key: поставить полученный ключ

6. docker-compose -f docker-compose.yaml up
7. Запуск скрипта create_admin.sh