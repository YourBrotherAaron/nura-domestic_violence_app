# Running the full backend stack locally

For anyone who pulled the repo and wants the entire backend (API, database,
object storage, secrets, Whisper, integrity checker) running on their own
machine — e.g. to test something before it goes to EduCloud, or to develop
backend code. If you only need the **frontend** for UI work, you don't need any
of this — see [`../frontend-dev/README.md`](../frontend-dev/README.md) instead
and point it at whoever's EduCloud VM (or your own local stack) is running.

## Prerequisites

- **Docker Desktop**, installed and running (the whale icon should say it's
  running before you continue).

That's it — everything else runs inside containers.

## Steps

**1. Go to the `deploy/` folder**

```bash
cd deploy
```

**2. Create your local secrets file**

```bash
cp .env.example .env
```

The defaults in `.env.example` work fine for local use as-is — you don't need
to edit anything unless you want to.

**3. Build and start everything**

```bash
docker compose up -d --build
```

First run downloads images and builds the backend/Whisper containers — this can
take a few minutes. Later runs are much faster.

**4. Watch it come up (optional)**

```bash
docker compose ps                 # all services should show "Up" / "healthy"
docker compose logs -f seeder     # confirms the demo data was created, then exits
```

The `seeder` container creates a demo user and a few sample cases/incidents
automatically, then stops — that's expected, it's not meant to keep running.

**5. Verify it's working**

Open in a browser:
- <http://localhost:8000/health> → `{"status":"ok",...}`
- <http://localhost:8000/docs> → interactive API docs
- <http://localhost:8001> → integrity checker dashboard

**6. Point the frontend at it**

Run the launcher in [`../frontend-dev/`](../frontend-dev/):
- **Windows:** double-click `frontend-dev/start.bat`
- **Mac/Linux:** `cd frontend-dev && ./start.sh`

When it asks for the backend URL, enter:

```
http://localhost:8000
```

Demo login (already seeded):

```
email:    demo@example.com
password: DemoPass123!
```

## Stopping it

```bash
docker compose down          # stop, keep all data
docker compose down -v       # stop AND wipe the database/storage (fresh start next time)
```

## If something goes wrong

See the **Common issues** table in
[`README-educloud.md`](README-educloud.md#common-issues) — the same stack runs
here, so the same fixes apply (e.g. image pull errors, disk space).

Known, documented behaviour (not bugs in this setup) is listed in
[`README-educloud.md`](README-educloud.md#good-to-know--caveats) — e.g. Vault
runs in-memory locally, so evidence keys reset if that one container is
recreated.

There is also one **known application bug**, unrelated to this setup: the
integrity checker currently marks every evidence file as "tampered" due to a
pre-existing mismatch in how the HMAC is computed. See
[`../../docs/bugs/integrity-checker-false-tamper.md`](../../docs/bugs/integrity-checker-false-tamper.md)
(outside the repo, in the shared `docs/` folder) for details — it's expected
until the team decides on a fix.
