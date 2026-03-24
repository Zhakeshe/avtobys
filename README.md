# Avtobys MVP

Workspace:

- `backend` - API + admin panel
- `flutter_clone` - main Flutter client for Android, iPhone web, and Flutter web deploy
- `react_native_clone` - old React Native client, optional

## Backend

```powershell
cd C:\Users\Zhorik\Desktop\avtobys\backend
npm install
npm start
```

Backend env setup:

```powershell
cd C:\Users\Zhorik\Desktop\avtobys\backend
Copy-Item .env.example .env
```

Set these values in `backend/.env` for Telegram login delivery:

- `TELEGRAM_BOT_TOKEN=...`
- `TELEGRAM_BOT_USERNAME=...` (without `@`)
- `TELEGRAM_POLLING=true` for local/http mode
- `TELEGRAM_CHAT_MAP_JSON={"+77001234567":"123456789"}` (optional)

URLs:

- API: `http://localhost:4000/api`
- Admin panel: `http://localhost:4000`

## Flutter local run

Android emulator:

```powershell
cd C:\Users\Zhorik\Desktop\avtobys\flutter_clone
flutter run
```

Web:

```powershell
cd C:\Users\Zhorik\Desktop\avtobys\flutter_clone
flutter run -d chrome --dart-define=AVTOBUS_API_URL=http://localhost:4000/api
```

Custom backend host:

```powershell
cd C:\Users\Zhorik\Desktop\avtobys\flutter_clone
flutter run --dart-define=AVTOBUS_API_URL=http://YOUR_PC_IP:4000/api
```

## Flutter web build

```powershell
cd C:\Users\Zhorik\Desktop\avtobys\flutter_clone
flutter build web --dart-define=AVTOBUS_API_URL=https://YOUR_DOMAIN/api
```

Build output:

- `flutter_clone/build/web`

## VPS deploy

Backend:

```bash
cd /var/www/avtobys/backend
npm install
ADMIN_TOKEN=your_admin_token NODE_ENV=production PORT=4000 node server.js
```

Recommended with PM2:

```bash
cd /var/www/avtobys/backend
pm2 start server.js --name avtobys-api --update-env --time
pm2 save
```

Telegram bot via HTTPS webhook:

```bash
cd /var/www/avtobys/backend
DATABASE_URL='postgresql://USER:PASSWORD@127.0.0.1:5433/avtobys' DATABASE_SSL=false ADMIN_TOKEN='your_admin_token' TELEGRAM_BOT_TOKEN='YOUR_BOT_TOKEN' TELEGRAM_BOT_USERNAME='your_bot_username' NODE_ENV=production PORT=4000 pm2 restart avtobys-api --update-env
curl "https://api.telegram.org/botYOUR_BOT_TOKEN/setWebhook?url=https://YOUR_DOMAIN/api/telegram/webhook"
```

Telegram bot with plain HTTP server:

- Telegram webhook will not work on plain `http`.
- Use polling mode instead, then public HTTPS is not required for the bot.

```bash
cd /var/www/avtobys/backend
DATABASE_URL='postgresql://USER:PASSWORD@127.0.0.1:5433/avtobys' DATABASE_SSL=false ADMIN_TOKEN='your_admin_token' TELEGRAM_BOT_TOKEN='YOUR_BOT_TOKEN' TELEGRAM_BOT_USERNAME='your_bot_username' TELEGRAM_POLLING=true NODE_ENV=production PORT=4000 pm2 restart avtobys-api --update-env
```

Notes:

- `TELEGRAM_BOT_USERNAME` should be without `@`
- if BotFather username is `avtobyskzzbot`, set exactly `avtobyskzzbot`
- do not add a trailing `.`

Flutter web build on VPS:

```bash
cd /var/www/avtobys/flutter_clone
flutter pub get
flutter build web --dart-define=AVTOBUS_API_URL=https://YOUR_DOMAIN/api
```

Point Nginx root to:

- `/var/www/avtobys/flutter_clone/build/web`

Proxy `/api` to:

- `http://127.0.0.1:4000/api`

## Subdomain + HTTPS for web app

QR/camera and Bluetooth flows in browser should be opened from HTTPS.

1. Create DNS `A` record for subdomain, for example:
   - `pay.avtobys.kz -> YOUR_SERVER_IP`
2. Nginx config (`/etc/nginx/sites-available/avtobys`):

```nginx
server {
    listen 80;
    server_name pay.avtobys.kz;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name pay.avtobys.kz;

    root /var/www/avtobys/flutter_clone/build/web;
    index index.html;

    ssl_certificate /etc/letsencrypt/live/pay.avtobys.kz/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/pay.avtobys.kz/privkey.pem;

    location /api/ {
        proxy_pass http://127.0.0.1:4000/api/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

3. Issue certificate:

```bash
sudo certbot --nginx -d pay.avtobys.kz
sudo systemctl reload nginx
```

4. Rebuild web for HTTPS domain:

```bash
cd /var/www/avtobys/flutter_clone
flutter build web --dart-define=AVTOBUS_API_URL=https://pay.avtobys.kz/api
```

## Current Flutter flow

- login by phone with Telegram code
- saved session token
- city selection and city sync
- wallet balance from backend
- bank cards and transport cards
- active card selection
- wallet top-up and transport card top-up
- 2 trial rides until admin enables ride access
- access request flow to `@aqxrx`
- routes by city from backend
- payment by bus number
- QR token payment flow for web
- validator list flow for Flutter web/mobile fallback
- tickets with QR
- admin panel with cities, tariffs, buses, users, cards, balances

## Important web note

- Flutter web is good for site deploy and iPhone Safari usage.
- Real camera scanning and real Bluetooth in browser are still limited by browser/platform support.
- For stable iPhone web version use the current QR token flow.
- For full native camera/Bluetooth later, build Flutter iOS and Flutter Android apps separately.
- iPhone browser mode is blocked by `web/index.html`: users must use Share -> Add to Home Screen.
