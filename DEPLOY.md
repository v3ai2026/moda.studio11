# moda.STUDIO 部署指南（域名：mdio.shop�?
## 前置条件
- 已安�?PHP（建�?8.2+）、Composer�?- 数据库：MySQL/MariaDB（推荐快速上线）�?Postgres（需迁移）�?- Web 服务器根目录需指向 `server/public`�?
## 环境变量（Laravel `.env`�?�?`server` 目录下创�?`.env`（可参考下方示例或使用 `/.env.mdio.example`）：

```
APP_ENV=production
APP_DEBUG=false
APP_URL=https://modamoda.shop
SESSION_DOMAIN=mdiomodamoda.shop
SANCTUM_STATEFUL_DOMAINS=modamoda.shop

# 推荐：MySQL/MariaDB（与 moda.STUDIO.sql 完全兼容�?DB_CONNECTION=mysql
DB_HOST=<your-mysql-host>
DB_PORT=3306
DB_DATABASE=<modamoda>
DB_USERNAME=<modamoda>
DB_PASSWORD=<modamoda>

# 如选择 Postgres/Neon（需完成架构迁移后再启用�?# DB_CONNECTION=pgsql
# DB_HOST=<your-neon-host>
# DB_PORT=5432
# DB_DATABASE=<your-db-name>
# DB_USERNAME=<your-db-user>
# DB_PASSWORD=<your-db-pass>
# DB_SSLMODE=require
```

## 初始化与启动（Windows 示例�?```
cd "C:\Users\1\Downloads\moda.STUDIO v9.9\moda.STUDIO v9.9\server"
composer install
php artisan key:generate
php artisan storage:link

# 方式一：直接导入提供的 MySQL 脚本（推荐）
mysql -u <user> -p -h <host> -P 3306 < "C:\Users\1\Downloads\moda.STUDIO v9.9\moda.STUDIO v9.9\moda.STUDIO.sql"

# 方式二：若改用迁移（需确认迁移脚本与兼容性）
# php artisan migrate --force

php artisan config:cache
php artisan route:cache
php artisan view:cache
php artisan serve
```

## Web 服务器（Nginx 参考片段）
```
server {
  listen 80;
  server_name mdio.shop;
  root /var/www/moda.STUDIO/server/public;

  index index.php;
  location / {
    try_files $uri $uri/ /index.php?$query_string;
  }
  location ~ \.php$ {
    include fastcgi_params;
    fastcgi_pass unix:/run/php/php8.2-fpm.sock; # 按实际版本调�?    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
  }
}
```

## 注意事项
- 切勿将真实数据库凭据提交�?Git；请使用部署平台的密钥管理（环境变量/Secrets）�?- 若你已在沟通中暴露数据库密码，建议立即在数据库后台旋转/重置密码�?- Postgres/Neon 方案需�?`moda.STUDIO.sql` 进行 DDL/数据转换，并修正不兼容查询；完成后才切换�?`pgsql` 驱动�?
