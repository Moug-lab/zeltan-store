cat > /e/Devops-Zelt-Projects/zeltan-store/infrastructure/terraform/scripts/renew-certs.sh << 'EOF'
#!/bin/bash

# ============================================================
# CERTIFICATE RENEWAL + NGINX RELOAD
# Scheduled via cron — runs twice daily
# ============================================================

STORE_DIR="/home/ubuntu/zeltan-store"
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
EOF