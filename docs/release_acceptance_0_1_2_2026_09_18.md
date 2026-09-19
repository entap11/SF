# SwarmFront 0.1.2 acceptance handoff — September 18, 2026

Backend acceptance has passed for request intake, immediate account suppression,
device/session revocation, and rejection of unexpired credentials. Physical iOS
acceptance remains incomplete. No store upload occurred.

## Deployed revisions and rollback evidence

| Service | Live source revision | Live deployment |
| --- | --- | --- |
| Rank / Identity | `d0009218c9a5d9081854d4e02fd186736a76f771` | `dep-damtdlp42hec73ceg9tg` |
| VS | `a80c90f783f617c98d4cf48471a06267b9a0e8dc` | `dep-damtbrajnfac73ej71sg` |

VS source is identical at both commits. The Rank-only follow-up maps revoked
session errors to HTTP 403 instead of HTTP 500 on protected platform routes.
The initial deletion deployment was `dep-damtaf6k1f9s73eld240`.

Both services previously ran `761e2d82b909efd579b4c03a79d534e719a7aba0`.
Recorded pre-change deployments: Rank `dep-da7h3obm6pss73fmjbg0`; VS
`dep-da7h52jm6pss73fmnqfg`. Private configuration snapshots and the logical
database backup are in restricted local storage at
`~/.local/share/swarmfront-release-acceptance/2026-09-18/` on the operator Mac.
Do not commit or distribute that directory.

The 34,639,254-byte database backup has SHA-256
`c664f1b75c7a60759f3f2c0680b52a830611556693ed92bf2b7d793cae067ddd`.
It was taken before capability/schema changes, over verified TLS, and restored
successfully into isolated PostgreSQL 18.4. This is a verified logical rollback
copy, not a claim that a current Render PITR recovery has been exercised.

Do not blindly restore the original service configuration: its startup commands
overrode false environment variables and enabled settlement/delivery. Preserve
the closed gates on rollback. After accepting deletion, a rollback must also
preserve suppression and revocation; old code that accepts those JWTs must not
be exposed. Restore deletion suppression before exposing any restored data.

## Minimal backend scope and migrations

The backend branch starts from the deployed revision and applies only the
existing Swarmfront-scoped deletion/session change, its tests, a stale health
allowlist correction, and the one-line HTTP error mapping correction. It does
not deploy the historical deletion commit wholesale, which would revert newer
rollout safeguards. Mobile source and engine code were not changed.

Rank migrations `010_account_deletion.sql` and
`011_swarmfront_account_boundary.sql` were rehearsed against the restored actual
certification database. All existing rows across 60 tables were identical after
the rehearsal; all 10 game profiles mapped to shared identity principals.
The same invariants were checked in the live migration transaction. Neither
migration deletes unrelated records. Existing credentials are classified as
Swarmfront, matching the current certification architecture.

The database operator applied the migrations because it owns the existing
tables. Required CRUD grants on the new tables were given to the existing Rank
runtime role. No unrelated role/key rotation or debug bypass was introduced.
VS required no schema migration.

## Safeguards

Source inspection established independently gated economy paths despite the
legacy primary flags being false. Rank's DB capabilities `HONEY_EARN`,
`HONEY_SPEND`, `NECTAR`, and `WAX_STANDARD` were disabled; `WAX_CRUCIBLE` remains
false. All five are false in final live health.

Rank verified-match mutations are false. VS platform economy delivery, rank
mutations, and durable public 1v1 support are false, including startup-command
overrides. Primary economy mutations, all public-mode gates, public leaderboards,
contest rewards, bot fallback, and Crucible settlement remain false. Dedicated
service/player verification and admin authentication remain configured.

Remote ops remains enabled: its effective rollout is the AND of remote settings
and deployment caps, so it cannot open false deployment caps. Contest storage
authorization alone does not open the closed contest handler.

## Live acceptance evidence

The hosted test used two fresh disposable identities and real P-256 device proof.
It verified registration, successful authentication, two simultaneous sessions
for the deletion subject, and authorized access before deletion. Then it checked:

- Authenticated deletion challenge and explicit device-signed confirmation.
- HTTP 202 scoped pending receipt, suppressed game profile, retained shared ENTaP
  principal, and all six fulfillment tasks.
- All subject Swarmfront devices/sessions revoked in authoritative PostgreSQL.
- Both subject tokens rejected by session status; the original still-unexpired
  token rejected with HTTP 403 by Rank's protected route and VS.
- Revoked device denied a new authentication challenge.
- Repeated confirmation safely returning the same pending receipt after a
  service redeployment; private status still available after revocation.
- Wrong receipt concealed with the contract's intended HTTP 404. This is distinct
  from the missing-route HTTP 404 observed before deployment.
- Control identity remained authenticated, no unrelated account was marked for
  deletion, and all ten pre-existing profiles matched the rollback snapshot.
- Final closed health gates and HTTP 503 for authenticated cash-escrow and public
  matchmaking attempts.

Both disposable test accounts were then put through the deletion flow, leaving
their credentials revoked. Their two requests remain pending manual fulfillment.
No completed purge, anonymization, external disposal, or backup expiry is claimed.
The dedicated deletion-operator credential and private receipts are stored only
in the restricted local operator directory and configured service environment.
Handle the queue according to `docs/account_deletion.md`; never mark unperformed
cleanup complete. Intake is enabled on the protected certification service.

Backend builds, embedded deletion and device-session tests, VS session-status
tests, Rank/VS quarantine tests, and fail-closed authentication tests passed.
The live test exposed the HTTP 500/403 mapping defect, which was corrected and
verified using the same unexpired token after deployment.

## Physical devices and immutable release

The existing iOS archive installed and launched on the paired physical iPhone as
`com.matthew.swarmfront`, version `0.1.2`, build `2026091801`. It upgraded the
existing installation without deleting its data. The owner exercised main-menu,
background/foreground, and quit/relaunch behavior, but could not start Free Roll
human 1v1. The device's existing registration authenticated twice after installation
and had a live session, supporting native key signing, persistence, and reconnect.

Free Roll human 1v1 checks the intentionally closed public gate. CTF bot practice
also checks the closed bot-fallback gate. Neither was opened to obtain a pass.
The phone left with the owner before fresh-install bootstrap, ordinary gameplay,
in-app deletion, local cleanup, and post-deletion/new-user behavior could be
completed. Do not report physical iOS acceptance as passed.

The current deletion UI remains on its private receipt screen after acceptance;
it does not automatically register another player. Any later fresh-install test
must preserve receipt evidence and follow the actual product flow.

Android was detected but adb still reported `unauthorized`; no Android install or
acceptance pass occurred. The owner explicitly allows Android physical acceptance
to follow a future Google Play Internal Testing upload of the exact AAB. Android
is not an independent blocker to finishing backend/iOS work or that later internal
upload. No upload is authorized by this handoff.

The mobile release worktree remains clean at
`c758b75a4f3e6f0b3ef4cc5e24ec2183da48bfcb`. Final AAB, IPA, project ZIP, and archive
ZIP SHA-256 hashes still match the original manifest. No mobile rebuild or
re-signing occurred. The archive's development-signed executable matches the
distribution IPA executable after signatures are removed from temporary copies,
and its packaged PCK is identical.

## Resume tonight

1. Reconnect/unlock the iPhone and resume the missing physical acceptance checks.
   Resolve an allowed gameplay route under the closed-gate policy; do not silently
   enable public matchmaking, bot fallback, economy, or debug bypasses.
2. Complete device-signed in-app deletion and verify local cleanup, revoked device
   access, relaunch behavior, and the designed receipt/new-user transition. The
   existing phone profile is not a newly created disposable account; account
   removal must be intentional.
3. Review the pending operator queue and actual fulfillment/retention procedures.
   Pending receipt acceptance is not completed data removal.
4. Only after the owner accepts the remaining results, proceed under a separate
   upload instruction: TestFlight, Google Play Internal Testing, then physical
   Android acceptance of the actual Play-distributed build.

Sanitized local evidence is in `artifacts/releases/0.1.2/acceptance/`, particularly
`backend-acceptance-final.json` and the final handoff report. Those artifacts are
outside this source worktree. Never include the private operator directory in a
store upload or repository commit.
