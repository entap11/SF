# Swarmfront VS Service

Minimum in-memory VS handshake backend for two-phone TestFlight smoke tests.

This implements the routes in `../../docs/vs_backend_contract.md`. It intentionally does not include database, auth, payment, or rank production logic. Sessions, queue tickets, and intent streams reset when the process restarts.

## Local Run

```bash
cd tools/vs-service
npm install
npm run build
npm run smoke
npm run dev
```

Local base URL:

```text
http://127.0.0.1:8791/v1
```

## Routes

- `GET /health`
- `GET /v1/health`
- `POST /v1/create_invite`
- `POST /v1/join_invite`
- `POST /v1/get_session`
- `POST /v1/set_ready`
- `POST /v1/can_start`
- `POST /v1/start_session`
- `POST /v1/leave_session`
- `POST /v1/enqueue_quick_match`
- `POST /v1/poll_quick_match`
- `POST /v1/cancel_quick_match`
- `POST /v1/open_money_escrow`
- `POST /v1/settle_money_match`
- `POST /v1/refund_money_match`
- `POST /v1/open_async_entry_escrow`
- `POST /v1/settle_async_contest`
- `POST /v1/preview_async_contest_payout_report`
- `POST /v1/list_async_contest_payout_reports`
- `POST /v1/approve_async_contest_payout_report`
- `POST /v1/settle_async_contest_payout_percentages`
- `POST /v1/refund_async_entry`
- `POST /v1/get_money_transactions`
- `POST /v1/get_money_payout_summary`
- `POST /v1/publish_intent`
- `POST /v1/poll_intents`

The same `POST /<action>` routes are also available for hosts that prefer a root base URL.

## Environment

- `PORT`: HTTP port. Defaults to `8791`.
- `BIND_HOST`: bind host. Defaults to `0.0.0.0`.
- `VS_CORS_ENABLED`: defaults to `true`.
- `VS_SESSION_TTL_SEC`: defaults to `900`.
- `VS_QUEUE_TTL_SEC`: defaults to `90`.
- `VS_INTENT_STREAM_MAX_EVENTS`: defaults to `512`.

## Deploy

Use any Node HTTPS host such as Render, Railway, or Fly. Most hosts terminate TLS for you and provide a public HTTPS URL.

Build command:

```bash
npm install
npm run build
```

Start command:

```bash
npm start
```

Set `PORT` only if your host does not inject it automatically.

After deployment, use this base URL in Godot:

```ini
swarmfront/vs/backend_url="https://YOUR_HOSTNAME/v1"
```

Verify before exporting TestFlight:

```bash
godot --headless --path ../.. --script res://scripts/dev/vs_pvp_smoke.gd --vs-smoke-backend-url=https://YOUR_HOSTNAME/v1
```

Local money-game transport smoke:

```bash
PORT=8791 BIND_HOST=127.0.0.1 npm start
SF_VS_BACKEND_URL=http://127.0.0.1:8791/v1 godot --headless --path ../.. --script res://tools/money_game_backend_transport_smoke_test.gd
```
