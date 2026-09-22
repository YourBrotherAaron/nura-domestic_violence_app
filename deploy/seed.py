#!/usr/bin/env python3
"""
Seed the Nura backend with a demo user and sample cases/incidents so the legal
dashboard has realistic content to design against.

- Uses only the Python standard library (no pip install needed).
- Talks to the backend over its normal HTTP API (same paths the apps use).
- Idempotent: re-running it will not create duplicate users or incidents.

Configured via environment variables (see docker-compose.yml / .env):
    API_BASE_URL, DEMO_EMAIL, DEMO_PASSWORD, DEMO_FIRST_NAME, DEMO_LAST_NAME
"""

import json
import os
import time
import urllib.error
import urllib.request

API = os.environ.get("API_BASE_URL", "http://backend:8000").rstrip("/")

# The primary demo account — must match the dashboard's auto-login credentials.
PRIMARY = {
    "first_name": os.environ.get("DEMO_FIRST_NAME", "Demo"),
    "last_name": os.environ.get("DEMO_LAST_NAME", "Reviewer"),
    "email": os.environ.get("DEMO_EMAIL", "demo@example.com"),
    "password": os.environ.get("DEMO_PASSWORD", "DemoPass123!"),
    "phone_number": "+31600000000",
    "case_title": "State v. Doe",
    "case_status": "open",
    "incidents": [
        {"incident_type": "physical", "location": "Home — kitchen",
         "incident_date": "2026-01-14", "incident_time": "21:30:00",
         "description": "Pushed against the counter during an argument; visible bruising on left arm."},
        {"incident_type": "verbal", "location": "Home — living room",
         "incident_date": "2026-02-02", "incident_time": "19:05:00",
         "description": "Repeated threats and shouting; neighbour overheard."},
        {"incident_type": "stalking", "location": "Workplace parking lot",
         "incident_date": "2026-02-20", "incident_time": "08:15:00",
         "description": "Followed to work; waited outside for over an hour."},
    ],
}

# A couple of extra accounts so the admin cases table isn't a single row.
EXTRAS = [
    {
        "first_name": "Anna", "last_name": "Jansen",
        "email": "anna.jansen@example.com", "password": "DemoPass123!",
        "phone_number": "+31611111111",
        "case_title": "Jansen — protective order prep", "case_status": "open",
        "incidents": [
            {"incident_type": "psychological", "location": "Home",
             "incident_date": "2026-01-28", "incident_time": "22:40:00",
             "description": "Isolation and controlling behaviour; phone monitored."},
            {"incident_type": "financial", "location": "Home — office",
             "incident_date": "2026-02-11", "incident_time": "10:00:00",
             "description": "Denied access to shared bank account."},
        ],
    },
    {
        "first_name": "Mark", "last_name": "de Vries",
        "email": "mark.devries@example.com", "password": "DemoPass123!",
        "phone_number": "+31622222222",
        "case_title": "de Vries — evidence review", "case_status": "under_review",
        "incidents": [
            {"incident_type": "sexual", "location": "Home — bedroom",
             "incident_date": "2026-02-05", "incident_time": "23:10:00",
             "description": "Non-consensual incident reported by client."},
        ],
    },
]


def _request(method, path, token=None, body=None):
    url = f"{API}{path}"
    data = json.dumps(body).encode() if body is not None else None
    headers = {"Accept": "application/json"}
    if body is not None:
        headers["Content-Type"] = "application/json"
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            text = resp.read().decode()
            return resp.status, (json.loads(text) if text else None)
    except urllib.error.HTTPError as e:
        text = e.read().decode()
        try:
            return e.code, json.loads(text)
        except ValueError:
            return e.code, text


def wait_for_backend(max_seconds=180):
    print(f"[seed] Waiting for backend at {API} ...", flush=True)
    deadline = time.time() + max_seconds
    while time.time() < deadline:
        try:
            with urllib.request.urlopen(f"{API}/health", timeout=5) as resp:
                if resp.status == 200:
                    print("[seed] Backend is up.", flush=True)
                    return True
        except Exception:
            pass
        time.sleep(3)
    print("[seed] ERROR: backend did not become healthy in time.", flush=True)
    return False


def seed_account(acc):
    label = acc["email"]

    # 1) Register (tolerate 'already registered'). Registration auto-creates a case.
    status, resp = _request("POST", "/auth/register", body={
        "first_name": acc["first_name"], "last_name": acc["last_name"],
        "email": acc["email"], "password": acc["password"],
        "phone_number": acc["phone_number"],
    })
    if status == 200:
        print(f"[seed] Registered {label}", flush=True)
    elif status == 400:
        print(f"[seed] {label} already exists — continuing.", flush=True)
    else:
        print(f"[seed] WARN register {label}: {status} {resp}", flush=True)

    # 2) Log in
    status, resp = _request("POST", "/auth/login", body={
        "email": acc["email"], "password": acc["password"],
    })
    if status != 200 or not isinstance(resp, dict) or "access_token" not in resp:
        print(f"[seed] ERROR login {label}: {status} {resp}", flush=True)
        return
    token = resp["access_token"]

    # 3) Find the auto-created case
    status, case = _request("GET", "/cases/me", token=token)
    if status != 200 or not isinstance(case, dict):
        print(f"[seed] ERROR fetching case for {label}: {status} {case}", flush=True)
        return
    case_id = case["case_id"]

    # 4) Give the case a nicer title/status
    _request("PUT", f"/cases/{case_id}", token=token, body={
        "case_title": acc["case_title"], "status": acc["case_status"],
    })

    # 5) Only add incidents if this case has none yet (keeps it idempotent)
    status, existing = _request("GET", f"/incidents/?case_id={case_id}", token=token)
    if status == 200 and isinstance(existing, list) and existing:
        print(f"[seed] {label}: {len(existing)} incident(s) already present — skipping.", flush=True)
        return

    created = 0
    for inc in acc["incidents"]:
        payload = {"case_id": case_id, **inc}
        status, resp = _request("POST", "/incidents/", token=token, body=payload)
        if status == 200:
            created += 1
        else:
            print(f"[seed] WARN incident for {label}: {status} {resp}", flush=True)
    print(f"[seed] {label}: created {created} incident(s).", flush=True)


def main():
    if not wait_for_backend():
        raise SystemExit(1)
    seed_account(PRIMARY)
    for acc in EXTRAS:
        seed_account(acc)
    print("[seed] Done.", flush=True)


if __name__ == "__main__":
    main()
