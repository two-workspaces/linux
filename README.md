# Deploy and Host Linux on Railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/linux?referralCode=sLjDXb&utm_medium=integration&utm_source=button&utm_campaign=linux)

This template gives you an always-on Ubuntu 24.04 server you can actually host things on. A plain Linux container forgets everything outside its volume on every redeploy and has nothing to keep your programs running. Here `apt install` sticks, programs you register with `svc` restart after crashes and redeploys, and whatever listens on port 8080 is served at your Railway domain.

## About Hosting Linux

One service, one volume at `/data`. You reach the box in three ways:

- **The Railway domain** serves your app on port 8080, or a welcome page until something listens there.
- **`/terminal/`** on the same domain is a password-protected web terminal.
- **SSH** goes through Railway's TCP proxy.

The terminal and SSH both land in the same `tmux` session.

What persists:

- **Your home directory and `/srv`** live on the volume.
- **Packages you `apt install`** are recorded on the volume, together with any apt sources and keys you added, and reinstalled on boot.
- **Services** you add with `svc` are a script plus a supervisor entry on the volume. They start again after every redeploy.
- **Your crontab** is kept on the volume.

## Common Use Cases

- A small VPS for a bot, a scraper, a webhook receiver or a side-project API
- Run a program 24/7 and have it restart after a crash
- Serve a static site or a quick prototype from `/srv` without writing a Dockerfile
- Scheduled jobs with `crontab -e`
- A persistent Linux workspace reachable from a browser or SSH

## Dependencies for Linux Hosting

- None. Single service, no database.

### Deployment Dependencies

- [ttyd](https://github.com/tsl0922/ttyd) web terminal
- [Supervisor](https://supervisord.org/) process manager

### Implementation Details

**First use:** open `https://<your-domain>/terminal/` and log in with `WEB_USER` and the generated `WEB_PASSWORD`, which are in the service's Variables tab.

**Run an app:**

```
mkdir -p /srv/site && echo hello > /srv/site/index.html
svc add web --dir /srv/site -- python3 -m http.server 8080
```

Open your Railway domain and the app is there. Other `svc` commands:

- `svc ls` lists your services.
- `svc logs web -f` follows a service's output.
- `svc edit web` changes its command.
- `svc rm web` removes it.

To serve a different port, change `APP_PORT`.

**Install software:** `apt install nodejs` (or anything else) as usual. The package list is saved after every apt run and replayed on boot, before your services start. The web terminal and SSH come up first, so a long reinstall never fails the deploy. The log is `/data/linux/logs/restore.log`.

**SSH:** Railway creates a TCP proxy for port 22 on deploy. Copy the host and port from Settings → Networking and run `ssh root@<host> -p <port>` with `ROOT_PASSWORD`. For key-only login, add your public key to `AUTHORIZED_KEYS` and clear `ROOT_PASSWORD`.

Notes and limits:

- Only apt packages are replayed. Software installed with `curl | sh`, `pip install --user`, `npm -g` or a downloaded `.deb` should go in your home directory or `/srv`, or be reinstalled from your service's script.
- Anything else outside `/root` and `/srv` resets on redeploy, as in any container.
- There is no systemd and no Docker daemon. `svc` takes systemd's place.
- You are root. The web terminal password guards a root shell, so keep it strong.
- 512 MB of RAM is enough for the box itself (about 50 MB idle). Size up for what you run.
- Just want a shell? The same author publishes a [Linux Terminal](https://railway.com/deploy/ubuntu-terminal?referralCode=sLjDXb) template.

## Why Deploy Linux on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Linux on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
