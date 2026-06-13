#!/bin/bash

# ============================================================
# ZELTAN STORE — FULL PLATFORM BOOTSTRAP
# STAGED DEPLOYMENT: HTTP → CERTBOT → HTTPS
# INCLUDES: Docker Compose + k3s Kubernetes
# ============================================================
# Stage 1: Boot with HTTP-only nginx + k3s installed
# Stage 2: Update DuckDNS with Elastic IP
# Stage 3: Run certbot to issue certificate
# Stage 4: Enable HTTPS nginx config
# ============================================================

set -e
exec > /var/log/userdata.log 2>&1
echo "Bootstrap started: $(date)"

# ============================================================
# SYSTEM UPDATE
# ============================================================

apt-get update -y
apt-get upgrade -y

# ============================================================
# INSTALL REQUIRED PACKAGES
# ============================================================

apt-get install -y \
    curl \
    wget \
    unzip \
    openssl \
    ca-certificates \
    gnupg \
    lsb-release

# ============================================================
# SWAP — 2GB
# Required for running Docker Compose + k3s on t3.small
# Without swap memory pressure causes k3s API timeouts
# ============================================================

fallocate -l 2G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab

echo "Swap configured: $(free -h)"

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

echo "Docker Compose installed: $(docker-compose --version)"

# ============================================================
# CREATE APPLICATION DIRECTORIES
# ============================================================

mkdir -p /home/ubuntu/zeltan-store/nginx
mkdir -p /home/ubuntu/zeltan-store/scripts
mkdir -p /home/ubuntu/zeltan-k8s

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
# ============================================================

cat > /home/ubuntu/zeltan-store/nginx/default.conf <<'EOF'
server {
    listen 80;
    server_name zeltan-store.duckdns.org;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

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
# ============================================================

cat > /home/ubuntu/zeltan-store/nginx/default-https.conf <<'EOF'
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
    listen 443 ssl;
    http2 on;
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
# ENABLE HTTPS SCRIPT
# ============================================================

cat > /home/ubuntu/zeltan-store/scripts/enable-https.sh <<'SCRIPT'
#!/bin/bash

STORE_DIR="/home/ubuntu/zeltan-store"

echo ">>> Checking certificate exists..."

if docker run --rm \
    -v zeltan-store_letsencrypt:/certs \
    alpine test -f /certs/live/zeltan-store.duckdns.org/fullchain.pem; then

    echo ">>> Certificate found. Enabling HTTPS nginx config..."
    cp $STORE_DIR/nginx/default-https.conf $STORE_DIR/nginx/default.conf

    cd $STORE_DIR
    docker-compose restart nginx

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
    exit 1
fi
SCRIPT

chmod +x /home/ubuntu/zeltan-store/scripts/enable-https.sh

# ============================================================
# CERTIFICATE RENEWAL SCRIPT
# ============================================================

cat > /home/ubuntu/zeltan-store/scripts/renew-certs.sh <<'SCRIPT'
#!/bin/bash

LOGFILE="/var/log/zeltan-certbot-renewal.log"

echo "---------------------------------------------" >> $LOGFILE
echo "Renewal check: $(date)" >> $LOGFILE

docker run --rm \
    -v zeltan-store_letsencrypt:/etc/letsencrypt \
    -v zeltan-store_certbot-webroot:/var/www/certbot \
    certbot/certbot:latest renew --quiet 2>> $LOGFILE

RENEWAL_EXIT=$?

if [ $RENEWAL_EXIT -eq 0 ]; then
    echo "Certbot renew succeeded. Reloading nginx..." >> $LOGFILE
    docker exec zeltan-nginx nginx -s reload >> $LOGFILE 2>&1
    echo "Nginx reloaded." >> $LOGFILE
else
    echo "Certbot renew failed with exit code $RENEWAL_EXIT" >> $LOGFILE
fi

echo "---------------------------------------------" >> $LOGFILE
SCRIPT

chmod +x /home/ubuntu/zeltan-store/scripts/renew-certs.sh

# ============================================================
# HEALTH CHECK SCRIPT
# ============================================================

cat > /home/ubuntu/zeltan-store/scripts/health-check.sh <<'SCRIPT'
#!/bin/bash

LOGFILE="/var/log/zeltan-health.log"
PASS=0
FAIL=0

log() { echo "$1" | tee -a $LOGFILE; }

log ""
log "============================================="
log "Health Check: $(date)"
log "============================================="

if docker ps --format '{{.Names}}' | grep -q "zeltan-backend"; then
    log ">>> [PASS] Backend container: running"; PASS=$((PASS+1))
else
    log ">>> [FAIL] Backend container: not running"; FAIL=$((FAIL+1))
fi

if docker ps --format '{{.Names}}' | grep -q "zeltan-nginx"; then
    log ">>> [PASS] Nginx container: running"; PASS=$((PASS+1))
else
    log ">>> [FAIL] Nginx container: not running"; FAIL=$((FAIL+1))
fi

BACKEND_RESPONSE=$(docker exec zeltan-nginx wget -qO- http://backend:5000 2>/dev/null)
if echo "$BACKEND_RESPONSE" | grep -q "Zeltan Store API Running"; then
    log ">>> [PASS] Backend API: responding"; PASS=$((PASS+1))
else
    log ">>> [FAIL] Backend API: not responding"; FAIL=$((FAIL+1))
fi

HTTPS_RESPONSE=$(curl -sk https://localhost 2>/dev/null)
if echo "$HTTPS_RESPONSE" | grep -q "Zeltan Store API Running"; then
    log ">>> [PASS] HTTPS endpoint: responding"; PASS=$((PASS+1))
else
    log ">>> [WARN] HTTPS endpoint: not responding"
fi

EXPIRY=$(docker run --rm \
    -v zeltan-store_letsencrypt:/certs \
    alpine sh -c "cat /certs/live/zeltan-store.duckdns.org/cert.pem 2>/dev/null" \
    | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)

if [ -n "$EXPIRY" ]; then
    log ">>> [PASS] Certificate expiry: $EXPIRY"; PASS=$((PASS+1))
else
    log ">>> [WARN] Certificate: not yet issued"
fi

# --- Check 6: k3s status ---
if systemctl is-active --quiet k3s; then
    log ">>> [PASS] k3s Kubernetes: running"; PASS=$((PASS+1))
else
    log ">>> [WARN] k3s Kubernetes: not running"
fi

# --- Check 7: kubectl node ready ---
NODE_STATUS=$(kubectl get nodes --no-headers 2>/dev/null | awk '{print $2}')
if echo "$NODE_STATUS" | grep -q "Ready"; then
    log ">>> [PASS] Kubernetes node: Ready"; PASS=$((PASS+1))
else
    log ">>> [WARN] Kubernetes node: not Ready yet"
fi

log ""
log "Result: $PASS passed, $FAIL failed"
log "============================================="
SCRIPT

chmod +x /home/ubuntu/zeltan-store/scripts/health-check.sh

# ============================================================
# CREATE LOG FILES WITH CORRECT PERMISSIONS
# ============================================================

touch /var/log/zeltan-health.log
touch /var/log/zeltan-certbot-renewal.log
chown ubuntu:ubuntu /var/log/zeltan-health.log
chown ubuntu:ubuntu /var/log/zeltan-certbot-renewal.log

# ============================================================
# CRON JOBS
# ============================================================

crontab -u ubuntu - <<'CRON'
# Zeltan Store — Automated Jobs

# Certificate renewal — twice daily
0 3  * * * /home/ubuntu/zeltan-store/scripts/renew-certs.sh
0 15 * * * /home/ubuntu/zeltan-store/scripts/renew-certs.sh

# Health check — every 5 minutes
*/5 * * * * /home/ubuntu/zeltan-store/scripts/health-check.sh
CRON

# ============================================================
# SET PERMISSIONS
# ============================================================

chown -R ubuntu:ubuntu /home/ubuntu/zeltan-store
chown -R ubuntu:ubuntu /home/ubuntu/zeltan-k8s

# ============================================================
# STAGE 1 — START DOCKER COMPOSE (HTTP only)
# ============================================================

cd /home/ubuntu/zeltan-store
docker-compose up -d

echo "Docker Compose started: $(date)"

# ============================================================
# INSTALL k3s — LIGHTWEIGHT KUBERNETES
# Installed AFTER Docker Compose to ensure production
# is running before Kubernetes initialization begins
# Traefik disabled — nginx handles all ingress
# ============================================================

echo "Installing k3s: $(date)"

# Create k3s config — disable traefik (nginx handles routing)
mkdir -p /etc/rancher/k3s
cat > /etc/rancher/k3s/config.yaml <<'EOF'
disable:
  - traefik
write-kubeconfig-mode: "0644"
EOF

# Install k3s
curl -sfL https://get.k3s.io | sh -

# Wait for k3s to be fully ready
echo "Waiting for k3s to be ready..."
sleep 30

# Verify k3s started
systemctl is-active k3s && echo "k3s is running" || echo "k3s failed to start"

# ============================================================
# CONFIGURE KUBECTL FOR UBUNTU USER
# ============================================================

mkdir -p /home/ubuntu/.kube
cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config
chown ubuntu:ubuntu /home/ubuntu/.kube/config
chmod 600 /home/ubuntu/.kube/config

# Add KUBECONFIG to ubuntu user profile — persists across sessions
echo 'export KUBECONFIG=~/.kube/config' >> /home/ubuntu/.bashrc
echo 'export KUBECONFIG=~/.kube/config' >> /home/ubuntu/.profile

# ============================================================
# CREATE KUBERNETES MANIFESTS FOR ZELTAN STORE
# Pre-written and ready — apply after certbot issues certificate
# ============================================================

# --- Namespace ---
cat > /home/ubuntu/zeltan-k8s/namespace.yaml <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: zeltan-store
  labels:
    project: zeltan-store
    environment: production
EOF

# --- Backend Deployment ---
cat > /home/ubuntu/zeltan-k8s/backend-deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: zeltan-backend
  namespace: zeltan-store
  labels:
    app: zeltan-backend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: zeltan-backend
  template:
    metadata:
      labels:
        app: zeltan-backend
    spec:
      containers:
        - name: zeltan-backend
          image: mabms/zeltan-store-backend:latest
          ports:
            - containerPort: 5000
          env:
            - name: PORT
              value: "5000"
            - name: JWT_SECRET
              value: "zeltan_super_secret_key_2024"
            - name: MONGO_URI
              value: "mongodb+srv://zeltan-store1.yb0zerd.mongodb.net/zeltanDB?authSource=%24external&authMechanism=MONGODB-AWS"
          resources:
            requests:
              memory: "128Mi"
              cpu: "100m"
            limits:
              memory: "256Mi"
              cpu: "250m"
          livenessProbe:
            tcpSocket:
              port: 5000
            initialDelaySeconds: 60
            periodSeconds: 60
            failureThreshold: 10
          readinessProbe:
            tcpSocket:
              port: 5000
            initialDelaySeconds: 15
            periodSeconds: 30
            failureThreshold: 5
EOF

# --- Backend Service ---
cat > /home/ubuntu/zeltan-k8s/backend-service.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: zeltan-backend
  namespace: zeltan-store
  labels:
    app: zeltan-backend
spec:
  selector:
    app: zeltan-backend
  ports:
    - protocol: TCP
      port: 5000
      targetPort: 5000
  type: ClusterIP
EOF

# --- Ingress ---
cat > /home/ubuntu/zeltan-k8s/ingress.yaml <<'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: zeltan-ingress
  namespace: zeltan-store
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - zeltan-store.duckdns.org
      secretName: zeltan-tls
  rules:
    - host: zeltan-store.duckdns.org
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: zeltan-backend
                port:
                  number: 5000
EOF

chown -R ubuntu:ubuntu /home/ubuntu/zeltan-k8s

# ============================================================
# DEPLOYMENT GUIDE
# ============================================================

cat > /home/ubuntu/DEPLOYMENT.md <<'EOF'
# Zeltan Store — Deployment Guide

## Architecture
- Docker Compose: production serving on port 80/443
- k3s Kubernetes: learning + future migration platform

## Stage 1 — DONE (this boot)
- Docker + Docker Compose installed
- Backend running (HTTP nginx on port 80)
- k3s installed (Traefik disabled)
- kubectl configured for ubuntu user
- All Kubernetes manifests pre-written at ~/zeltan-k8s/
- Swap: 2GB configured
- Cron: renewal 03:00+15:00, health check every 5min

## Stage 2 — Update DuckDNS
    terraform output elastic_ip
    # Update DuckDNS with that IP
    curl http://zeltan-store.duckdns.org
    # Expected: {"status":"ok","message":"Zeltan Store API Running"}

## Stage 3 — Issue Certificate
    cd /home/ubuntu/zeltan-store
    docker-compose run --rm certbot

## Stage 4 — Enable HTTPS
    sudo /home/ubuntu/zeltan-store/scripts/enable-https.sh

## Stage 5 — Verify k3s
    kubectl get nodes
    kubectl get pods -A

## Stage 6 — Deploy to Kubernetes
    kubectl apply -f ~/zeltan-k8s/namespace.yaml
    kubectl apply -f ~/zeltan-k8s/backend-deployment.yaml
    kubectl apply -f ~/zeltan-k8s/backend-service.yaml

## Stage 7 — Install Ingress Controller
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.0/deploy/static/provider/cloud/deploy.yaml
    kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s

## Stage 8 — Create TLS Secret and Apply Ingress
    sudo cp /var/lib/docker/volumes/zeltan-store_letsencrypt/_data/live/zeltan-store.duckdns.org/fullchain.pem /tmp/
    sudo cp /var/lib/docker/volumes/zeltan-store_letsencrypt/_data/live/zeltan-store.duckdns.org/privkey.pem /tmp/
    sudo chown ubuntu:ubuntu /tmp/fullchain.pem /tmp/privkey.pem
    kubectl create secret tls zeltan-tls --cert=/tmp/fullchain.pem --key=/tmp/privkey.pem -n zeltan-store
    kubectl apply -f ~/zeltan-k8s/ingress.yaml

## Stage 9 — Verify Full Stack
    curl https://zeltan-store.duckdns.org/
    kubectl get pods -n zeltan-store
    kubectl get ingress -n zeltan-store

## Log Files
    /var/log/userdata.log          — bootstrap log
    /var/log/zeltan-health.log     — health checks
    /var/log/zeltan-certbot-renewal.log — cert renewal
EOF

echo "Bootstrap completed: $(date)"