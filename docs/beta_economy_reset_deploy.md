# Beta Economy Reset and Render Deploy

Reset epoch: `beta_2026071301`

This reset preserves player UUIDs, ENTaP IDs, call signs, friends, settings, purchases/entitlements, and rank audit history. It resets Honey, canonical Wax and Wax-derived standings, Crucible Wax ledgers, Nectar/Battle Path progress, reward claims, and economy dedupe records exactly once.

## 1. Configure the VS service in Render

Open the `sf` / `sf-zr2m` web service in the Render Dashboard and add these values under **Environment**:

- `VS_ADMIN_TOKEN`: a unique random 32-byte secret.
- `VS_MATCH_AUTHORITY_TOKEN`: a different unique random 32-byte secret.
- `VS_ECONOMY_EPOCH`: `beta_2026071301`
- `VS_PRODUCTION_MODE`: `true`
- `CRUCIBLE_LEDGER_STORE`: `file`
- `CRUCIBLE_LEDGER_PATH`: `/var/data/crucible-ledger.json`
- `HONEY_LEDGER_STORE`: `file`
- `HONEY_LEDGER_PATH`: `/var/data/honey-ledger.json`

Generate the two secrets locally with `openssl rand -hex 32`. Never commit them or paste them into chat.

The current file-backed ledgers need a persistent disk for beta retention. On the VS service's **Disks** page, add the smallest available disk mounted at `/var/data`. Only paid Render web services support persistent disks. Adding the disk triggers a deploy and briefly stops the single disk-backed instance.

## 2. Configure the rank service in Render

Open `entap-identity-rank-staging` and confirm these Environment values:

- `RANK_API_TOKEN`: already configured; keep the existing value.
- `RANK_ECONOMY_EPOCH`: `beta_2026071301`
- `RANK_ENFORCE_CANONICAL_PLAYER_IDS`: `true`
- `RANK_ENABLE_DEBUG_ACTIONS`: `false`

The epoch resets every player's Wax to the configured starting value and recomputes Wax-derived standings while retaining the player records and audit history. The Postgres epoch marker prevents repeat resets on restart.

## 3. Give Codex deploy-only Render API access

In Render, open **Account Settings > API Keys**, create a key named `codex-sf-deploy`, and copy it once. Store it in macOS Keychain from a local Terminal without placing the value in shell history:

```zsh
read -s "RENDER_API_KEY?Paste Render API key: "; echo
security add-generic-password -a "$USER" -s swarmfront-render-api -w "$RENDER_API_KEY" -U
unset RENDER_API_KEY
```

Then tell Codex that the key is stored under the Keychain service name `swarmfront-render-api`. Codex can use it to list service IDs, trigger deploys, and inspect deploy status without printing the key.

Render API verification, if needed:

```zsh
RENDER_API_KEY="$(security find-generic-password -a "$USER" -s swarmfront-render-api -w)"
curl -fsS 'https://api.render.com/v1/services?limit=20' \
  -H 'Accept: application/json' \
  -H "Authorization: Bearer $RENDER_API_KEY"
unset RENDER_API_KEY
```

The API deploy endpoint is `POST /v1/services/{serviceId}/deploys`. Environment-variable updates should be made in the Dashboard: Render's API `PUT` endpoint replaces the complete variable list, so it is unsafe for a partial manual update.

## 4. Deployment order

1. Configure both services and attach the VS disk.
2. Push the validated release commit to `main`.
3. Deploy the rank service first and confirm its epoch reset log.
4. Deploy the VS service and confirm `/health` reports both auth requirements and `economy_epoch=beta_2026071301`.
5. Verify the 12 identities/call signs still exist and their Wax is at the starting value.
6. Verify Honey and Crucible ledger snapshots are empty.
7. Run live rank, PvP, Honey, Wax, and Battle Path smoke checks.
8. Export and upload build `2026071301` to TestFlight.
