# Team setup — how to run Nura / EviSafe

The original team hosted the whole backend on a private home server that we no
longer have access to. To get the app running for our UI/UX work, we host the
**backend on the school's EduCloud** once, and everyone runs the **frontend
locally** against it.

Nothing in the application code was changed to make this work, except one line in
`backend/app/services/transcription.py` (the Whisper address, which the project's
own README already told us to update). Everything else lives in two new folders:

```
deploy/         # everything to run the backend stack on EduCloud (Docker)
frontend-dev/   # one-click launcher to run the dashboard / mobile app locally
```

## Two roles

### 1. One person sets up the backend (once)
Follow **[`deploy/README-educloud.md`](deploy/README-educloud.md)**. End result: a
VM with the full stack running, reachable at `http://<VM-IP>:8000`. Share that URL
with the team.

### 2. Everyone runs the frontend
Follow **[`frontend-dev/README.md`](frontend-dev/README.md)**. Windows users
double-click `frontend-dev/start.bat`; Mac users run `frontend-dev/start.sh`.
Enter the backend URL once, pick dashboard / mobile / both, done. No Docker or
Python needed for this part.

### Want the backend on your own laptop instead?
If you're doing backend work (or just want to test something locally) rather
than using the shared EduCloud VM, follow
**[`deploy/README-local.md`](deploy/README-local.md)** instead of step 1 above —
same stack, no VM/SSH/EduCloud account needed.

## What's running where

```
Your laptop                         EduCloud VM (Docker)
-----------                         --------------------
legal dashboard (localhost:5173) ─┐
mobile app (Expo)                ─┼─►  backend API (:8000)
                                  │        ├─ PostgreSQL   (schema auto-created)
                                  │        ├─ MinIO        (encrypted evidence)
                                  │        ├─ OpenBao      (encryption keys)
                                  │        └─ Whisper      (transcription)
                                  └─►  integrity dashboard (:8001)
```

## Demo login

```
email:    demo@example.com
password: DemoPass123!
```

The dashboard logs in with this automatically. The backend is seeded with a few
sample cases and incidents so the UI isn't empty.
