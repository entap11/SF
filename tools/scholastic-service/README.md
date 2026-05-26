# Swarmfront Scholastic Service

Server-authoritative backend for SFA/SFU profiles, school/program affiliation, hive review, complaints, and scholastic tournaments.

## Scope

Implemented:
- SFA school-year enrollment attestation
- four-school-year SFA eligibility window
- school hive review and hive-level bonus eligibility
- enrollment complaint/dispute path
- SFU adult-only program affiliation
- SFU tournament rule flags for buffs/cash/entry/program roster
- SFA/SFU/open-player activity metrics for DAU/WAU/MAU, new players, and time-in-app comparison
- SFA family-safe advertising policy resolution
- durable Postgres storage
- audit events
- admin summary endpoint

This is intentionally separate from analytics. Analytics observes product behavior; this service owns scholastic state.

## Setup

```bash
cd tools/scholastic-service
cp .env.example .env
docker compose up -d
npm install
npm run migrate
npm run dev
```

Default local URL:

```text
http://127.0.0.1:8792/v1
```

## Routes

- `GET /health`
- `GET /v1/health`
- `POST /v1/report_age`
- `POST /v1/register_high_school`
- `POST /v1/join_school`
- `POST /v1/file_enrollment_complaint`
- `POST /v1/register_college_program`
- `POST /v1/join_college_program`
- `POST /v1/create_sfa_tournament`
- `POST /v1/create_sfu_tournament`
- `POST /v1/review_school_hive`
- `POST /v1/record_sfa_tournament_result`
- `POST /v1/record_sfu_tournament_result`
- `POST /v1/record_activity`
- `GET /v1/profile/:playerId`
- `GET /v1/school/:schoolId`
- `GET /v1/ad_policy/:playerId`
- `GET /v1/admin/summary`

If `SCHOLASTIC_API_TOKEN` is set, client routes require `Authorization: Bearer <token>`.
If `SCHOLASTIC_ADMIN_TOKEN` is set, admin routes require that token. Otherwise they use `SCHOLASTIC_API_TOKEN`.

## Smoke

```bash
npm run smoke
```

The smoke test uses the in-memory store and validates SFA/SFU policy behavior without requiring Postgres.
