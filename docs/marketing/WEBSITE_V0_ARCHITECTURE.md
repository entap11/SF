# Website V0 Architecture Recommendation

Status: Repository, architecture, and deployment target selected; awaiting Cloudflare Pages project  
Decision date: 2026-08-07

## Decision

Use an **Astro static site with TypeScript, local Markdown content collections, semantic HTML, and a small site-owned CSS layer**. Use no client framework by default. Add JavaScript islands only when a concrete interaction requires them.

Deploy the static output through **Cloudflare Pages Git integration**. The owner-confirmed production game origin is `https://swarmfront.games`; the studio origin is `https://entap.games`. The canonical website repository is the private GitHub repository `entap11/swarmfront-site`, with a local clone at `/Users/matthewballou/SideProjects/SF/swarmfront-site`. Its neutral Astro scaffold was created and pushed on 2026-08-07. This does not authorize creation of the Pages project, public deployment, custom-domain attachment, or DNS changes.

## Why this is the smallest fit

- The site is mostly pages and editorial content, not an application.
- Astro's file routes directly cover Home, Game, Manifesto, Dispatches, Community, and About/Contact.
- Build-time content collections provide local Markdown, a validated schema, and static post routes without a CMS or database.
- Static output gives fast, cacheable pages and complete per-page metadata without a running application server.
- The official sitemap integration avoids bespoke sitemap code.
- Standard video embeds and static posters avoid a new media pipeline.
- `npm run build` (or the approved package-manager equivalent) produces one deployable `dist/` directory.

The architecture uses framework-native capabilities documented in [Astro content collections](https://docs.astro.build/en/guides/content-collections/), [Astro routing](https://docs.astro.build/en/guides/routing/), and [Astro sitemap](https://docs.astro.build/en/guides/integrations-guide/sitemap/).

## Why not copy the existing TanStack/Lovable app

`BDR/BDR-App` proves ENTaP-adjacent experience with React, TypeScript, Vite, TanStack Start, Tailwind, shadcn/Radix, and Lovable. It also carries SSR/server configuration, Supabase, authentication, application queries, email, AI gateways, and business-domain components. Those capabilities are appropriate for BDR but are unnecessary surface area for a static Swarmfront marketing V0.

Reuse from BDR should be limited to proven engineering conventions and, only if a need arises, a small accessible component pattern. Starting from its application repository would increase dependency, security, deployment, and upgrade scope without improving the required editorial site.

## Proposed routes

| Route | Source | V0 responsibility |
| --- | --- | --- |
| `/` | `src/pages/index.astro` | Game-first hero, approved media, pitch, 4–6 verified principles, gameplay proof, CTA. |
| `/game/` | `src/pages/game.astro` | Core gameplay, current modes/availability, screenshots/video, competitive premise. |
| `/manifesto/` | `src/pages/manifesto/index.astro` | Filterable-by-link/category index; no client app required. |
| `/manifesto/[id]/` | Content-driven static route | Focused canonical principle page, status-safe copy, sources/proof. |
| `/dispatches/` | `src/pages/dispatches/index.astro` | Editorial index for blogettes, FROM THE BETA, and design essays. |
| `/dispatches/[slug]/` | Content-driven static route | One Markdown article with metadata and related proof. |
| `/community/` | `src/pages/community.astro` | Only approved/active Reddit, YouTube, Discord, and beta links. |
| `/about/` | `src/pages/about.astro` | Minimal studio thesis and identity. |
| `/contact/` | `src/pages/contact.astro` | Configured email/external CTA; no stored submissions in V0. |
| `/404.html` | `src/pages/404.astro` | Clear recovery navigation. |

## Content model

Use two build-time collections:

### `principles`

Required frontmatter:

```yaml
id: SF-MKT-001
title: You cannot buy XP from us
category: progression
claimStatus: VERIFY
publicShorthand: You cannot buy XP from us.
summary: Internal draft only.
publicationState: blocked
proofSources: []
proofAssets: []
updated: 2026-08-07
```

### `dispatches`

Required frontmatter:

```yaml
title: Working title
description: Search/social description
slug: working-title
type: manifesto
wave: A
principleIds: [SF-MKT-001]
claimStatus: VERIFY
publicationState: draft
publishedAt: null
updatedAt: 2026-08-07
heroImage: null
videoUrl: null
```

The build must reject an unknown claim status, missing description, duplicate ID/slug, or `publicationState: published` paired with `VERIFY`.

## Presentation and reuse

- Copy the canonical logo into the approved web repository as a derived, optimized asset; do not link into the game repository at runtime.
- Self-host the minimum Chakra Petch/Iceland files and preserve OFL notices.
- Translate `docs/ui/SWARMFRONT_GAME_SKIN.md` into a small set of CSS custom properties after visual approval.
- Prefer system body text if the brand fonts reduce readability or performance.
- Use semantic landmarks, visible focus, reduced-motion support, responsive images, captions/transcripts, and keyboard-operable navigation from the first scaffold.
- Keep the visual connection to Swarmfront without imitating a game HUD.

## Metadata and discovery

One base layout owns:

- title and description;
- canonical URL rooted at `https://swarmfront.games`;
- Open Graph and social-card tags;
- page type, image, and alt text;
- robots directives;
- favicon/app icon references;
- a sitemap link.

Use the official Astro sitemap integration. Root canonical and sitemap URLs at `https://swarmfront.games`. Do not carry the repository's existing `swarmfront.com` placeholders into the scaffold. Keep `robots.txt` deployment-neutral until the production site is ready to be indexed.

## Video and media

- Use an approved YouTube embed or a plain linked poster as the V0 default.
- Load embeds on demand where practical to protect performance/privacy.
- Provide poster, title, caption/transcript link, aspect-ratio box, and non-JavaScript fallback.
- Store small approved images with the site; keep raw masters and clean gameplay captures in their governed production location.
- Do not create a custom streaming/transcoding service.

## Analytics

Default: **off**.

If the hosting/privacy owner approves Cloudflare, Cloudflare Web Analytics is a viable configuration-only option; its documentation currently states that it does not collect or use visitor personal data. This is not approval to create an account or install the beacon. No gameplay analytics service will be reused for the site.

## Contact and beta CTA

V0 uses configuration values for:

- `PUBLIC_CONTACT_EMAIL` rendered as `mailto:`; and/or
- `PUBLIC_BETA_URL` pointing to an owner-approved external signup destination.

Do not add a serverless function merely to receive a small contact form. A form may be added later only after owner, retention, privacy-copy, spam-control, and destination decisions are explicit.

## Build and deployment contract

Proposed local commands:

```text
npm install
npm run dev
npm run check
npm run build
```

Proposed output: `dist/`.

Deployment target: **Cloudflare Pages**, using Git integration and a static Astro build.

| Setting | Selected value |
| --- | --- |
| Production hostname | `swarmfront.games` |
| Secondary hostname | `www.swarmfront.games`, permanent redirect to apex |
| Production branch | `main` |
| Framework | Astro, static output; no Cloudflare adapter |
| Build command | `npm run build` |
| Build output directory | `dist` |
| Pages Functions / Worker | None |
| Application backend | None |
| Production auto-deploy | Keep disabled until quiet-launch approval; previews may be enabled after repository approval. |

Cloudflare Pages is selected because the domains are already delegated to Cloudflare, Pages has a platform-native Astro static build contract, it can attach both custom hostnames without introducing another origin provider, and it avoids a Worker/backend. Existing Render ownership remains confined to game backends. No Pages project or deployment is created in Phase 0.

## Explicitly rejected for V0

| Rejected item | Reason |
| --- | --- |
| Custom CMS | Git/Markdown and schema validation cover the known editorial workflow. |
| Authentication | No private user area is required. |
| Application backend | All required pages can be static. |
| New database or Supabase | Content is repository-owned; CTAs can link outward. |
| Bespoke analytics | Optional privacy-conscious page metrics are commodity configuration. |
| Bespoke form/email service | No approved submission owner, privacy policy, or retention need exists. |
| 3D homepage | Heavy, inaccessible, and redundant with approved video/gameplay. |
| Large animation framework | CSS and minimal native transitions are enough. |
| Custom video pipeline | YouTube plus governed export assets cover V0. |
| Parallel deployment tooling | Use the selected host's native static deployment after ownership approval. |
| Reusing BDR auth/Supabase/server code | It solves unrelated application problems and creates avoidable security/maintenance scope. |

## Remaining approval and configuration

The product/studio owner must still name or approve:

1. Cloudflare Pages project owner and actual default `*.pages.dev` hostname.
2. Contact email and/or beta destination owner.
3. Whether analytics remains omitted or an approved provider is used.

The neutral Astro skeleton now contains the required destinations, two validated content collections, base metadata layout, sitemap integration, static placeholders, and no backend. It uses npm and Node.js 22 or newer. All pages remain `noindex, nofollow`, and `robots.txt` disallows crawling until publication approval.

The DNS and redirect handoff is governed by `CLOUDFLARE_DNS_HANDOFF.md`. Do not manually add a Pages CNAME before the matching hostname has been associated under **Workers & Pages → project → Custom domains**; Cloudflare documents that doing so out of order can produce a `522`.
