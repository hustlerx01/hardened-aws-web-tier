#!/bin/bash
# Amazon Linux 2023: install Nginx as a reverse proxy in front of a tiny local app.
set -euo pipefail
dnf -y update --security
dnf -y install nginx python3

# Tiny upstream app on localhost only (stands in for the real app).
mkdir -p /opt/app && cat > /opt/app/index.html <<HTML
<h1>${project}</h1><p>served via nginx reverse proxy from a private subnet</p>
HTML
cat > /etc/systemd/system/upstream.service <<UNIT
[Unit]
Description=Local upstream app
After=network.target
[Service]
ExecStart=/usr/bin/python3 -m http.server 8080 --bind 127.0.0.1 --directory /opt/app
User=nobody
Restart=always
[Install]
WantedBy=multi-user.target
UNIT

cat > /etc/nginx/conf.d/app.conf <<'NGINX'
server_tokens off;
limit_req_zone $binary_remote_addr zone=perip:10m rate=10r/s;
server {
    listen 80 default_server;
    client_max_body_size 1m;
    add_header X-Content-Type-Options nosniff always;
    add_header X-Frame-Options DENY always;
    add_header Referrer-Policy no-referrer always;
    location = /healthz { access_log off; return 200 "ok\n"; }
    location / {
        limit_req zone=perip burst=20 nodelay;
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $http_x_forwarded_proto;
    }
}
NGINX
# drop the default server block so ours is the only default
sed -i '/^\s*server\s*{/,/^\s*}/d' /etc/nginx/nginx.conf || true
systemctl daemon-reload
systemctl enable --now upstream nginx
