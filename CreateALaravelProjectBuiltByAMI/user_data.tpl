#!/bin/bash
cat >> /home/ubuntu/laravel/.env <<EOF

DB_CONNECTION=mysql
DB_HOST=db.lynn.demo
DB_PORT=3306
DB_DATABASE=todo
DB_USERNAME=root
DB_PASSWORD=password

IMAGE_S3_BUCKET=tf-s3-laravel-demo-project
IMAGE_DOMAIN=${image_domain}
EOF
php /home/ubuntu/laravel/artisan migrate
