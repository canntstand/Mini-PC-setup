1. Настроить все переменные в .env (также стоит сразу купить домен для настройки всего)
2. https://www.google.com/recaptcha/admin/create здесь настроить капчу и взять ключи (нужно выбрать CAPTCHAv2 с проверкой i'm not a robot и отключить Verify the origin of reCAPTCHA solutions)
3. Если инициализировать сначала то есть скрипт /scripts/synapse_init.sh и потом нужно зайти в homeserver.yaml и в нем закомментировать:
    - recaptcha_public_key
    - recaptcha_private_key
    - macaroon_secret_key
    - form_secret
    - registration_shared_secret
4. В этом же файле добавить: enable_registration: true + enable_registration_captcha: true
5. Настройка проброса в интернет либо разворачивать на удаленном сервере
6. Создание admin пользователя с помощью файла scripts/create_synapse_admin.sh