param(
    [string]$ProjectRoot = 'C:\project',
    [string]$Host = '82.148.17.131',
    [string]$User = 'root',
    [string]$Domain = 'express.indgas.ru'
)

$ErrorActionPreference = 'Stop'

$remote = "$User@$Host"
$deployRoot = Join-Path $ProjectRoot 'deploy'
$linuxDeployRoot = Join-Path $deployRoot 'linux'
$serverArchive = Join-Path $deployRoot 'server-deploy.tgz'
$webArchive = Join-Path $deployRoot 'web-build.tgz'

Write-Host 'Building Flutter web bundle...'
Push-Location $ProjectRoot
try {
    flutter build web --release --dart-define=API_BASE_URL=/api
} finally {
    Pop-Location
}

Write-Host 'Packing deployment archives...'
tar -czf $serverArchive -C (Join-Path $ProjectRoot 'server') .
tar -czf $webArchive -C (Join-Path $ProjectRoot 'build\web') .

Write-Host 'Uploading deployment files...'
scp $serverArchive "${remote}:/root/server-deploy.tgz"
scp $webArchive "${remote}:/root/web-build.tgz"
scp (Join-Path $linuxDeployRoot 'indgas-express-api.service') "${remote}:/root/indgas-express-api.service"
scp (Join-Path $linuxDeployRoot 'express.indgas.ru.nginx.conf') "${remote}:/root/express.indgas.ru.nginx.conf"

$remoteScript = @"
set -e

mkdir -p /opt/indgas-express/api
mkdir -p /var/www/express/build/web
mkdir -p /var/www/express/releases

if [ -f /opt/indgas-express/api/data/store.json ]; then
  cp /opt/indgas-express/api/data/store.json /root/store.json.backup
fi

if [ -f /opt/indgas-express/api/.env ]; then
  cp /opt/indgas-express/api/.env /root/indgas.env.backup
fi

rm -rf /opt/indgas-express/api/*
tar -xzf /root/server-deploy.tgz -C /opt/indgas-express/api

if [ -f /root/store.json.backup ]; then
  cp /root/store.json.backup /opt/indgas-express/api/data/store.json
fi

if [ -f /root/indgas.env.backup ]; then
  cp /root/indgas.env.backup /opt/indgas-express/api/.env
else
  SECRET=`$(openssl rand -hex 32)
  {
    echo PORT=8787
    echo APP_SECRET=`$SECRET
    echo CORS_ORIGIN=https://$Domain
  } > /opt/indgas-express/api/.env
fi

id -u indgas >/dev/null 2>&1 || useradd --system --home /opt/indgas-express/api --shell /usr/sbin/nologin indgas
chown -R indgas:indgas /opt/indgas-express/api

install -m 644 /root/indgas-express-api.service /etc/systemd/system/indgas-express-api.service
install -m 644 /root/express.indgas.ru.nginx.conf /etc/nginx/sites-available/express.indgas.ru

TS=`$(date +%Y%m%d%H%M%S)
if [ -d /var/www/express/build/web ]; then
  cp -a /var/www/express/build/web /var/www/express/releases/web-`$TS || true
fi

rm -rf /var/www/express/build/web
mkdir -p /var/www/express/build/web
tar -xzf /root/web-build.tgz -C /var/www/express/build/web

systemctl daemon-reload
systemctl enable indgas-express-api.service >/dev/null 2>&1 || true
systemctl restart indgas-express-api.service
nginx -t
systemctl reload nginx

echo '--- BACKEND'
curl -fsS http://127.0.0.1:8787/api/health
echo
echo '--- DOMAIN API'
curl -fsS https://$Domain/api/health
echo
"@

Write-Host 'Applying remote deployment...'
$remoteScript | ssh $remote "bash -s"

Write-Host 'Deployment completed.'
