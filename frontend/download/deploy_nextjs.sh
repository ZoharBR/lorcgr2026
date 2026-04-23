#!/bin/bash
#
# LOR-CGR Next.js Frontend Deployment Script
# This script deploys the Next.js standalone build to the production server
#
# Usage: ./deploy_nextjs.sh [server_ip] [user]
# Example: ./deploy_nextjs.sh 45.71.242.131 root
#

set -e

# Configuration
SERVER_IP="${1:-45.71.242.131}"
SERVER_USER="${2:-root}"
REMOTE_PATH="/opt/lorcgr-frontend"
LOCAL_BUILD="/home/z/my-project/.next/standalone"
LOCAL_STATIC="/home/z/my-project/.next/static"
LOCAL_PUBLIC="/home/z/my-project/public"

echo "================================================"
echo "LOR-CGR Next.js Frontend Deployment"
echo "================================================"
echo "Server: ${SERVER_USER}@${SERVER_IP}"
echo "Remote Path: ${REMOTE_PATH}"
echo "================================================"

# Check if local build exists
if [ ! -d "$LOCAL_BUILD" ]; then
    echo "ERROR: Local build not found at $LOCAL_BUILD"
    echo "Please run 'bun run build' first"
    exit 1
fi

echo "[1/6] Creating deployment package..."
cd /home/z/my-project
tar -czf /tmp/lorcgr-frontend.tar.gz \
    -C .next/standalone . \
    --exclude='*.log'

echo "[2/6] Creating directories on remote server..."
ssh ${SERVER_USER}@${SERVER_IP} "mkdir -p ${REMOTE_PATH}/{.next/static,public}"

echo "[3/6] Uploading application files..."
scp /tmp/lorcgr-frontend.tar.gz ${SERVER_USER}@${SERVER_IP}:/tmp/

echo "[4/6] Extracting application on remote server..."
ssh ${SERVER_USER}@${SERVER_IP} "
    cd ${REMOTE_PATH}
    tar -xzf /tmp/lorcgr-frontend.tar.gz
    rm /tmp/lorcgr-frontend.tar.gz
"

echo "[5/6] Uploading static and public files..."
rsync -avz --delete ${LOCAL_STATIC}/ ${SERVER_USER}@${SERVER_IP}:${REMOTE_PATH}/.next/static/
rsync -avz --delete ${LOCAL_PUBLIC}/ ${SERVER_USER}@${SERVER_IP}:${REMOTE_PATH}/public/

echo "[6/6] Setting permissions and restarting service..."
ssh ${SERVER_USER}@${SERVER_IP} "
    chown -R www-data:www-data ${REMOTE_PATH}
    chmod -R 755 ${REMOTE_PATH}
    
    # Restart the service
    systemctl restart lorcgr-frontend || systemctl restart lorcgr || echo 'Service restart skipped'
    
    # Show status
    systemctl status lorcgr-frontend --no-pager || systemctl status lorcgr --no-pager || echo 'Service status check skipped'
"

echo "================================================"
echo "Deployment Complete!"
echo "================================================"
echo ""
echo "Your application should now be available at:"
echo "  http://${SERVER_IP}:3000"
echo ""
echo "If using a reverse proxy (Nginx/Caddy):"
echo "  Check /etc/nginx/sites-available/lorcgr or /etc/caddy/Caddyfile"
echo ""
