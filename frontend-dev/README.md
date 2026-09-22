# Running the frontend locally (for UI/UX work)

This folder has a one-step launcher for the two frontends — the **legal
dashboard** and the **mobile app** — so you don't have to touch the backend,
Docker, or any config. They connect to the shared backend running on the school's
EduCloud server.

## What you need first

- **Node.js** (LTS) — install from <https://nodejs.org> if you don't have it.
- The **backend URL** from whoever set up EduCloud. It looks like
  `http://<some-ip>:8000`.

That's it. No Python, no Docker.

## Start it

### Windows
Double-click **`start.bat`** (or right-click `start.ps1` → Run with PowerShell).

### macOS / Linux
```bash
cd frontend-dev
chmod +x start.sh    # first time only
./start.sh
```

The first time, it asks for the backend URL and remembers it. Then pick:

- **[1] Legal dashboard** → opens at <http://localhost:5173> in your browser
- **[2] Mobile app** → Expo; press `w` for web, or scan the QR with **Expo Go**
- **[3] Both**

The first launch installs dependencies (a few minutes); later launches are fast.

## Logging in

The dashboard logs in automatically with the demo account. If you ever need it:

```
email:    demo@example.com
password: DemoPass123!
```

## Notes

- **Change the backend URL later**: delete `backend-url.txt` in this folder and
  run the launcher again.
- **The mobile app on your phone**: because the backend is a public server IP,
  the same URL works on a physical phone, an emulator, and the web build — no
  extra setup.
- The launcher writes small local config files (`.env.development.local` for the
  dashboard, `.env` for the mobile app). These are git-ignored and **do not
  change any project code**.
- To stop: close the app window (Windows), or press `Ctrl+C` / run `./stop.sh`
  (macOS/Linux).
