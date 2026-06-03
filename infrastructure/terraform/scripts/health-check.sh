cat > /e/Devops-Zelt-Projects/zeltan-store/infrastructure/terraform/scripts/health-check.sh << 'EOF'
#!/bin/bash

# ============================================================
# PLATFORM HEALTH CHECK
# ============================================================

LOGFILE="/var/log/zeltan-health.log"
PASS=0
FAIL=0

log() { echo "$1" | tee -a $LOGFILE; }

log ""
log "============================================="
log "Health Check: $(date)"
log "============================================="

# Check 1: Backend container
if docker ps --format '{{.Names}}' | grep -q "zeltan-backend"; then
    log ">>> [PASS] Backend container: running"; PASS=$((PASS+1))
else
    log ">>> [FAIL] Backend container: not running"; FAIL=$((FAIL+1))
fi

# Check 2: Nginx container
if docker ps --format '{{.Names}}' | grep -q "zeltan-nginx"; then
    log ">>> [PASS] Nginx container: running"; PASS=$((PASS+1))
else
    log ">>> [FAIL] Nginx container: not running"; FAIL=$((FAIL+1))
fi

# Check 3: Backend API
BACKEND_RESPONSE=$(docker exec zeltan-nginx wget -qO- http://backend:5000 2>/dev/null)
if echo "$BACKEND_RESPONSE" | grep -q "Zeltan Store API Running"; then
    log ">>> [PASS] Backend API: responding"; PASS=$((PASS+1))
else
    log ">>> [FAIL] Backend API: not responding"; FAIL=$((FAIL+1))
fi

# Check 4: HTTPS endpoint
HTTPS_RESPONSE=$(curl -sk https://localhost 2>/dev/null)
if echo "$HTTPS_RESPONSE" | grep -q "Zeltan Store API Running"; then
    log ">>> [PASS] HTTPS endpoint: responding"; PASS=$((PASS+1))
else
    log ">>> [WARN] HTTPS endpoint: not responding"
fi

# Check 5: Certificate expiry
EXPIRY=$(docker run --rm \
    -v zeltan-store_letsencrypt:/certs \
    alpine sh -c "cat /certs/live/zeltan-store.duckdns.org/cert.pem 2>/dev/null" \
    | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)

if [ -n "$EXPIRY" ]; then
    log ">>> [PASS] Certificate expiry: $EXPIRY"; PASS=$((PASS+1))
else
    log ">>> [WARN] Certificate: not yet issued"
fi

log ""
log "Result: $PASS passed, $FAIL failed"
log "============================================="
EOF