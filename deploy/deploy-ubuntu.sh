#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR=${1:-/opt/magicai}

echo "部署目標目錄: $TARGET_DIR"

if [ "$EUID" -ne 0 ]; then
  echo "請以 root 或 sudo 執行此腳本"
  exit 1
fi

apt-get update
apt-get install -y ca-certificates curl gnupg lsb-release apt-transport-https software-properties-common

# Install Docker
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh
fi

# Install docker compose plugin if missing
if ! docker compose version >/dev/null 2>&1; then
  DOCKER_CONFIG=${DOCKER_CONFIG:-/etc/docker}
  mkdir -p /etc/docker
  curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
fi

systemctl enable --now docker || true

# Prepare target directory
mkdir -p "$TARGET_DIR"
chown $SUDO_USER:$SUDO_USER "$TARGET_DIR" || true

echo "請確保本機已將完整專案上傳至 $TARGET_DIR，或在該目錄執行 git clone。"

cd "$TARGET_DIR"

echo "啟動 docker compose..."
docker compose up -d --build

echo "執行容器內必要初始化..."
# 嘗試尋找 app 服務名稱
if docker compose ps --services | grep -q app; then
  docker compose exec app bash -lc "cd /var/www/html && composer install --no-interaction --prefer-dist && npm ci && npm run build || true && php artisan key:generate --force || true && php artisan storage:link || true && php artisan config:cache || true"
fi

echo "部署完成。請檢查: docker compose ps 與 docker compose logs -f"
