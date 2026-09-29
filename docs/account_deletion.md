# Account deletion implementation and rollout

September 18, 2026. Implemented in the `project` working tree; not deployed or
certified against the Android release candidate. No production account was touched.

## Player experience

Dashboard → Settings → Account → **Delete Account**. Settings → Support has an
**Account and data deletion** shortcut. Both open the same accessible, scrollable
confirmation screen with Cancel, consequences, and a link to
https://swarmfront.games/delete-account/.

The player explicitly confirms permanent deletion once. A five-minute device
signature challenge is bound to the operation, authenticated player, device,
request ID and private receipt. A public ID, display name or emailed address is
not proof. No account is deleted by opening a screen or visiting a URL.

Before submitting the signed confirmation, the app atomically saves its private
receipt. A lost response leaves a retryable status screen instead of recreating
the account. Successful acceptance revokes only Swarmfront devices/sessions,
excludes the account from RankStore reads, and blocks new economy actions for it.
The client clears its credentials, profile, progression, local match data and
queued analytics. It stays on the receipt screen and does not automatically
register another account. Other devices learn about the closure on authentication
or their next periodic session check; offline devices cannot be remotely erased.

Deletion covers **Swarmfront only**. ENTaP is a separate application with separate
permissions. The shared ENTaP identity and other applications' credentials,
sessions, permissions and data remain intact. The confirmation screen and public
deletion page explain this boundary.

The seven-day date is a fulfillment **target**, not a guaranteed deletion time.
The app never displays “complete” until the server confirms completion.

Permanent deletion creates no cold-storage archive. The separate six-month
Archive Account proposal is not shipped: the current device-bound identity system
has no cross-device recovery factor, and no tested archive/restore/expiry pipeline.

## API and trust boundaries

Migration `010_account_deletion.sql` adds durable requests, short-lived challenges,
per-domain tasks and a deletion-pending state. `AccountDeletionStore` owns these
operations; UI code only submits intents. Gameplay simulation rules are unchanged.

Migration `011_swarmfront_account_boundary.sql` separates the minimal shared
ENTaP principal (UUID, ENTaP ID and creation date) from `rank_players`, the
Swarmfront game profile. Existing records are assigned to Swarmfront. Devices,
sessions and authentication challenges have application ownership, enforced by
composite foreign keys. Swarmfront auth routes issue and accept only Swarmfront
credentials; possession of another application's session does not grant access.
The retained principal contains no game profile or restorable progress. A future
ENTaP app must provide its own authentication routes, token audience and permission
policy; this change does not implement that app or grant it Swarmfront permissions.

| Route | Authorization / purpose |
| --- | --- |
| POST `/v1/account/deletion/challenge` | Signed player JWT **and live database session**; body `request_id`, `receipt_token`. |
| POST `/v1/account/deletion/confirm` | Fresh registered-device signature, private receipt, `confirmation: "DELETE"`. Same-request retries return the existing receipt even after revocation. |
| POST `/v1/account/deletion/status` | `request_id` plus a 256-bit private `receipt_token` in the body; no token in a URL. |
| POST `/v1/identity/session/status` | Verify JWT and authoritative session/account state; no successful-check cache. |
| GET `/v1/admin/account-deletions` | Dedicated deletion operator credential; pending work and due dates. |
| POST `/v1/admin/account-deletions/verified-request` | Operator-only intake after separately documented ownership proof and explicit owner confirmation. |
| POST `/v1/admin/account-deletions/:id/fulfillment` | Record actual external cleanup evidence and specific retained categories/reasons/expiry dates. |
| POST `/v1/admin/account-deletions/:id/complete` | Refuses incomplete tasks or unresolved financial references; transactional Swarmfront profile purge, then completion. |

The operator credential is `ENTAP_DELETION_OPERATOR_TOKEN` (at least 32 characters),
separate from normal rank/player credentials. Requests/status use `Cache-Control:
no-store`; unexpected deletion failures log a code without SQL parameters or body.
New requests are disabled by default. The server accepts them only when
`ENTAP_ACCOUNT_DELETION_ENABLED=true` and a dedicated operator token is configured.
Disabling intake preserves existing receipts, fulfillment and already-issued
confirmation challenges. Enable intake only after the release gates below pass.

The VS middleware checks player sessions at the issuer before processing player
JWT requests. In production, missing configuration or an unavailable issuer fails
closed. Nonproduction tests can omit it. Local JWT validation still runs in the
existing handlers. No service token is granted player privileges by this check.

## Operator fulfillment

This is a supported **manual fulfillment queue**, not automatic deletion across
all databases. Assign a responsible operator and monitor the queue daily before
enabling the feature for players. Deletion evidence is a record of work already
performed, not a command to assert that unimplemented work succeeded.

Set `ENTAP_DELETION_API_URL` to the identity service origin (without `/v1`) and
the dedicated token in the operator environment, then use:

```sh
npm run account-deletions -- list
npm run account-deletions -- fulfill REQUEST_ID /private/path/evidence.json
npm run account-deletions -- complete REQUEST_ID
```

An evidence file has this structure (use actual case references):

```json
{
  "domain": "analytics",
  "evidence_ref": "privacy-case:example:analytics-purge",
  "retention": []
}
```

For necessary retained records, `retention` contains objects with `category`,
`reason`, and a future ISO `expires_at`. Do not put raw personal data in case
references. Record an explicit reviewed no-data result for an unused service.

| Domain | Required fulfillment work |
| --- | --- |
| identity | Completed by code only: remove Swarmfront rank profile, Swarmfront devices/sessions/challenges and audit entries, game friend references, event dedupe and metadata references, Honey/Nectar gameplay history. Preserve the shared ENTaP principal and other applications' records. |
| multiplayer | Remove public presence, leaderboards, friend/invite links and public history; redact identifying fields in shared matches without changing opponents' results. Include VS PostgreSQL tables, JSON ledgers, in-memory caches and delayed settlement/delivery jobs. |
| analytics | Resolve legitimate account-to-install/session mappings and remove corresponding raw events/installs/exports; inspect JSON payloads. UUID-only account deletion does not cover install-based telemetry. |
| community | Review clans, scholastic profiles/activity, rosters, moderation records and their nested JSON. Retain only justified minimal records with an expiry. |
| support | Process email intake, verification and scope; remove unnecessary correspondence/attachments. Retain the minimum case evidence needed to fulfill and confirm the request. |
| backups | Verify the actual provider retention/expiry schedule, replicas, hosting logs, exports and the legacy rank import JSON. Reapply suppression and completed deletions **before** exposing any restored service. |

Support can initiate verified requests through the CLI:

```sh
npm run account-deletions -- verified-request /private/path/verified-request.json
```

The private JSON must include `request_id`, a freshly generated 32-byte base64url
`receipt_token`, canonical `player_id`, `verification_evidence_ref`, and
`owner_confirmed: true`. Store it with restricted file permissions. An email
from an unbound address or knowledge of the call sign is not sufficient evidence.
For a lost-device user without a proven recovery factor, escalate ownership
verification rather than treating public information as proof. The public webpage
must still accept initiation without requiring an app reinstall.

Completion is deliberately blocked by remaining economy accounts/journals/event
receipts or restrictive financial foreign keys. Do not disable ledger triggers
or cascade through other players' transactions to bypass this. Financial retention
needs a reviewed disposal/redaction migration with reconciliation evidence before
those accounts can be completed. Minimal suppression hashes prevent delayed rank
writes or legacy imports recreating a deleted ID; they are pseudonymous security
records, not anonymous data or a restorable account.

All operator work must use the same Swarmfront-only scope. Shared providers must
filter by application as well as subject. The current game economy/history tables
belong to Swarmfront; future ENTaP application data must use separate storage or
explicit application ownership before sharing these stores.

## Release gates still open

1. Validate migration `011` against a staging copy of existing identities. Legacy
   records are classified as Swarmfront; any already-shared credentials need an
   explicit migration mapping before rollout. Confirm all external cleanup
   procedures preserve ENTaP and other applications' records.
2. Complete actual external-service disposal procedures, financial retention
   migration, account/install mappings and public-cache removal. Operator receipts
   must not conceal missing implementations. The default first-party purge only
   completes accounts with no unresolved financial references.
3. Approve actual retention periods, including the minimal completion/suppression
   records and private receipts; configure expiry jobs and backup restore tests.
   The queue records external expiry dates but does not delete provider records
   when those dates arrive. Do not advertise a blanket six-month retention period.
4. Configure `ENTAP_DELETION_OPERATOR_TOKEN`; deploy Rank migration/code first,
   then set `VS_PLAYER_SESSION_STATUS_URL` to the **full** identity route
   `https://IDENTITY_HOST/v1/identity/session/status` before deploying VS. A VS
   deploy without this URL blocks production player requests. The route needs
   private-body logging exclusions and deployment-appropriate rate limiting.
5. Align/deploy website copy and verify the selected deletion inbox is monitored.
   Concurrent website work chose a temporary inbox; this implementation sends no
   email and does not overwrite that selection. Keep released wording consistent
   with the actual account scope and pre-confirmation retention disclosures.
6. Merge into the Android release worktree and test a real device, second device,
   lost confirmation response, backend outage, expired challenge, partial external
   cleanup, paid account, backup restore and the final status response.
   Then enable request intake and verify `account_deletion_requests_enabled` in
   Rank's health response before changing the Play Console declaration.

Keep the Play Console declaration unchanged until these gates pass. Local tests
are not evidence that the deployed game or all processors support deletion.

## Validation

`npm run smoke:account-deletion` uses a disposable embedded PostgreSQL database
and real HTTP routes. It tests proof, authorization, explicit confirmation,
revocation, public-rank exclusion, receipt privacy, retries, completion gates,
transactional purge and prevention of recreated IDs. The existing embedded
device/session test checks registration/session regression. The deletion suite
also creates separate ENTaP credentials, sessions, challenges and audit evidence
for the same principal, verifies they remain unchanged after both acceptance and
completion, rejects cross-application auth and revocation, and checks the database
rejects a session paired with another application's device. VS tests exercise
authoritative revocation and issuer outages plus the existing player auth flow.

`tools/account_deletion_ui_smoke_test.gd` requires a custom isolated user directory
named `SwarmfrontDeletionTest-*`; it refuses to run cleanup against a real profile.
It checks discoverability, cancellation, unverified-device rejection, touch sizes,
and scoped local-file cleanup. No production requests or destructive live tests
are part of this suite.
