# Deploying the Nura / EviSafe backend to Fontys EduCloud

This runs the **entire backend** (API, database, object storage, secret store,
Whisper transcription, and the integrity checker) on one EduCloud VM with a
single `docker compose up`. Your team then runs only the **frontend** locally,
pointed at this VM. See [`../frontend-dev/README.md`](../frontend-dev/README.md)
for the frontend side.

This mirrors how the original team hosted everything on a private home server —
just on free school infrastructure you control.

> **Just want it running on your own laptop instead** (to test something, or for
> backend development)? See [`README-local.md`](README-local.md) — same stack,
> no VM needed.

> **One-time job for one technical person.** After this is up, everyone else just
> needs the VM's IP address.

---

## What you'll end up with

| Service | Where | Exposed? |
|---|---|---|
| Backend API (FastAPI) | `http://<VM-IP>:8000` (docs at `/docs`) | ✅ port 8000 |
| Integrity dashboard | `http://<VM-IP>:8001` | ✅ port 8001 |
| PostgreSQL, MinIO, OpenBao, Whisper | internal Docker network only | ❌ (not public) |

The database is created and seeded automatically on first launch (schema +
evidence types + a demo user + sample cases/incidents).

---

## Step 1 — Create the VM on EduCloud

1. Log in at `educloud.fontysict.nl`
2. **Compute → Instances → Add Instance**
3. Settings:
   - **Template**: Ubuntu 24.04 LTS Cloud
   - **Service Offering**: at least **Small+ (20 GB disk)**. The Whisper model
     (~1.5 GB) plus Docker images use real space — pick a **larger disk if
     offered** (30 GB+ recommended).
   - **Network**: create or select a guest network
4. **Advanced → SSH Key Pair**: paste your public SSH key
5. Boot the VM and note the assigned **public IP**

## Step 2 — Open ports on EduCloud

**Network → Guest Networks → your network → Public IP Addresses → click the IP**

- **Firewall tab** — add rules (Source CIDR `0.0.0.0/0`, TCP):
  - port **22** (SSH)
  - port **8000** (API)
  - port **8001** (integrity dashboard)
- **Port Forwarding tab** — forward each of those public ports to the same VM port.

## Step 3 — SSH in

```bash
ssh -i C:\Users\<you>\.ssh\<your-key> ubuntu@<VM-IP>
```

If you recreated the VM and get a host-key error: `ssh-keygen -R <VM-IP>`

## Step 4 — Install Docker

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker ubuntu
```

Log out and back in so the `docker` group applies.

## Step 5 — Fontys SSL-inspection fix (if image pulls fail)

The school network intercepts HTTPS. If Docker can't pull images, trust the
proxy cert:

```bash
echo | openssl s_client -connect registry-1.docker.io:443 2>/dev/null | openssl x509 > /tmp/proxy-ca.crt
sudo cp /tmp/proxy-ca.crt /usr/local/share/ca-certificates/school-proxy.crt
sudo update-ca-certificates
sudo systemctl restart docker
```

Repeat with a new filename if it fails again later with a different cert.

> If `docker compose build` later fails with a TLS/cert error during **pip
> install** (not image pull), the proxy is also intercepting PyPI. Easiest
> workaround: build off the school network (e.g. at home), or ask for the VM's
> egress to be un-inspected. See "Common issues" below.

## Step 6 — Get the project onto the VM

If your team has a Git remote:

```bash
git clone <your-repo-url> nura
cd nura/deploy
```

No Git remote? Copy the project folder from your machine instead (run locally):

```bash
scp -i <your-key> -r "C:\Users\Aaron\Desktop\domestic-violence-development\domestic-violence-development" ubuntu@<VM-IP>:~/nura
```
then on the VM: `cd ~/nura/deploy`

## Step 7 — Configure secrets

```bash
cp .env.example .env
nano .env
```

At minimum set strong values for `POSTGRES_PASSWORD`, `MINIO_SECRET_KEY`,
`VAULT_TOKEN`, and `SECRET_KEY`. Generate a good secret with:

```bash
openssl rand -hex 32
```

## Step 8 — Launch everything

```bash
docker compose up -d --build
```

First run builds the images and can take several minutes. Check progress:

```bash
docker compose ps
docker compose logs -f seeder     # shows the demo data being created
```

## Step 9 — Verify

On the VM:

```bash
curl http://localhost:8000/health         # {"status":"ok",...}
```

From your laptop, open:

- `http://<VM-IP>:8000/docs` — the API (interactive)
- `http://<VM-IP>:8001` — the integrity dashboard

## Step 10 — Point the frontends at it

On each team member's machine, run the launcher in
[`../frontend-dev/`](../frontend-dev/README.md) and, when asked, enter:

```
http://<VM-IP>:8000
```

Demo login (created by the seeder, and used by the dashboard's auto-login):

```
email:    demo@example.com
password: DemoPass123!
```

---

## Updating after code changes

```bash
cd ~/nura && git pull        # or re-scp the folder
cd deploy && docker compose up -d --build
```

The database keeps its data across restarts (Docker volume `postgres_data`).

## Stopping / resetting

```bash
docker compose down                 # stop (keeps data)
docker compose down -v              # stop AND wipe all data (fresh DB next time)
```

---

## Good to know / caveats

- **The Vault (OpenBao) runs in dev mode = in-memory.** If that container is
  recreated, the per-file encryption keys are lost and previously uploaded
  evidence shows as `unverifiable`. Fine for a dev/UI environment; switch to a
  persistent OpenBao config before relying on it long-term.
- **Trusted timestamps need outbound internet.** Evidence upload calls the
  Sectigo TSA (`http://timestamp.sectigo.com`, plain HTTP, so SSL inspection
  doesn't affect it). If the VM has no internet, uploads return 503.
- **MinIO addressing** is handled: the backend image sets path-style S3
  addressing via an AWS config file, so no application code was changed for it.
- **Whisper** downloads its model (~1.5 GB) on the first transcription and caches
  it in a Docker volume, so it only downloads once. The first transcription is
  slow (CPU).

## Common issues

| Problem | Fix |
|---|---|
| Docker image pull fails (TLS cert) | Re-run Step 5 with a new cert filename |
| `pip install` fails during build (TLS cert) | School proxy is intercepting PyPI — build off the school network, or add the proxy CA into the build |
| VM disk full during build | Recreate with a larger disk; `docker system prune -af` to reclaim space |
| Can't reach `:8000` from laptop | Check both the **Firewall** and **Port Forwarding** rules exist for 8000 |
| Seeder shows errors | `docker compose logs seeder`; re-run with `docker compose up -d seeder` |
| Containers gone after a VM reboot | `restart: always` handles this; otherwise `docker compose up -d` |
