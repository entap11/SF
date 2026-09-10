
# Codex Kickoff — Swarmfront Marketing Phase 0 / First Production Checkpoint

Implement the first checkpoint defined by `SWARMFRONT_MARKETING_ROLLOUT_PRODUCTION_PLAN.md`.

This is a planning-and-scaffold checkpoint only. Do not publish, deploy publicly, announce a launch date, or build unnecessary infrastructure.

## Required outputs

Produce:

1. `MARKETING_CANON.md`
2. Website/tooling reuse audit
3. Website V0 architecture recommendation
4. Content-inventory structure for the existing manifesto/blogette bank
5. Hero-spot production backlog
6. A concise checkpoint report with decisions, unresolved questions, and the exact next implementation step

## Governance

Follow ENTaP reuse-first governance before building any testing, deployment, analytics, forms, hosting, content, or engineering plumbing.

Search, in order:

1. Current repository
2. Other ENTaP projects
3. Shared tooling/components
4. Historical tooling
5. Platform/framework-native tooling

Prefer:

- Use
- Configure
- Extend
- Extract proven shared components
- Adapt

Build a new parallel tool only when reuse is unsuitable and document why.

Do not create infrastructure merely because it may be useful later.

## Workstream A — Marketing Canon

Create a first-pass `MARKETING_CANON.md` containing:

### Core positioning

- One-sentence Swarmfront pitch
- ENTaP studio thesis
- Campaign doctrine: make specific promises and show the receipts

### Claim-status system

Every public principle must be classified:

- SHIPPED
- V1 COMMITMENT
- FUTURE PRINCIPLE

Do not guess status when product truth cannot be proven from the repository/docs. Mark it `VERIFY` and identify the authority needed.

### Required doctrine sections

Include precise approved language for:

- No purchasable XP
- No hidden win/loss-based adaptive difficulty
- Tactical bot adaptation is allowed and desirable
- “Bots adapt to the battle, not to your retention profile”
- No fake gameplay ads
- One clear store/spend currency
- No currency-conversion shell game
- Competition is the core product
- Returning players should reach ordinary play in approximately 1–3 intentional actions
- No artificial friction created in order to sell its removal
- Marketing may dramatize but may not misrepresent gameplay

### 50-principle structure

Create a structured table with fields:

- ID
- Principle
- Category
- Public shorthand
- Claim status
- Product proof/source
- Proof asset needed
- Publication-ready?
- Notes

Use existing project documentation and current implementation as evidence where available.

Do not invent missing principles merely to reach 50 if the source material is insufficient. Preserve placeholders as `TBD` and report the gap.

## Workstream B — Website/tooling reuse audit

Before recommending a web stack, search for existing ENTaP assets and plumbing relevant to:

- Web repositories
- Lovable/TanStack projects
- Shared UI components
- Branding assets
- Domain/DNS setup
- Hosting/deployment
- Static-site tooling
- Markdown/content systems
- Analytics
- Contact/beta forms
- SEO/social metadata
- Media/video handling
- CI/CD

Produce a reuse matrix:

| Capability | Existing option | Location | Proven? | Reuse path | New work needed? |

Do not start a new site framework before the audit is complete.

## Workstream C — Website V0 architecture decision

Recommend the smallest proven stack that can support:

- Home
- Game
- Manifesto
- Dispatches
- Community
- About/Contact
- Markdown/content-driven posts
- Responsive mobile-first presentation
- Video embeds
- SEO metadata
- Social-card metadata
- Sitemap
- Privacy-conscious basic analytics
- Simple beta/contact CTA
- Automated or one-command deployment

Explicitly reject unnecessary:

- Custom CMS
- Authentication
- Application backend
- Bespoke analytics
- 3D homepage
- Large animation framework
- New database
- Parallel deployment tooling

If an existing ENTaP stack satisfies the need, use it unless there is a code-grounded reason not to.

Do not deploy publicly during this checkpoint.

## Workstream D — Content inventory structure

Create the content-tracking structure for the existing manifesto/blogette bank.

Do not fabricate the actual 12–15 pieces if they are not present in the repository.

Define fields for:

- Principle ID
- Working title
- Wave A/B/C
- Claim status
- Canonical essay path
- Reddit adaptation
- Gameplay proof
- Video opportunity
- Beta evidence
- Product verification
- Publication state
- Proposed publication week
- Performance notes

Propose the process for ingesting the existing pieces once their source location is identified.

## Workstream E — Hero-spot production backlog

Audit existing Blender/marketing-spot documentation and assets where accessible.

Create a bounded backlog covering:

- Bee skeleton/rig artifacts visible in renders
- Skinning
- Model/art defects
- Lighting
- Animation
- Render consistency
- Compositing
- Export formats
- Reuse/adaptation across roughly 3–5 distinct spots
- Clean gameplay integration
- Final render QA

Separate:

- Blocking defects
- Production polish
- Adaptation work
- Future enhancement

Do not edit Blender assets during this checkpoint unless explicitly authorized.

## Stop conditions

Stop and report rather than guessing if:

- The authoritative starting repository/location for the website is unclear after reuse audit
- Existing domain/hosting ownership cannot be established
- A claim cannot be verified
- Existing dirty work would be overwritten
- Required manifesto source files cannot be located
- Hero-spot source assets are not available

## Scope restrictions

Do not:

- Publish content
- Push public deployment
- Announce December 1, 2026
- Open or promote social accounts without explicit approval
- Create a new backend
- Create a database
- Add authentication
- Build marketing automation
- Modify Swarmfront gameplay
- Modify unrelated product code
- Commit or push unless explicitly authorized

## Checkpoint report

Return:

1. Files created/changed
2. Reuse findings
3. Proposed website stack and why
4. Marketing Canon status
5. Claims requiring verification
6. Content-inventory status
7. Hero-spot backlog summary
8. Unresolved decisions
9. Exact next recommended implementation step

The checkpoint should leave us ready to approve Website V0 scaffolding and content population without having created unnecessary infrastructure.
