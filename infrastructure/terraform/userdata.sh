#!/bin/bash

# ============================================================
# ZELTAN STORE — FULL PLATFORM BOOTSTRAP
# ============================================================

# Update Linux
apt-get update -y

# Install Docker
apt-get install -y docker.io

# Enable and start Docker
systemctl enable docker
systemctl start docker

# Add ubuntu user to docker group
usermod -aG docker ubuntu

# ============================================================
# INSTALL DOCKER COMPOSE
# ============================================================

curl -SL https://github.com/docker/compose/releases/download/v2.39.1/docker-compose-linux-x86_64 \
    -o /usr/local/bin/docker-compose

chmod +x /usr/local/bin/docker-compose
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

# Create application directories
mkdir -p /home/ubuntu/zeltan-store/nginx

# ============================================================
# CREATE DOCKER COMPOSE FILE
# ============================================================

cat > /home/ubuntu/zeltan-store/docker-compose.yml <<EOF
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
    volumes:
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
    depends_on:
      - backend
EOF

# ============================================================
# CREATE NGINX CONFIG
# ============================================================

cat > /home/ubuntu/zeltan-store/nginx/default.conf <<EOF
# ============================================================
# HTTP → HTTPS REDIRECT
# ============================================================

server {
    listen 80;
    server_name zeltan-store.duckdns.org;
    return 301 https://\$host\$request_uri;
}

# ============================================================
# HTTPS SERVER
# ============================================================

server {
    listen 443 ssl;
    server_name zeltan-store.duckdns.org;

    ssl_certificate     /etc/nginx/certs/fullchain.pem;
    ssl_certificate_key /etc/nginx/certs/privkey.pem;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;

    # ========================================================
    # SECURITY HEADERS
    # ========================================================

    add_header X-Frame-Options         SAMEORIGIN;
    add_header X-Content-Type-Options  nosniff;
    add_header X-XSS-Protection        "1; mode=block";
    add_header Referrer-Policy         no-referrer-when-downgrade;

    # ========================================================
    # REVERSE PROXY
    # ========================================================

    location / {
        proxy_pass              http://backend:5000;
        proxy_http_version      1.1;
        proxy_set_header        Upgrade            \$http_upgrade;
        proxy_set_header        Connection         "upgrade";
        proxy_set_header        Host               \$host;
        proxy_set_header        X-Real-IP          \$remote_addr;
        proxy_set_header        X-Forwarded-For    \$proxy_add_x_forwarded_for;
        proxy_set_header        X-Forwarded-Proto  \$scheme;
        proxy_cache_bypass      \$http_upgrade;
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