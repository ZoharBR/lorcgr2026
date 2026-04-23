#!/bin/bash
# Deploy script for Dashboard and GBIC API fix
# Run on server: bash /tmp/deploy_dashboard.sh

cd /opt/lorcgr

# Backup current files
cp devices/gbic_api.py devices/gbic_api.py.bak 2>/dev/null
cp frontend/src/components/Dashboard.js frontend/src/components/Dashboard.js.bak 2>/dev/null

echo "Files backed up. Now copy the new files manually or use scp."
