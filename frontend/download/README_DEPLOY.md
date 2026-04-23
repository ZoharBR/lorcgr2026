# LOR-CGR Deployment Files

This folder contains all the files needed to deploy the LOR-CGR application.

## Files

| File | Description |
|------|-------------|
| `deploy_nextjs.sh` | Deployment script to run locally (uploads build to server) |
| `setup_server.sh` | Server setup script (run on the server) |
| `lorcgr-frontend.service` | Systemd service file |
| `nginx-lorcgr.conf` | Nginx configuration |
| `Caddyfile-production` | Caddy configuration |
| `DEPLOYMENT_GUIDE.md` | Complete deployment guide |

## Quick Start

### Option 1: Automated Deployment

1. Build the project locally:
```bash
cd /home/z/my-project
bun run build
```

2. Run the deployment script:
```bash
bash download/deploy_nextjs.sh 45.71.242.131 root
```

3. On the server, run the setup script:
```bash
ssh root@45.71.242.131
bash /opt/lorcgr-frontend/setup_server.sh
# or copy setup_server.sh to the server first
```

### Option 2: Manual Deployment

1. Build the project locally
2. Copy files to server:
```bash
# Create directories on server
ssh root@45.71.242.131 "mkdir -p /opt/lorcgr-frontend/{.next/static,public}"

# Copy files
scp -r .next/standalone/* root@45.71.242.131:/opt/lorcgr-frontend/
scp -r .next/static/* root@45.71.242.131:/opt/lorcgr-frontend/.next/static/
scp -r public/* root@45.71.242.131:/opt/lorcgr-frontend/public/
```

3. Configure the server:
```bash
# Copy service file
scp download/lorcgr-frontend.service root@45.71.242.131:/etc/systemd/system/

# Copy nginx config
scp download/nginx-lorcgr.conf root@45.71.242.131:/etc/nginx/sites-available/lorcgr

# On server
ssh root@45.71.242.131
ln -s /etc/nginx/sites-available/lorcgr /etc/nginx/sites-enabled/
systemctl daemon-reload
systemctl enable lorcgr-frontend
systemctl start lorcgr-frontend
systemctl reload nginx
```

## Troubleshooting 404 Errors

If you're getting 404 errors for static files:

1. Check if static files exist:
```bash
ls -la /opt/lorcgr-frontend/.next/static/
```

2. Check file permissions:
```bash
chown -R www-data:www-data /opt/lorcgr-frontend
chmod -R 755 /opt/lorcgr-frontend
```

3. Check nginx configuration:
```bash
nginx -t
```

4. Check service status:
```bash
systemctl status lorcgr-frontend
journalctl -u lorcgr-frontend -n 50
```
