# upgrade: skip
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8 PORT=7681 APP_PORT=8080

# Toolbox plus the server parts: supervisor runs every process, cron for
# scheduled jobs, nginx routes the Railway domain, ttyd is the web terminal.
# nginx `worker_processes auto` counts host cores, not the container quota
# (48 on Railway Metal hosts), so pin it to 2.
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl wget gnupg git openssh-server ttyd nginx-light tmux \
      supervisor cron vim nano less htop ripgrep jq unzip zip tree procps locales \
      python3 python3-pip python3-venv build-essential \
      iputils-ping dnsutils net-tools \
  && curl -LsSf https://astral.sh/uv/install.sh | UV_INSTALL_DIR=/usr/local/bin sh \
  && mkdir -p /run/sshd \
  && sed -i 's/^worker_processes auto;/worker_processes 2;/' /etc/nginx/nginx.conf \
  && grep -q '^worker_processes 2;' /etc/nginx/nginx.conf \
  && rm -f /etc/nginx/sites-enabled/default \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# What the image ships. Packages the user adds on top are saved to the volume
# and reinstalled on boot (see bin/save-packages and bin/restore).
RUN mkdir -p /opt/linux && apt-mark showmanual | sort -u > /opt/linux/base-packages.txt

# The volume mounts at /data. Home, /srv and the root crontab live on it.
# Replacing a directory with a symlink survives Railway's image unpacking.
RUN mv /root /opt/linux/root-image && ln -s /data/root /root \
  && rm -rf /srv && ln -s /data/srv /srv \
  && rm -rf /var/spool/cron/crontabs && ln -s /data/linux/crontabs /var/spool/cron/crontabs

COPY skel/ /opt/linux/skel/
COPY welcome.html /opt/linux/welcome.html
COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY bin/ /usr/local/lib/linux/
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh /usr/local/lib/linux/* \
  && ln -s /usr/local/lib/linux/svc /usr/local/bin/svc \
  && ln -s /usr/local/lib/linux/drop-file-cache /usr/local/bin/drop-file-cache \
  && echo 'DPkg::Post-Invoke { "/usr/local/lib/linux/save-packages || true"; };' \
       > /etc/apt/apt.conf.d/99linux-persist

EXPOSE 22 7681
ENTRYPOINT ["/entrypoint.sh"]
