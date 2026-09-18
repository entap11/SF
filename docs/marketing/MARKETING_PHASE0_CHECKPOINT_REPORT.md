# Marketing Phase 0 Checkpoint Report

Status: Checkpoint complete; implementation gates remain open  
Date: 2026-08-07

## 1. Files created/changed

Created, without modifying gameplay or existing product code:

- `docs/marketing/MARKETING_CANON.md`
- `docs/marketing/WEBSITE_TOOLING_REUSE_AUDIT.md`
- `docs/marketing/WEBSITE_V0_ARCHITECTURE.md`
- `docs/marketing/CONTENT_INVENTORY.md`
- `docs/marketing/HERO_SPOT_PRODUCTION_BACKLOG.md`
- `docs/marketing/MARKETING_PHASE0_CHECKPOINT_REPORT.md`

The imported production plan and kickoff prompt remain under `docs/planning_import/`. No content was published, no website was scaffolded, no account/domain/hosting state was changed, no Blender source was edited, and no deployment was performed.

Existing unrelated dirty gameplay/UI work was detected before the checkpoint and left untouched.

## 2. Reuse findings

- Current Swarmfront repository: no website framework; does contain the canonical logo, licensed fonts, Game Skin/UX doctrine, Blender sources, GLB exports, backend deployment knowledge, social-video/highlight tooling, and extensive product evidence.
- Adjacent ENTaP work: `BDR/BDR-App` is a current Lovable/TanStack Start/React/TypeScript/Vite/Tailwind/shadcn application. It is credible reference code but carries an application backend, auth, Supabase, server functions, and business-specific UI that V0 does not need.
- Historical tooling: `BDR/matts-sandbox` is not an appropriate canonical seed.
- Domain/hosting: owner confirms `swarmfront.games` and `entap.games` were purchased through Cloudflare. Dashboard evidence confirms `swarmfront.games` is Active at Cloudflare Registrar, has Full DNS setup, and contains exactly zero DNS records. The account shows no existing Worker/Pages deployment. Repository `.com` references are not Website V0 canonicals.
- Content: the stated 12–15 manifesto/blogette source files were not located.
- Hero pipeline: canonical LFS assets and supporting textures/lighting exist. The local Blender 4.2.17 runtime cannot open the Blender 5.0.1-authored sources, so internal read-only inspection is deferred rather than converting them.

## 3. Proposed website stack and why

Recommendation: Astro static output, TypeScript, local Markdown content collections, semantic HTML, a small CSS layer, official sitemap integration, standard video embeds, and no client framework by default.

It directly fits the six-page editorial site, generates static post routes and metadata, validates content structure, and avoids a CMS, backend, database, authentication, bespoke analytics, and the BDR app's unrelated surface area.

Deployment target is selected and verified: Cloudflare Pages with Git integration, Astro static output, production branch `main`, build command `npm run build`, and output directory `dist`. No Cloudflare adapter, Worker, Pages Function, or application backend is required. The canonical private repository is `entap11/swarmfront-site`; its neutral scaffold is deployed at `swarmfront-site.pages.dev` and externally returns the intended static output. Account and empty-zone access are proven. Custom domains and DNS remain untouched.

## 4. Marketing Canon status

- Core pitch, studio thesis, campaign doctrine, status model, controlled bot/currency/ad/XP/action-count language, public-copy rules, and prohibited claims are drafted.
- The register contains 31 source-grounded candidates and 19 explicit `TBD` placeholders.
- No principle is publication-approved.
- Gate M0 remains open pending product-owner approval and claim resolution.

## 5. Claims requiring verification

| Claim family | Why blocked | Required authority/evidence |
| --- | --- | --- |
| No purchasable XP | Match-earned XP is documented, but absence of all purchase/grant paths and final policy is not certified. | Product + economy owner; SKU/grant audit. |
| No result/retention-based adaptive difficulty | Chosen tiers/styles and tactical decisions exist; complete negative claim needs all decision inputs audited. | Product + bot/matchmaking owner; code/config/experiment audit. |
| Bots adapt to battle, not retention profile | Tactical half is evidenced; retention-profile absence is not fully certified. | Product/data/bot owner. |
| One store/spend currency | Honey, Wax, Nectar, XP, rank, and money-game concepts need a final public taxonomy. | Economy owner and final value-flow diagram. |
| No conversion shell game | Multiple economy drafts exist; final conversion graph is not approved. | Economy owner; implementation audit. |
| Competitive advantage is not sold / no pay-to-win | Older V1 spec permits minor, capped buff packs and buff purchase systems exist. | Product/economy owner must resolve policy and per-mode effect. |
| Return to play in 1–3 actions | “Ordinary play” and cold/warm routes are undefined and unmeasured. | UX/product owner; device recordings. |
| No artificial friction sold back | Doctrine exists only in the marketing plan. | Studio/product policy plus UX/economy audit. |
| Advertising truth | Governance is clear, but no final spot/capture candidate has passed. | Creative + product-truth + release approval. |

## 6. Content-inventory status

The schema, tracker template, 15 discovery slots, provenance requirements, ingestion process, sequencing rules, and Gate M2 exit criteria are ready. The actual source bank is missing, so titles, essays, Reddit versions, beta evidence, and a 10–12 week sequence were deliberately not fabricated.

## 7. Hero-spot backlog summary

The backlog contains 24 bounded items separated into blocking defects, production polish, adaptation work, and future enhancements. The critical path is:

`Supported Blender audit → reproduce/remove rig artifacts → validate skinning/models/paths → lock render preset → lighting/animation/composite/master QA → Marketing Capture Candidate → distinct spot adaptations`

The deferred in-game cinematic-trigger concept is kept out of trailer V1 scope.

## 8. Unresolved decisions

1. Who approves Marketing Canon v1 and owns claim re-verification?
2. Where is the canonical source bank of 12–15 manifesto/blogette pieces?
3. Who owns ongoing Cloudflare Pages deployment administration and approvals?
4. What contact email or beta destination is approved, with what privacy/retention terms?
5. Is web analytics omitted or approved through a named provider/account?
6. Which supported Blender 5.x environment and asset owner will perform the source audit?
7. How are paid buff packs reconciled with the intended competitive-integrity claim?
8. What exact path counts as “ordinary play” for the 1–3-action promise?

## 9. Exact next recommended implementation step

Hold a single owner approval checkpoint that records, in writing:

- the canonical website repository/location;
- recovered Cloudflare access, verified zone/account ownership, and the Website V0 deployment owner;
- the contact/beta destination;
- the location of the existing content bank; and
- product/economy decisions for `SF-MKT-001`, `002`, `004`, `008`, `009`, `010`, `012`, and `013`.

After those decisions—and not before—the exact code step is to scaffold the neutral Astro Website V0 shell for `https://swarmfront.games` with Home, Game, Manifesto, Dispatches, Community, and About/Contact routes; validated `principles` and `dispatches` Markdown collections; one metadata layout; official sitemap generation; static approved brand placeholders; and no backend, auth, database, or public deployment.

## Gate result

Phase 0 planning/scaffold checkpoint: **COMPLETE**.  
Gate M0 Marketing Canon: **OPEN**.  
Gate M1 Website skeleton: **NOT STARTED — STOP CONDITION ACTIVE**.  
Gate M2 Content bank: **BLOCKED — SOURCE LOCATION UNKNOWN**.  
Gate M3 Hero pipeline: **OPEN**.
