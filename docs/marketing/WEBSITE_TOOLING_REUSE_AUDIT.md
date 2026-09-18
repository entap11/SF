# Website and Tooling Reuse Audit

Status: Phase 0 complete; Cloudflare Pages selected; no website scaffold, DNS change, or deployment created  
Audit date: 2026-08-07

## Search scope and decision order

The audit followed the kickoff order:

1. Current Swarmfront repository: `/Users/matthewballou/SideProjects/SF/project`
2. Other ENTaP/adjacent projects under `/Users/matthewballou/SideProjects`
3. Shared components and tooling exposed by those projects
4. Historical copies, including `BDR/matts-sandbox`
5. Framework/platform-native capabilities

The current `ENTaP_Reuse_First_Tooling_Governance_Draft_2026-07-20.md` is explicitly a draft input, but its search/reuse standard is binding for this checkpoint because the kickoff prompt makes it so. No new shared abstraction or parallel infrastructure was created.

## Findings

| Capability | Existing option | Location | Proven? | Reuse path | New work needed? |
| --- | --- | --- | --- | --- | --- |
| Web repository | No Swarmfront marketing-site repository or web root found. | Current repository and all Git roots under `SideProjects` | No | None until an owner selects the canonical location. | Yes: approve a location; do not scaffold yet. |
| ENTaP web stack | Lovable-exported TanStack Start app using React 19, TypeScript, Vite, Tailwind 4, shadcn/Radix, Supabase, and server functions. | `/Users/matthewballou/SideProjects/BDR/BDR-App` | Proven for an active private line-of-business application; not proven as a static marketing site. | Reuse its TypeScript/Vite conventions and selected accessible UI patterns only when they reduce work. | Yes: avoid copying its backend/auth/application surface. |
| Historical web copy | A second closely related TanStack/Lovable application tree. | `/Users/matthewballou/SideProjects/BDR/matts-sandbox` | Historical/branch-specific, not canonical for new use. | Do not start from it. | No. |
| Shared UI components | shadcn/Radix components exist in BDR (`button`, `card`, `navigation-menu`, `form`, etc.). | `BDR/BDR-App/src/components/ui` | Proven inside BDR. | Extract only a small component if its behavior is actually needed and license/provenance is retained; prefer native semantic HTML for V0. | Probably no extraction for V0. |
| Swarmfront brand master | Canonical 1024px raster logo. | `assets/branding/swarmfront_logo_1024.png`; authority in `assets/branding/README.md` | Yes. | Copy into the approved site repository as a derived web asset with provenance. | Web formats/sizes and social card still needed. |
| Fonts | Chakra Petch and Iceland font files plus OFL text. | `assets/fonts/` and `assets/fonts/brand/` | Yes in the game. | Self-host only the required weights and retain OFL notices. | Web subsetting/preload decision and browser QA. |
| Visual system | Game Skin, UX Bible, UI sprite inventory, adoption guide. | `docs/ui/` | Proven as product guidance. | Reuse palette/type/accessibility principles without turning the site into an in-game menu. | A small web token mapping is needed after visual approval. |
| Gameplay images/media | Numerous game assets and screenshots; no certified marketing capture set. | `assets/`, maps, and current game scenes | Mixed. | Use only assets that pass a marketing visual audit; retain capture/build provenance. | Yes: Marketing Capture Candidate. |
| Blender sources | Two LFS-managed bee `.blend` sources, textures, HDRI/EXR lighting, and GLB exports. | `assets/blender/bees`, `assets/blender/lighting`, `assets/models/bees` | Source presence is proven; internal production readiness is not. | Reuse one repaired hero pipeline for 3–5 spots. | Yes: Blender 5-compatible audit and defect work. |
| Video tooling | Social-video render worker and highlight URL/config machinery. | `tools/social_video_render_worker.gd`, `tools/analytics/src/highlights/` | Proven for game/highlight workflows, not a web media pipeline. | Reuse exported files and canonical link concepts; do not embed the game analytics service into the website. | Normal encode/poster/caption workflow still needed. |
| Domain references | Owner confirms `swarmfront.games` and `entap.games` were purchased through Cloudflare. Existing highlight config still points at `swarmfront.com`. | Owner statement; `tools/analytics/src/highlights/config.ts`; `data/ops/ops_config_*` | Domain choice/registrar is owner-confirmed. The `.com` references are stale or provisional until separately explained. | Use `swarmfront.games` for the game site and `entap.games` for studio/legal destinations. Do not carry `swarmfront.com` into Website V0. | Yes: audit and later correct downstream `.com` configuration under a separate product task. |
| DNS setup | Public DNS delegates both domains to Cloudflare. Owner-provided dashboard screenshots confirm `swarmfront.games` is Active at Cloudflare Registrar with Full DNS setup and exactly zero DNS records. | Public DNS, owner statement, Cloudflare dashboard screenshots dated 2026-08-07 | Registrar, delegation, account access, and empty zone proven. | Preserve the empty zone until the Pages project/default hostname exists; then use Pages Custom domains to generate the two records. | Yes: Pages project identity; no current record cleanup. |
| Hosting/deployment | Cloudflare Pages with Git integration for a static Astro build. Existing Render services remain game-backend infrastructure. | Owner-confirmed Cloudflare domains; official Cloudflare Pages Astro/custom-domain documentation; `render.yaml` | Cloudflare Pages is platform-proven for Astro; not yet configured in the ENTaP account. | Select Pages for Website V0. Use production branch `main`, build command `npm run build`, output `dist`; no Pages Functions or Worker. | Yes: recover account, create project after approval, record actual `*.pages.dev` hostname. |
| Static-site tooling | No static-site generator in the current or adjacent ENTaP repositories. | None found | No | Use a framework-native static system after approval. | Yes. |
| Markdown/content system | Markdown is used for repository docs, but there is no schema, renderer, frontmatter contract, or publication workflow. | `docs/` | Proven for documentation only. | Keep source content in Git/Markdown; add framework-native schema validation. | Yes: content collections and layouts. |
| Manifesto/blogette bank | The rollout plan says roughly 12–15 pieces exist, but source files were not found under `SideProjects` or Desktop searches. | Unknown | No | Ingest without rewriting once the owner supplies the source location. | Blocked on source location. |
| Web analytics | Swarmfront has gameplay analytics; BDR has app-specific monitoring/config. Neither is suitable for public web analytics reuse. | `tools/analytics`, BDR application code | Proven for different purposes. | Do not couple the website to either system. Keep web analytics off until hosting/privacy approval. | Optional provider configuration later. |
| Contact/beta forms | No reusable public contact/beta form or approved endpoint found. | None found | No | V0 may use configured `mailto:` and/or an owner-approved external beta URL. | Endpoint, retention notice, spam policy, and owner needed. |
| SEO metadata | Existing highlight config contains `.com` link concepts, but the owner-confirmed game hostname is `swarmfront.games`; there is no page metadata component. | Highlight config plus owner statement | Canonical hostname selected; website implementation absent. | Use `https://swarmfront.games` for Website V0 canonicals after the site exists. | Base metadata layout, per-page fields, robots, canonical tags. |
| Social metadata/cards | No Open Graph/Twitter card implementation or approved social-card asset found. | None found | No | Generate one static card from approved brand/game art; add per-page overrides later. | Yes. |
| Sitemap | No website sitemap tooling found. | None found | No | Use the selected framework's official sitemap integration. | Small configuration only. |
| Media/video delivery | YouTube is the planned primary video home; no approved channel/embed IDs or local web delivery policy found. | Marketing production plan | Planned, not proven | Embed approved YouTube videos with poster/fallback; do not invent a bespoke video service. | Channel/video approval and captions/posters. |
| CI/CD | Swarmfront GitHub Actions are game release-readiness checks; BDR build scripts are application-specific. | `.github/workflows/release-readiness.yml`; BDR `package.json` | Proven for their owners. | Reuse command conventions (`build`, `lint`, type check); add a tiny site-only check in the chosen repository. | Yes, after repository approval. |
| Privacy/legal destinations | Defaults reference `https://entap.games/privacy` and `/terms`; the owner confirms `entap.games` is an ENTaP domain. | `data/ops/ops_config_defaults.json`; owner statement | Domain ownership is owner-confirmed; page content is not verified. | Use the studio domain only after privacy/terms pages and legal ownership are confirmed. | Yes: legal-content approval. |

## Framework/platform-native review

Astro is the smallest reviewed fit for a content-heavy, mostly static site: its official content collections load and validate local Markdown, its default output can prerender static routes, and its official sitemap integration generates sitemap files from built routes. Sources: [Astro content collections](https://docs.astro.build/en/guides/content-collections/), [Astro routing](https://docs.astro.build/en/guides/routing/), and [Astro sitemap](https://docs.astro.build/en/guides/integrations-guide/sitemap/).

Cloudflare Pages is selected for Website V0. Its official Astro deployment contract uses production branch `main`, build command `npm run build`, and build directory `dist`; its custom-domain flow can associate an apex and subdomain from a Cloudflare-managed zone and create the CNAME after confirmation. Cloudflare Web Analytics remains optional and describes itself as privacy-first. Sources: [Cloudflare Pages Astro guide](https://developers.cloudflare.com/pages/framework-guides/deploy-an-astro-site/), [Cloudflare Pages custom domains](https://developers.cloudflare.com/pages/configuration/custom-domains/), [Cloudflare Pages Git integration](https://developers.cloudflare.com/pages/get-started/git-integration/), and [Cloudflare Web Analytics](https://developers.cloudflare.com/web-analytics/about/).

## Reuse decisions

- **Use:** Swarmfront logo master, licensed fonts, approved visual doctrine, product documentation, and future certified gameplay captures.
- **Configure:** Astro's native file routing, Markdown content collections, metadata layout, and official sitemap integration if the architecture is approved.
- **Deploy:** Cloudflare Pages Git integration, static assets only, with `main` → `npm run build` → `dist`.
- **Adapt:** BDR's TypeScript/Vite quality conventions and only the smallest useful accessible interaction patterns.
- **Do not extract yet:** a shared ENTaP UI package. One static site does not prove a shared abstraction.
- **Do not reuse:** BDR Supabase, authentication, server functions, email pipeline, AI gateways, business data components, or application backend.
- **Do not reuse:** Swarmfront gameplay analytics as web analytics.
- **Do not build:** a CMS, database, auth system, custom analytics, bespoke form backend, or custom video pipeline.

## Stop-condition result

The canonical domains and Cloudflare account/zone access are confirmed. The `swarmfront.games` DNS zone is empty and has no conflicts to remediate. Cloudflare Pages is Website V0's deployment target, and `entap11/swarmfront-site` is the canonical private website repository. Its Astro scaffold is deployed from `main` at `swarmfront-site.pages.dev` and externally verified. DNS and custom-domain actions still stop pending SSL/redirect review and explicit authorization. See `CLOUDFLARE_DNS_HANDOFF.md` for the remaining evidence.
