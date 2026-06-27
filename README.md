# Fitnesswispr

Voice-first iOS workout tracker. Speak your sets — *"Bench Press 225 pounds, 12 reps, 3 sets, then overhead press 135 for 3 sets of 10"* — and they're parsed into structured data and saved with a timestamp. No login; each device is identified by a UUID.

## How it works

```
iPhone mic
  → SFSpeechRecognizer (on-device, live transcript)
  → POST /api/v1/parse  {transcript, device_uuid, unit_preference, context}
  → FastAPI backend → Gemini 2.5 Flash (text)
  → structured JSON → review screen → Save
  → POST /api/v1/sessions → PostgreSQL
```

On-device speech-to-text keeps transcription free and instant; Gemini only does the semantic parsing (shorthand expansion, splitting exercises on "then", classifying the workout type, pulling out body weight / cardio / timed holds). Body weight stated once carries forward to later clips and the next session.

## Features

- **Record** a workout by voice, review the parsed result, then save
- **Add a past workout** with a date picker
- **Calendar** with color-coded dots per workout type
- **History** grouped by month, with full session detail
- **Export** all data to CSV or Excel (`.xlsx`)
- Unit preference (lbs / kg)

## Tech stack

| Layer | Tech |
|---|---|
| iOS | Swift 6, SwiftUI, iOS 17+, SFSpeechRecognizer + AVAudioEngine |
| Backend | Python 3.13, FastAPI, SQLAlchemy 2 (async), Alembic, Pydantic v2 |
| LLM | Google Gemini `gemini-2.5-flash` |
| Database | PostgreSQL |
| Export | pandas + openpyxl |

## Repository layout

```
backend/                FastAPI service
  app/
    routers/            HTTP endpoints (parse, sessions, calendar, export, devices)
    services/           gemini_service, export_service
    models/             SQLAlchemy ORM
    schemas/            Pydantic request/response models
  migrations/           Alembic
  tests/                pytest (SQLite + mocked Gemini)
  Dockerfile
ios/
  project.yml           xcodegen project definition
  Fitnesswispr/
    App, Core/, Features/, Components/   (MVVM, feature-organized)
  FitnesswisrUITests/
```

## Backend — local development

Requires Python 3.13 and PostgreSQL.

```bash
cd backend
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

# config
cp .env.example .env          # then edit:
#   GEMINI_API_KEY=<your key>
#   DATABASE_URL=postgresql+asyncpg://postgres:postgres@localhost/fitnesswispr

createdb fitnesswispr
alembic upgrade head

uvicorn app.main:app --reload --port 8000
```

Run the tests (no Postgres or API key needed — uses SQLite and mocks Gemini):

```bash
pytest -q
```

The API is served under `/api/v1` (e.g. `GET /api/v1/health`).

### API endpoints

```
GET    /api/v1/health
POST   /api/v1/parse                      transcript -> structured JSON (no DB write); exercises missing a name are dropped
POST   /api/v1/sessions                   save a workout
GET    /api/v1/sessions?device_uuid=&start_date=&end_date=&limit=&offset=
GET    /api/v1/sessions/{id}
PUT    /api/v1/sessions/{id}
DELETE /api/v1/sessions/{id}
GET    /api/v1/calendar?device_uuid=&year=&month=
GET    /api/v1/export?device_uuid=&format=csv|xlsx
GET    /api/v1/devices/{device_uuid}/context     last body weight, etc.
```

## iOS — local development

Requires Xcode 16+ and [xcodegen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
cd ios
xcodegen generate
open Fitnesswispr.xcodeproj
```

The API base URL is read from `Info.plist` (`API_BASE_URL`), generated from `project.yml`. Point it at your local backend for development or at the deployed server for device testing:

```yaml
# ios/project.yml  ->  targets.Fitnesswispr.info.properties
API_BASE_URL: "http://localhost:8000"
```

Re-run `xcodegen generate` after changing `project.yml`. Speech recognition needs a physical device (the Simulator has no microphone input).

## Deployment

The backend is containerized (`backend/Dockerfile`) and runs on a single AWS EC2 instance with a managed, private RDS PostgreSQL database. Operational details (instance, RDS endpoint, security groups) live outside the repo.

**Redeploy** (after code changes):

```bash
# from backend/ — copy code to the instance, rebuild, restart
tar --exclude='.venv' --exclude='__pycache__' --exclude='.env' -czf /tmp/app.tgz .
scp -i <key.pem> /tmp/app.tgz ec2-user@<host>:~/app/
ssh -i <key.pem> ec2-user@<host> \
  "cd ~/app && tar xzf app.tgz && find . -name '._*' -delete \
   && docker build -t fitnesswispr-backend:latest . \
   && docker rm -f fitnesswispr; \
   docker run -d --name fitnesswispr --restart unless-stopped \
     --env-file ~/app/.env.prod -p 8000:8000 fitnesswispr-backend:latest"
```

The container runs `alembic upgrade head` on startup, so schema migrations apply automatically.

> **Note:** secrets (`GEMINI_API_KEY`, `DATABASE_URL`) are never committed — they live in `.env` locally and `~/app/.env.prod` on the server. The public endpoint currently uses plain HTTP with an iOS ATS exception, which is fine for personal use; for App Store distribution, front it with a domain + HTTPS and remove the exception.
