# Render Reactivation Ownership Matrix

Status: discovery baseline; unresolved ownership remains explicit.

`Current posture` describes repository architecture and known certification
contracts, not permission to activate a feature.

| Concern | Canonical owner | Persistence owner | Mutation authority | Result/settlement/receipt authority | Kill switch / gate | Current posture |
| --- | --- | --- | --- | --- | --- | --- |
| Player identity and device sessions | Rank/identity service | Rank PostgreSQL | Rank/identity authenticated endpoints | Rank/identity issues session receipts and player JWTs | Authenticated route capability; minimum client; credential availability | Implemented/certified default-off; mobile 4.7.1 credential integration incomplete on iOS |
| Device private credential | Player device secure hardware/store | iOS Keychain/Secure Enclave or Android Keystore | Native credential bridge only; private key never enters GDScript/backend | Device signature proves challenge possession; Rank validates | Release-export adapter gate | Android integrated; iOS 4.7.1 export integration unresolved |
| Match contract, roster, lifecycle | VS | VS PostgreSQL durable core | Authenticated VS lifecycle rules | VS contract/lifecycle receipts; terminal outcome still requires verifier | Durable core, authenticated slice, per-mode flags | Implemented and staging-certified all-off |
| Canonical command stream | VS | VS PostgreSQL repository | Authenticated player intents validated/frozen by VS | Durable idempotency receipt; verifier consumes stream | Durable public route and mode flag | Implemented and staging-certified all-off |
| Gameplay state | `OpsState`/`SimState` | Active client/worker process; durable inputs live in VS | Simulation systems only | No client result authority | Match contract/simulation compatibility | Authoritative-state rule frozen; worker/client revision alignment required |
| Synchronous match result | Trusted match-authority worker | VS result/verification tables | Worker replays exact stream or validates lifecycle | Worker signs immutable result; VS retains result/receipt | Match verification plus mode gate | Implemented; current certified worker is not yet aligned to current 4.7.1 candidate |
| Standard Rank mutation | Rank service | Rank PostgreSQL | Scoped VS-to-Rank settlement worker consuming verified result | Rank idempotent settlement/audit receipt | VS and Rank mutation gates, verified authority | Implemented/certified with mutations off |
| Normal player Wax | **UNRESOLVED production canonical ownership**; current Rank implementation owns normal Wax policy/balance | Current Rank PostgreSQL implementation | Verified Rank settlement in current design | Rank audit/settlement receipt | Rank economy and verified-mutation gates | Must be decided/reconciled before economy production work |
| Crucible Wax escrow/reserve | Current durable implementation: VS Crucible settlement repository | VS PostgreSQL | Scoped service operation after verified result | VS atomic escrow/settlement/refund/reversal receipts | Public Crucible and Crucible-Wax-settlement flags independently required | Durable implementation exists; relationship to canonical player Wax remains unresolved |
| Honey | **UNRESOLVED production canonical ownership**; product contract says player-owned | Current legacy VS memory/file store plus local profile mirrors; not acceptable for production | Current backend policy hooks are development/first-pass only | No accepted production ledger receipt authority | Honey reward/economy gates | Production durable ledger and ownership decision absent; HOLD |
| Free public contests | VS public-contest platform | VS PostgreSQL | Authenticated attempts/results; server closure/comparator | Verified evidence and VS contest/result/outbox receipts | Public contests plus family flags | Implemented/certified default-off; physical/managed rollout evidence pending |
| Time Puzzle/Gauntlet boards | VS contest platform | VS PostgreSQL | Versioned server comparator/closure | Contest result and leaderboard snapshot receipts | Public contests, leaderboard, family flags | Implemented default-off; device/rollover evidence pending |
| Free async 3/5 cohorts | VS contest platform | VS PostgreSQL | Server closes on fourth distinct qualified player | Contest closure and outbox receipts | Public contest and async-family flags | Implemented default-off; managed concurrency/device evidence pending |
| Economic async contests | **UNRESOLVED / EXCLUDED** | None accepted | None authorized | None authorized | Must have separate future gates | Outside reactivation and initial launch scope |
| 3P FFA / 2v2 / 4P FFA | VS contracts plus `OpsState` simulation | VS PostgreSQL for contracts/commands/results | Simulation systems; VS roster/lifecycle | Trusted verifier result; shadow analytics only initially | Independent mode flags | Implemented default-off; three/four-device certification pending |
| Human CTF | VS contracts plus `OpsState` simulation | VS PostgreSQL | Simulation systems | Trusted verifier | Public CTF flag | Implemented default-off; content/device certification pending |
| Human HCTF | **UNRESOLVED live hidden-state authority** | No accepted secrecy-preserving design | Not authorized publicly | Post-match verifier cannot provide live secrecy | HCTF flag plus explicit secrecy certification | HOLD |
| Public Rank leaderboard | Rank service | Rank PostgreSQL/cache | Verified Rank result consumers only | Rank read snapshot/audit | Rank public-leaderboard and VS public-leaderboard gates | Implemented/certified default-off |
| Remote operations/config | VS operations service/repository | VS PostgreSQL append-only revisions | Authenticated administrative role | Publication/history/reconciliation receipts | Static remote-ops cap plus all effective feature flags | Implemented/certified all-false |
| Operational evidence | Environment/operator-owned evidence store | External retained artifacts plus redacted Git summaries | Named operators only | Artifact digests and provider IDs | Evidence retention/review gate | Existing certification pattern; final ownership/SLOs require later freeze |

## Explicit unresolved decisions

1. Final canonical service and durable ledger for player Honey.
2. Final canonical service for player Wax and how normal Rank Wax and Crucible
   escrow reference one balance without creating two authorities.
3. Administrative identity/role provider for production operations.
4. HCTF live hidden-state authority design.
5. Production evidence-retention, appeal, and cleanup intervals.

None is resolved merely by reusing a current adapter or database table.
