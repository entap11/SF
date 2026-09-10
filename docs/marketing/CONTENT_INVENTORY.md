# Marketing Content Inventory

Status: Structure ready; source bank not located  
Audit date: 2026-08-07

## Source status

The production plan references an existing bank of roughly 12–15 manifesto/blogette pieces. Searches across the current repository, adjacent `SideProjects`, and Desktop Markdown/text/document filenames and distinctive doctrine phrases located only the marketing plan and kickoff prompt. The source bank's canonical location is therefore unknown.

No essay title, body, quote, publication state, or tester story has been fabricated. Content Gate M2 remains blocked on source discovery.

## Inventory schema

| Field | Type / allowed values | Required | Purpose |
| --- | --- | --- | --- |
| `content_id` | Stable string, e.g. `SF-DSP-001` | Yes | Internal identity that survives title/slug changes. |
| `principle_id` | One or more `SF-MKT-NNN` values | Yes | Links the piece to Marketing Canon claims. |
| `working_title` | String | Yes | Editorial title; not public until approved. |
| `wave` | `A`, `B`, or `C` | Yes | Campaign sequence. |
| `claim_status` | `SHIPPED`, `V1 COMMITMENT`, `FUTURE PRINCIPLE`, `VERIFY` | Yes | Must match the strictest linked claim. |
| `canonical_essay_path` | Repository-relative Markdown path | Yes after ingest | Single canonical website source. |
| `reddit_adaptation` | Path or `NOT_STARTED`, `DRAFT`, `APPROVED` | Yes | Discussion-oriented adaptation; never blind cross-post copy. |
| `gameplay_proof` | Asset IDs/paths plus capture SHA or `NEEDED` | Yes | Observable product receipt. |
| `video_opportunity` | `NONE`, `SHORT`, `LONG`, `SPOT`, plus note | Yes | Reuse opportunity without a quota. |
| `beta_evidence` | Consent-safe evidence ID or `NONE`/`NEEDED` | Yes | Feedback source; no PII or unauthorised quote in this tracker. |
| `product_verification` | Owner, decision, date, product revision | Yes before approval | Confirms current truth and scope. |
| `publication_state` | `UNLOCATED`, `INGESTED`, `DRAFT`, `FACT_CHECK`, `APPROVED`, `SCHEDULED`, `PUBLISHED`, `RETIRED` | Yes | Workflow state. |
| `proposed_publication_week` | ISO week or `TBD` | Yes | Planning only; not a launch announcement. |
| `performance_notes` | Free text/metrics links | After publication | Conversation quality, referrals, watch/read completion, corrections. |
| `source_provenance` | Original location, author/owner, modified date, checksum | Yes after ingest | Prevents loss or silent rewriting of the source bank. |
| `audience_problem` | One sentence | Yes | The player grievance/question the piece addresses. |
| `primary_cta` | Approved destination or `NONE` | Yes | Keeps one clear next action. |
| `rights_and_consent` | `N/A`, `PENDING`, `APPROVED`, with record ID | Yes | Required for tester quotes and third-party assets. |
| `seo_description` | Plain string | Before approval | Search/social summary that does not upgrade claim status. |
| `last_fact_check` | Date + product revision | Before scheduling | Prevents stale product claims. |

## Canonical tracker template

This table becomes populated only from located source material.

| Content ID | Principle ID | Working title | Wave | Claim status | Canonical essay path | Reddit adaptation | Gameplay proof | Video opportunity | Beta evidence | Product verification | Publication state | Proposed publication week | Performance notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| TBD | TBD | TBD — source not located | TBD | `VERIFY` | TBD | `NOT_STARTED` | `NEEDED` | TBD | TBD | Required | `UNLOCATED` | TBD | — |

## Source-bank intake ledger

These are discovery slots, not invented pieces.

| Intake slot | Source located? | Provenance captured? | Ingest status |
| --- | --- | --- | --- |
| SOURCE-01 | No | No | `UNLOCATED` |
| SOURCE-02 | No | No | `UNLOCATED` |
| SOURCE-03 | No | No | `UNLOCATED` |
| SOURCE-04 | No | No | `UNLOCATED` |
| SOURCE-05 | No | No | `UNLOCATED` |
| SOURCE-06 | No | No | `UNLOCATED` |
| SOURCE-07 | No | No | `UNLOCATED` |
| SOURCE-08 | No | No | `UNLOCATED` |
| SOURCE-09 | No | No | `UNLOCATED` |
| SOURCE-10 | No | No | `UNLOCATED` |
| SOURCE-11 | No | No | `UNLOCATED` |
| SOURCE-12 | No | No | `UNLOCATED` |
| SOURCE-13 | No | No | `UNLOCATED` |
| SOURCE-14 | No | No | `UNLOCATED` |
| SOURCE-15 | No | No | `UNLOCATED` |

## Ingestion process

1. Product/content owner identifies the canonical source folder/account and confirms permission to import.
2. Copy each source into a private intake branch or approved local staging area without editing; record original path, owner, modified date, and SHA-256.
3. De-duplicate exact and near-exact variants. Preserve the original; do not silently merge drafts.
4. Assign a stable `content_id`; capture the original title and body.
5. Map actual claims to one or more Marketing Canon IDs. If no ID exists, fill the next `TBD` principle only when the source supports it.
6. Apply the strictest linked claim status. Any `VERIFY` claim blocks publication.
7. Separate canonical essay from channel adaptations. The website Markdown remains the content authority.
8. Identify gameplay, beta, video, rights, and product-verification needs without manufacturing evidence.
9. Product owner and relevant system owner fact-check against a named revision.
10. Only then propose Wave A/B/C ordering and a 10–12 week cadence.

## Sequencing rules once content exists

- Wave A leads with a universal player grievance and one specific receipt.
- Wave B follows only when competition/economy claims have passed verification.
- Wave C uses studio thesis and beta/process evidence after the audience has seen product proof.
- Do not schedule two unresolved economy claims back-to-back.
- Keep at least four consecutive pieces publication-ready before campaign start.
- Every week has one primary argument; supporting clips or discussions are optional reuse.
- A changed product revision reopens fact-check for affected pieces.

## Exit criteria for Gate M2

- The actual 12–15 pieces are located and provenance is recorded.
- Every piece has a stable ID, principle mapping, wave, claim status, proof needs, and publication state.
- The first 10–12 week order is proposed from actual content.
- At least four consecutive pieces are fact-checked and approved.

