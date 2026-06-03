#!/bin/bash

# ============================================================
# ZELTAN STORE — FULL PLATFORM BOOTSTRAP
# STAGED DEPLOYMENT: HTTP → CERTBOT → HTTPS
# ============================================================
# Stage 1: Boot with HTTP-only nginx (this script)
# Stage 2: Update DuckDNS with Elastic IP from terraform output
# Stage 3: Run certbot to issue certificate
# Stage 4: Script auto-upgrades nginx to HTTPS
# ============================================================

# ============================================================
# SYSTEM UPDATE
# ============================================================

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
mkdir -p /home/ubuntu/zeltan-store/scripts

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
# STAGE 1 — HTTP-ONLY NGINX CONFIG
# Serves backend directly on port 80
# Keeps ACME challenge path ready for certbot
# ============================================================

cat > /home/ubuntu/zeltan-store/nginx/default.conf <<'EOF'
server {
    listen 80;
    server_name zeltan-store.duckdns.org;

    # ACME challenge for Let's Encrypt
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    # Proxy to backend (HTTP only at this stage)
    location / {
        proxy_pass              http://backend:5000;
        proxy_http_version      1.1;
        proxy_set_header        Host                $host;
        proxy_set_header        X-Real-IP           $remote_addr;
        proxy_set_header        X-Forwarded-For     $proxy_add_x_forwarded_for;
        proxy_set_header        X-Forwarded-Proto   $scheme;
    }
}
EOF

# ============================================================
# STAGE 4 — HTTPS NGINX CONFIG (written now, applied later)
# Run enable-https.sh after certificate is issued
# ============================================================

cat > /home/ubuntu/zeltan-store/nginx/default-https.conf <<'EOF'
server {
    listen 80;
    server_name zeltan-store.duckdns.org;

    # ACME challenge kept for future renewals
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    # Redirect all HTTP to HTTPS
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
# STAGE 3+4 HELPER SCRIPT — enable-https.sh
# Run this AFTER certbot issues the certificate:
#   sudo /home/ubuntu/zeltan-store/scripts/enable-https.sh
# ============================================================

cat > /home/ubuntu/zeltan-store/scripts/enable-https.sh <<'SCRIPT'
#!/bin/bash

# ============================================================
# ENABLE HTTPS — Run after certbot certificate is issued
# ============================================================

STORE_DIR="/home/ubuntu/zeltan-store"

echo ">>> Checking certificate exists..."

if docker run --rm \
    -v zeltan-store_letsencrypt:/certs \
    alpine test -f /certs/live/zeltan-store.duckdns.org/fullchain.pem; then

    echo ">>> Certificate found. Enabling HTTPS nginx config..."

    cp $STORE_DIR/nginx/default-https.conf $STORE_DIR/nginx/default.conf

    cd $STORE_DIR
    docker-compose restart nginx

    echo ""
    echo ">>> Waiting 3 seconds for nginx to reload..."
    sleep 3

    echo ">>> Testing HTTPS locally..."
    curl -sk https://localhost | head -c 200

    echo ""
    echo ">>> HTTPS enabled successfully!"
    echo ">>> Visit: https://zeltan-store.duckdns.org"

else
    echo ">>> ERROR: Certificate not found!"
    echo ">>> Run first: docker-compose run --rm certbot"
    echo ">>> Then re-run this script."
    exit 1
fi
SCRIPT

chmod +x /home/ubuntu/zeltan-store/scripts/enable-https.sh

# ============================================================
# CERTIFICATE RENEWAL SCRIPT — renew-certs.sh
# Runs certbot renew + reloads nginx if certificate updated
# ============================================================

cat > /home/ubuntu/zeltan-store/scripts/renew-certs.sh <<'SCRIPT'
#!/bin/bash

# ============================================================
# CERTIFICATE RENEWAL + NGINX RELOAD
# Scheduled via cron — runs twice daily
# ============================================================

STORE_DIR="/home/ubuntu/zeltan-store"
LOGFILE="/var/log/zeltan-certbot-renewal.log"

echo "---------------------------------------------" >> $LOGFILE
echo "Renewal check: $(date)" >> $LOGFILE

# Run certbot renew inside a one-off container
docker run --rm \
    -v zeltan-store_letsencrypt:/etc/letsencrypt \
    -v zeltan-store_certbot-webroot:/var/www/certbot \
    certbot/certbot:latest renew --quiet 2>> $LOGFILE

RENEWAL_EXIT=$?

if [ $RENEWAL_EXIT -eq 0 ]; then
    echo "Certbot renew succeeded. Reloading nginx..." >> $LOGFILE

    # Reload nginx gracefully (no downtime)
    docker exec zeltan-nginx nginx -s reload >> $LOGFILE 2>&1

    echo "Nginx reloaded." >> $LOGFILE
else
    echo "Certbot renew failed with exit code $RENEWAL_EXIT" >> $LOGFILE
fi

echo "---------------------------------------------" >> $LOGFILE
SCRIPT

chmod +x /home/ubuntu/zeltan-store/scripts/renew-certs.sh

# ============================================================
# HEALTH CHECK SCRIPT — health-check.sh
# Verifies backend, nginx HTTP, and nginx HTTPS are all alive
# ============================================================

cat > /home/ubuntu/zeltan-store/scripts/health-check.sh <<'SCRIPT'
#!/bin/bash

# ============================================================
# PLATFORM HEALTH CHECK
# Run manually or via cron
# ============================================================

STORE_DIR="/home/ubuntu/zeltan-store"
LOGFILE="/var/log/zeltan-health.log"
PASS=0
FAIL=0

log() {
    echo "$1" | tee -a $LOGFILE
}

log ""
log "============================================="
log "Health Check: $(date)"
log "============================================="

# --- Check 1: Backend container running ---
if docker ps --format '{{.Names}}' | grep -q "zeltan-backend"; then
    log ">>> [PASS] Backend container: running"
    PASS=$((PASS+1))
else
    log ">>> [FAIL] Backend container: not running"
    FAIL=$((FAIL+1))
fi

# --- Check 2: Nginx container running ---
if docker ps --format '{{.Names}}' | grep -q "zeltan-nginx"; then
    log ">>> [PASS] Nginx container: running"
    PASS=$((PASS+1))
else
    log ">>> [FAIL] Nginx container: not running"
    FAIL=$((FAIL+1))
fi

# --- Check 3: Backend API response ---
BACKEND_RESPONSE=$(docker exec zeltan-nginx wget -qO- http://backend:5000 2>/dev/null)
if echo "$BACKEND_RESPONSE" | grep -q "Zeltan Store API Running"; then
    log ">>> [PASS] Backend API: responding"
    PASS=$((PASS+1))
else
    log ">>> [FAIL] Backend API: not responding"
    FAIL=$((FAIL+1))
fi

# --- Check 4: HTTPS endpoint ---
HTTPS_RESPONSE=$(curl -sk https://localhost 2>/dev/null)
if echo "$HTTPS_RESPONSE" | grep -q "Zeltan Store API Running"; then
    log ">>> [PASS] HTTPS endpoint: responding"
    PASS=$((PASS+1))
else
    log ">>> [WARN] HTTPS endpoint: not responding (expected if HTTPS not yet enabled)"
fi

# --- Check 5: Certificate expiry ---
EXPIRY=$(docker run --rm \
    -v zeltan-store_letsencrypt:/certs \
    alpine sh -c "cat /certs/live/zeltan-store.duckdns.org/cert.pem 2>/dev/null" \
    | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)

if [ -n "$EXPIRY" ]; then
    log ">>> [PASS] Certificate expiry: $EXPIRY"
    PASS=$((PASS+1))
else
    log ">>> [WARN] Certificate: not yet issued"
fi

log ""
log "Result: $PASS passed, $FAIL failed"
log "============================================="
SCRIPT

chmod +x /home/ubuntu/zeltan-store/scripts/health-check.sh

# ============================================================
# CRON JOBS — Certificate renewal + Health checks
# ============================================================

# Write cron jobs for ubuntu user
crontab -u ubuntu - <<'CRON'
# Zeltan Store — Automated Jobs

# Certificate renewal — twice daily at 03:00 and 15:00
0 3  * * * /home/ubuntu/zeltan-store/scripts/renew-certs.sh
0 15 * * * /home/ubuntu/zeltan-store/scripts/renew-certs.sh

# Health check — every 5 minutes
*/5 * * * * /home/ubuntu/zeltan-store/scripts/health-check.sh
CRON

# ============================================================
# SET PERMISSIONS
# ============================================================

chown -R ubuntu:ubuntu /home/ubuntu/zeltan-store

# ============================================================
# STAGE 1 — START PLATFORM (HTTP only)
# ============================================================

cd /home/ubuntu/zeltan-store
docker-compose up -d

# ============================================================
# DEPLOYMENT STAGES REMINDER
# Written to /home/ubuntu/DEPLOYMENT.md
# ============================================================

cat > /home/ubuntu/DEPLOYMENT.md <<'EOF'
# Zeltan Store — Deployment Stages

## Stage 1 — DONE (this boot)
- Docker installed
- Backend running
- HTTP nginx running on port 80
- Certbot ready (not yet run)
- Renewal cron scheduled (03:00 + 15:00 daily)
- Health check cron scheduled (every 5 minutes)

## Stage 2 — Update DuckDNS
Get Elastic IP from Terraform output:
    terraform output elastic_ip

Update DuckDNS to point to that IP.

Verify HTTP works:
    curl http://zeltan-store.duckdns.org

Expected: {"status":"ok","message":"Zeltan Store API Running"}

## Stage 3 — Issue Certificate
    cd /home/ubuntu/zeltan-store
    docker-compose run --rm certbot

Expected: Certificate issued successfully.

## Stage 4 — Enable HTTPS
    sudo /home/ubuntu/zeltan-store/scripts/enable-https.sh

Expected: HTTPS working at https://zeltan-store.duckdns.org

## Ongoing — Automated Jobs
Certificate renewal:  /var/log/zeltan-certbot-renewal.log
Health checks:        /var/log/zeltan-health.log

Manual health check:
    /home/ubuntu/zeltan-store/scripts/health-check.sh

Manual renewal:
    /home/ubuntu/zeltan-store/scripts/renew-certs.sh
EOF