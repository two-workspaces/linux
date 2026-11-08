#!/bin/bash
set -e
: "${WEB_PASSWORD:?WEB_PASSWORD is required}"

# /data is the Railway volume: empty on first boot.
mkdir -p /data/root /data/srv /data/linux/services /data/linux/logs /data/linux/apt /data/linux/ssh-host
if [ ! -f /data/root/.linux-seeded ]; then
  cp -af /opt/linux/root-image/. /data/root/
  cp -af /opt/linux/skel/. /data/root/
  touch /data/root/.linux-seeded
fi
chmod 700 /data/root
mkdir -p /data/root/.ssh && chmod 700 /data/root/.ssh

# cron refuses a spool dir with other owners or modes.
mkdir -p /data/linux/crontabs
chown root:crontab /data/linux/crontabs && chmod 1730 /data/linux/crontabs

# Persist SSH host keys so clients don't see "host key changed" after redeploys.
for t in rsa ed25519; do
  k=/data/linux/ssh-host/ssh_host_${t}_key
  [ -f "$k" ] || ssh-keygen -q -t "$t" -N '' -f "$k"
  cp -f "$k" "$k.pub" /etc/ssh/
  chmod 600 "/etc/ssh/ssh_host_${t}_key"
done

# Root login: password from ROOT_PASSWORD, optional keys from AUTHORIZED_KEYS.
[ -n "${ROOT_PASSWORD:-}" ] && echo "root:${ROOT_PASSWORD}" | chpasswd
[ -n "${AUTHORIZED_KEYS:-}" ] && printf '%s\n' "$AUTHORIZED_KEYS" > /data/root/.ssh/authorized_keys && chmod 600 /data/root/.ssh/authorized_keys
cat > /etc/ssh/sshd_config.d/railway.conf <<CFG
Port 22
ListenAddress 0.0.0.0
ListenAddress ::
PermitRootLogin yes
PasswordAuthentication $([ -n "${ROOT_PASSWORD:-}" ] && echo yes || echo no)
ClientAliveInterval 60
CFG

# sshd strips the environment: make the service's variables visible to SSH
# sessions too, except the passwords.
for n in $(compgen -e); do
  case "$n" in WEB_PASSWORD|ROOT_PASSWORD|AUTHORIZED_KEYS|_|PWD|OLDPWD|SHLVL|HOME|HOSTNAME|TERM|PATH) continue ;; esac
  printf 'export %s=%q\n' "$n" "${!n}"
done > /etc/profile.d/railway-env.sh

# nginx on $PORT: /healthcheck for Railway, /terminal for ttyd, the rest to the
# user's app on $APP_PORT, or a welcome page while nothing listens there.
cat > /etc/nginx/conf.d/linux.conf <<CFG
map \$http_upgrade \$connection_upgrade { default upgrade; '' close; }
server {
  listen ${PORT} default_server;
  listen [::]:${PORT} default_server;
  client_max_body_size 200m;
  # Redirects stay relative: Railway's proxy serves this on 443, not on \$PORT.
  absolute_redirect off;
  location = /healthcheck { access_log off; return 200 "ok"; }
  location = /terminal { return 301 /terminal/; }
  location /terminal/ {
    proxy_pass http://127.0.0.1:7682;
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host \$host;
    proxy_read_timeout 1d;
  }
  location / {
    proxy_pass http://127.0.0.1:${APP_PORT};
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection \$connection_upgrade;
    proxy_set_header Host \$host;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$http_x_forwarded_proto;
    proxy_read_timeout 1h;
    error_page 502 504 = @welcome;
  }
  location @welcome {
    root /opt/linux;
    try_files /welcome.html =503;
    add_header Cache-Control "no-store" always;
  }
}
CFG

mkdir -p /run/linux && rm -f /run/linux/ready
echo "== linux: web on :${PORT} (app on :${APP_PORT}, terminal at /terminal/), sshd on :22"
exec /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf
