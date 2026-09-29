# Cloudflare DNS and Canonical-Host Handoff

Status: Deployment target, Pages identity, and empty zone confirmed; DNS changes not yet authorized  
Date: 2026-08-07

## Selected deployment target

- Host: Cloudflare Pages with Git integration.
- Site: Astro static output; no Cloudflare adapter, Worker, Pages Function, application backend, or database.
- Production origin: `https://swarmfront.games`.
- Secondary hostname: `www.swarmfront.games`, permanently redirected to the apex while preserving path and query string.
- Build: production branch `main`; command `npm run build`; directory `dist`.

Cloudflare's official Pages workflow requires each custom hostname to be associated in **Workers & Pages → Pages project → Custom domains** before relying on its CNAME. When the zone is in Cloudflare, the flow creates the CNAME after confirmation. Manually creating the Pages CNAME first can fail with a `522`. Source: [Cloudflare Pages custom domains](https://developers.cloudflare.com/pages/configuration/custom-domains/).

## Current evidence

Owner statement: `swarmfront.games` and `entap.games` were purchased through Cloudflare. Public DNS on 2026-08-07 delegates `swarmfront.games` to:

- `anirban.ns.cloudflare.com`
- `coraline.ns.cloudflare.com`

Cloudflare dashboard screenshots supplied on 2026-08-07 confirm:

- `swarmfront.games` is Active at Cloudflare Registrar on the Free plan.
- The zone uses Cloudflare Full DNS setup.
- The DNS Records table contains exactly **0 of 200** records.
- There are therefore no apex, `www`, CAA, TXT, MX, or other records to preserve or conflict with at this checkpoint.
- The account home shows no existing Worker/Pages deployment; the Workers area offers “Ship something new.”

The private website repository exists at `entap11/swarmfront-site`, its production branch is `main`, and its Cloudflare Pages project hostname is `swarmfront-site.pages.dev`. The corrected production deployment from commit `8ceef16` was externally verified on 2026-08-07: the alias returned HTTP 200, required static routes loaded, canonicals and Open Graph URLs were rooted at `https://swarmfront.games`, `robots.txt` blocked crawling, and the sitemap was present.

## Evidence required from Cloudflare

Zone access, the empty DNS table, Pages identity, and a working preview are confirmed. Remaining evidence:

1. **SSL mode, before custom-domain attachment:** `swarmfront.games` → SSL/TLS → Overview. Record the current encryption mode.
2. **Edge certificate state:** `swarmfront.games` → SSL/TLS → Edge Certificates. Record Universal SSL plus Always Use HTTPS, minimum TLS, TLS 1.3, and HSTS.
3. **Existing redirects:** `swarmfront.games` → Rules → Redirect Rules. Confirm the list is empty or supply any enabled/disabled/draft rules.

Do not send an API token, password, recovery code, or secret key.

## Intended records — not yet authorized or exact

The zone is confirmed empty, so no record removal or collision handling is expected. The Pages target is now exact.

| Hostname | Type | Name | Target/content | Proxy | TTL | Verification |
| --- | --- | --- | --- | --- | --- | --- |
| `swarmfront.games` | `CNAME` at apex using Cloudflare flattening | `@` | `swarmfront-site.pages.dev` | Proxied | Auto | Normally created/validated by Pages custom-domain flow; inspect generated status/records. |
| `www.swarmfront.games` | `CNAME` | `www` | `swarmfront-site.pages.dev` | Proxied | Auto | Add `www.swarmfront.games` under Pages Custom domains before/with the generated CNAME. |

The confirmed empty zone has no restrictive CAA or existing TXT verification record. For a Pages project and zone in the same Cloudflare account, no manual verification record is expected: add each hostname through Pages Custom domains and allow Cloudflare to create/validate its record. If the Pages UI nevertheless presents a generated verification record, capture and use that exact value rather than substituting one.

## SSL/TLS requirements

Final settings, after the zone is visible and Pages custom domains are active:

- Universal SSL certificate status must be Active and cover both `swarmfront.games` and `www.swarmfront.games`.
- Use Automatic SSL/TLS at its secure setting or Custom **Full (strict)**; never Flexible.
- Enable Always Use HTTPS after both hostnames answer successfully over HTTPS.
- Enable TLS 1.3; minimum TLS 1.2 unless a documented compatibility requirement says otherwise.
- Leave HSTS off until HTTPS, apex, `www`, redirects, rollback, and certificate renewal behavior pass. Enable later only through a separate irreversible-risk review.
- Do not add a separate origin certificate: Pages owns the platform origin and certificate workflow.

Cloudflare's Universal SSL covers the zone apex and first-level subdomains on a full setup. Source: [Cloudflare Universal SSL](https://developers.cloudflare.com/ssl/edge-certificates/universal-ssl/).

## Canonical redirect configuration

After both custom domains are Active and proxied, create one Cloudflare Single Redirect:

| Field | Value |
| --- | --- |
| Rule name | `www-to-apex` |
| Match type | Custom filter expression |
| Expression | `(http.host eq "www.swarmfront.games")` |
| Target type | Dynamic |
| Target expression | `concat("https://swarmfront.games", http.request.uri.path)` |
| Status | `301` Permanent Redirect |
| Preserve query string | Enabled |

Single Redirects require proxied hostname traffic. Source: [Cloudflare Redirect Rules dashboard](https://developers.cloudflare.com/rules/url-forwarding/single-redirects/create-dashboard/).

The Astro site must independently emit:

- canonical URLs rooted at `https://swarmfront.games`;
- `og:url` rooted at the apex;
- sitemap URLs rooted at the apex;
- `robots.txt` pointing to `https://swarmfront.games/sitemap-index.xml`;
- no `swarmfront.com` or `www.swarmfront.games` canonical URLs.

The default `*.pages.dev` production URL should not be marketed or indexed as canonical. Decide whether to add an account-level redirect for it only after preview-deployment behavior is understood; do not accidentally redirect branch preview hostnames.

## Exact-record release gate

Inspect the SSL and redirect screens, then issue the final copy-ready DNS/redirect instructions and attach each hostname through Pages Custom domains only after explicit authorization. No DNS mutation is authorized by this document.
