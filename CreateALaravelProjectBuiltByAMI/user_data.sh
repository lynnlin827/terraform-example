#!/bin/bash
apt-get install -y awscli
cat > /home/ubuntu/laravel/.env <<EOF
APP_NAME=Laravel
APP_ENV=local
APP_KEY=
APP_DEBUG=true
APP_LOG_LEVEL=error
APP_URL=http://localhost

DB_CONNECTION=mysql
DB_HOST=db.lynn.demo
DB_PORT=3306
DB_DATABASE=todo
DB_USERNAME=root
DB_PASSWORD=password

IMAGE_S3_BUCKET=tf-s3-laravel-demo-project
EOF
chown www-data:www-data /home/ubuntu/laravel/.env
php /home/ubuntu/laravel/artisan key:generate
php /home/ubuntu/laravel/artisan migrate
