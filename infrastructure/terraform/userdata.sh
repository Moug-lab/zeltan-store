#!/bin/bash

# ============================================================
# ZELTAN STORE EC2 BOOTSTRAP
# ============================================================

# Update system
apt-get update -y

# Install Docker
apt-get install -y docker.io

# Enable Docker service
systemctl enable docker

# Start Docker
systemctl start docker

# Add ubuntu user to docker group
usermod -aG docker ubuntu

# Pull backend container image
docker pull mabms/zeltan-store-backend:latest

# Run backend container
docker run -d \
  --name zeltan-backend \
  --restart unless-stopped \
  -p 5000:5000 \
  -e PORT=5000 \
  -e NODE_ENV=production \
  -e JWT_SECRET=zeltan_super_secret_key_2024 \
  -e MONGO_URI="mongodb+srv://zeltan-store1.yb0zerd.mongodb.net/zeltanDB?authSource=%24external&authMechanism=MONGODB-AWS" \
  mabms/zeltan-store-backend:latest