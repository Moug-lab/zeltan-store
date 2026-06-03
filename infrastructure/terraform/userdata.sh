#!/bin/bash

# ============================================================
# ZELTAN STORE — FULL PLATFORM BOOTSTRAP
# ============================================================

# Update system
apt-get update -y

# ============================================================
# INSTALL DOCKER
# ============================================================

apt-get install -y docker.io
systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu

# ============================================================
# INSTALL DOCKER COMPOSE
# ============================================================

curl -SL https://github.com/docker/compose/releases/download/v2.39.1/docker-compose-linux-x86_64 \
    -o /usr/local/bin/docker-compose

chmod +x /usr/local/bin/docker-compose
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

# ============================================================
# CREATE APPLICATION DIRECTORIES
# ============================================================

mkdir -p /home/ubuntu/zeltan-store/nginx

# ============================================================
# CREATE DOCKER COMPOSE FILE
# ============================================================

cat > /home/ubuntu/zeltan-store/docker-compose.yml <<'EOF'
services:

  backend:
    image: mabms/zeltan-store-backend:latest
    container_name: zeltan-backend
    restart: always
    expose:
      - "5000"
    environment:
      PORT: 5000
      JWT_SECRET: zeltan_super_secret_key_2024
      MONGO_URI: mongodb+srv://zeltan-store1.yb0zerd.mongodb.net/zeltanDB?authSource=%24external&authMechanism=MONGODB-AWS

  nginx:
    image: nginx:stable-alpine
    container_name: zeltan-nginx
    restart: always
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf
      - letsencrypt:/etc/letsencrypt
      - certbot-webroot:/var/www/certbot
    depends_on:
      - backend

  certbot:
    image: certbot/certbot:latest
    container_name: zeltan-certbot
    restart: "no"
    volumes:
      - letsencrypt:/etc/letsencrypt
      - certbot-webroot:/var/www/certbot
    command:
      - certonly
      - --webroot
      - --webroot-path=/var/www/certbot
      - --email
      - mabms2024@hotmail.com
      - --agree-tos
      - --no-eff-email
      - --non-interactive
      - -d
      - zeltan-store.duckdns.org

volumes:
  letsencrypt:
  certbot-webroot:
EOF

# ============================================================
# CREATE NGINX CONFIG
# ============================================================

cat > /home/ubuntu/zeltan-store/nginx/default.conf <<'EOF'
server {
    listen 80;
    server_name zeltan-store.duckdns.org;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name zeltan-store.duckdns.org;

    ssl_certificate     /etc/letsencrypt/live/zeltan-store.duckdns.org/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/zeltan-store.duckdns.org/privkey.pem;

    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;

    location / {
        proxy_pass              http://backend:5000;
        proxy_http_version      1.1;
        proxy_set_header        Upgrade             $http_upgrade;
        proxy_set_header        Connection          "upgrade";
        proxy_set_header        Host                $host;
        proxy_set_header        X-Real-IP           $remote_addr;
        proxy_set_header        X-Forwarded-For     $proxy_add_x_forwarded_for;
        proxy_set_header        X-Forwarded-Proto   $scheme;
    }
}
EOF

# ============================================================
# SET PERMISSIONS
# ============================================================

chown -R ubuntu:ubuntu /home/ubuntu/zeltan-store

# ============================================================
# START PLATFORM
# ============================================================

cd /home/ubuntu/zeltan-store
docker-compose up -d