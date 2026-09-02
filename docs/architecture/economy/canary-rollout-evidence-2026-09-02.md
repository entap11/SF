# Economy Canary Rollout Evidence — 2026-09-02

Status: **FOUR NON-CRUCIBLE CAPABILITIES ACTIVE IN CERTIFICATION; RECONCILIATION GREEN**

This is a dated supplement to the August 17 certification report. That report
correctly records the read-only baseline before capability canaries. The
certification environment subsequently advanced on August 25; it should not be
described as still waiting for those same canaries.

This evidence applies only to the protected certification environment. It does
not authorize public game modes, paid entry, public leaderboards, or an overall
release.

## Deployed boundary

On September 2, both certification services reported live commit
`761e2d82b909efd579b4c03a79d534e719a7aba0`.

Rank/Platform health reported:

- epoch `beta_launch_0001`, state `ACTIVE`, season `BETA_S1`;
- `HONEY_EARN`, `HONEY_SPEND`, `NECTAR`, and `WAX_STANDARD` enabled;
- `WAX_CRUCIBLE` disabled;
- legacy Rank economy mutation mode disabled; and
- public leaderboards disabled.

VS health reported:

- Platform-economy delivery enabled;
- Rank mutation delivery enabled;
- rollout scope `POST_CUTOVER` with no player allowlist;
- public 1v1, larger modes, CTF/HCTF, Crucible, contests, rewards, and public
  leaderboards disabled.

The enabled Platform capability state and the disabled public-mode state are
separate controls. Neither should be inferred from the other.

## Retained August 25 canary sequence

Render's retained one-off-job history shows the bounded sequence and successful
job status without recording user/player identifiers here:

| Purpose | Job | Result |
| --- | --- | --- |
| Initial Platform snapshot | `job-da6tjggn74is73ejgl5g` | Succeeded |
| Enable Honey earn + Nectar | `job-da6tkirl550s73fcqnq0` | Succeeded |
| Managed two-player economy fixture | `job-da6tlgon74is73ejmql0` | Succeeded |
| Deliver Platform economy canary | `job-da6tn995efls73ct245g` | Succeeded |
| Honey policy/idempotency canary | `job-da6trqijnfac738bdm7g` | Succeeded |
| Enable Honey spend | `job-da6tsv8n74is73ekdq60` | Succeeded |
| Standard Wax delivery/settlement canary | `job-da6u4lgu01pc73dq0nk0` | Succeeded |
| Enable Standard Wax | `job-da6u00favr4c739kt6f0` | Succeeded |
| Disable-all containment checkpoint | `job-da6u67gn74is73elaaj0` | Succeeded |
| Final four-capability enable | `job-da6uf60ae00c7385rg4g` | Succeeded |
| Publish automatic Standard Wax config | `job-da6uf60n74is73em4s60` | Succeeded |
| Post-cutover managed fixture | `job-da6uhoon74is73emcnug` | Succeeded |
| Final delivery/settlement audit | `job-da6ul70u01pc73drhcbg` | Succeeded |
| Final Platform reconciliation | `job-da6ul715efls73cvo7s0` | Succeeded |

The sequence includes an explicit disable-all containment checkpoint before the
final enable. Crucible Wax was not part of this canary and remains disabled.

## Fresh read-only evidence

A new read-only Platform snapshot ran on September 2 as Render job
`job-dac99dnavr4c73fjk9rg` and succeeded. It returned:

- reconciliation `ok: true`;
- `0` unbalanced transactions;
- `0` incomplete receipts;
- `0` open Crucible contracts;
- `0` account drift; and
- matching conservation and journal totals for Wax, Honey, and Nectar.

No capability was enabled, disabled, or otherwise mutated during this check.
The existing canaries were not rerun because their intended capability state is
already active and the fresh reconciliation is green.

## Current disposition

- Nectar: active in certification; monitor and reconcile.
- Honey earn: active in certification; monitor and reconcile.
- Honey spend: active in certification; monitor and reconcile.
- Standard Wax: active in certification; monitor and reconcile.
- Crucible Wax: `HOLD`; requires its separate reservation, settlement, refund,
  and reserve-reconciliation canary.
- Public modes and overall release: unchanged; governed by the independent
  Public Modes P6/P7 decision.

