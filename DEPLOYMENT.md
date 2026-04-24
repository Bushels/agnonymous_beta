# Deployment

Everything you need to ship the Agnonymous Flutter web app to production
and keep the `agnonymous.news` → `agnonymous.buperac.com` redirect alive.

**Canonical production URL:** https://agnonymous.buperac.com/
**Legacy URL (301 redirect):** https://agnonymous.news/ → agnonymous.buperac.com
**Firebase Hosting:** disabled (site exists but serves 404)

---

## TL;DR — deploy to production

```bash
# From repo root
bash scripts/deploy-web.sh
```

That script:

1. Loads `SUPABASE_URL` + `SUPABASE_ANON_KEY` from `.env`
2. Runs `flutter build web --release` with the env vars as `--dart-define`s
3. Stages `deploy/vercel.prod.json` → `build/web/vercel.json` (CSP + SPA rewrites)
4. Re-links `build/web/` to the Vercel `agnonymous` project if the link is missing
5. Runs `vercel deploy --prod --yes` from `build/web/`
6. Prints the deploy URL and smoke-tests `https://agnonymous.buperac.com/`

---

## Infrastructure overview

| Piece | Hosted on | Where to look |
|---|---|---|
| Flutter web app | Vercel project `agnonymous` (`prj_w6WXCPQ4TL0vj8ITJyFgThq3MYXT`) | https://vercel.com/kyles-projects-d3ab6818/agnonymous |
| `agnonymous.news` redirect | Vercel project `agnonymous-news-redirect` (`prj_i3MnXsJfdymcL04Wjp18tqgiu0yw`) | `C:/Users/kyle/Agriculture/agnonymous_news_redirect/` (lives outside this repo) |
| `agnonymous.buperac.com` DNS | Shopify (buperac.com managed zone) | https://admin.shopify.com/store/getsupplemented/settings/domains |
| `agnonymous.news` DNS | Squarespace (nameservers `ns-cloud-b*.googledomains.com` — legacy Google Domains artifact) | https://account.squarespace.com/domains/managed/agnonymous.news/dns/dns-settings |
| Backend (Supabase) | Supabase hosted | https://supabase.com/dashboard |
| Firebase Hosting (legacy) | `agnonymousbeta` project | Disabled via `SITE_DISABLE` release — serves 404 |

All Vercel projects belong to team `team_G5ANWxcnatlUPZiwb90vf4px` (slug `kyles-projects-d3ab6818`).

---

## Prerequisites

Install once per workstation:

```bash
# Flutter (3.38.5 verified)
# https://docs.flutter.dev/get-started/install

# Vercel CLI 48.x+
npm i -g vercel

# Authenticate Vercel (one time; writes ~/AppData/Roaming/com.vercel.cli/Data/auth.json on Windows)
vercel login
```

Project-local files you need:

- **`.env`** — `SUPABASE_URL` + `SUPABASE_ANON_KEY` (copy from `.env.example`; get values from the
  Supabase dashboard "Project Settings → API")
- **`build/web/.vercel/project.json`** — auto-created by `vercel link`. Contents should be:

  ```json
  {
    "projectId": "prj_w6WXCPQ4TL0vj8ITJyFgThq3MYXT",
    "orgId": "team_G5ANWxcnatlUPZiwb90vf4px",
    "projectName": "agnonymous"
  }
  ```

  The `deploy-web.sh` script recreates this file if it's missing. Note: `projectName` will read
  back as `"web"` on freshly-created links because the Vercel CLI names the project after the
  deploy directory (`build/web`). The actual project has been renamed to `agnonymous` via the
  Vercel API — this is cosmetic, not a problem.

---

## Manual deploy (if you don't trust the script)

```bash
# 1. Build with Supabase creds baked in as compile-time dart-defines
# (.env sourcing works in bash/git-bash; use `Get-Content .env | ...` in PowerShell)
set -a && source .env && set +a
flutter build web --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"

# 2. Stage the production vercel.json (CSP + SPA rewrites) into the build output
cp deploy/vercel.prod.json build/web/vercel.json

# 3. Deploy the pre-built output to Vercel
cd build/web
vercel deploy --prod --yes
```

After deploy:

- Production URL is the `Production:` line in the output (looks like
  `https://agnonymous-<hash>-kyles-projects-d3ab6818.vercel.app`)
- Canonical `https://agnonymous.buperac.com/` updates automatically via the aliased domain

---

## The `agnonymous.news` → buperac redirect

Lives in a **separate** Vercel project so the redirect config is isolated from the real app.

**Location on disk:** `C:/Users/kyle/Agriculture/agnonymous_news_redirect/`

**Entire project is two files:**

`vercel.json`:
```json
{
  "cleanUrls": false,
  "trailingSlash": false,
  "redirects": [
    { "source": "/",        "destination": "https://agnonymous.buperac.com/",       "statusCode": 301 },
    { "source": "/:path*",  "destination": "https://agnonymous.buperac.com/:path*", "statusCode": 301 }
  ]
}
```

`.vercel/project.json`:
```json
{
  "projectId": "prj_i3MnXsJfdymcL04Wjp18tqgiu0yw",
  "orgId": "team_G5ANWxcnatlUPZiwb90vf4px",
  "projectName": "agnonymous-news-redirect"
}
```

To redeploy: `cd C:/Users/kyle/Agriculture/agnonymous_news_redirect && vercel deploy --prod --yes`

**Do NOT put an `index.html` in this project.** Vercel's filesystem check runs before
`redirects`, so a static file at `/` would short-circuit the apex redirect.

---

## DNS — what lives where

### `agnonymous.buperac.com` (Shopify DNS for buperac.com)

| Type | Name | Value |
|---|---|---|
| CNAME | `agnonymous` | `cname.vercel-dns.com.` |

Shopify doesn't expose DNS editing via Admin GraphQL — it must be done in the UI at
`https://admin.shopify.com/store/getsupplemented/settings/domains/<domainId>/dns`.

### `agnonymous.news` (Squarespace; nameservers are legacy ns-cloud-b*.googledomains.com)

| Type | Name | Value | Purpose |
|---|---|---|---|
| A | `@` | `216.198.79.1` | Vercel apex #1 |
| A | `@` | `64.29.17.1` | Vercel apex #2 |
| CNAME | `www` | `cname.vercel-dns.com.` | Vercel www |
| TXT | `@` | `hosting-site=agnonymousbeta` | **Dead** — Firebase site verification, safe to delete |

Edit at `https://account.squarespace.com/domains/managed/agnonymous.news/dns/dns-settings`.
Squarespace UI has a Google OAuth step-up verification dialog that fires on every mutation.

---

## Production `vercel.json` (the one that ships in `build/web/`)

Kept at `deploy/vercel.prod.json` so it survives `flutter clean`. The deploy script copies it
into `build/web/` just before `vercel deploy`.

Matches the old Firebase Hosting CSP one-for-one so behavior is identical to pre-migration.

---

## Disaster recovery

### "I ran `flutter clean` and lost `build/web/.vercel/`"

```bash
mkdir -p build/web/.vercel
cat > build/web/.vercel/project.json <<'EOF'
{
  "projectId": "prj_w6WXCPQ4TL0vj8ITJyFgThq3MYXT",
  "orgId": "team_G5ANWxcnatlUPZiwb90vf4px",
  "projectName": "agnonymous"
}
EOF
```

Or just run `bash scripts/deploy-web.sh` — it recreates the link automatically.

### "Someone deleted the `agnonymous` Vercel project"

1. Create a new project named `agnonymous` in the `kyles-projects-d3ab6818` team
2. Disable SSO protection (project settings → Security → Vercel Authentication: off)
3. Add `agnonymous.buperac.com` as a domain (project settings → Domains)
4. Update this doc with the new `projectId`
5. Update `scripts/deploy-web.sh` with the new `projectId`
6. Update Shopify DNS for `agnonymous.buperac.com` if Vercel changes the recommended CNAME target
7. Run `bash scripts/deploy-web.sh`
8. Issue SSL cert: `vercel certs issue agnonymous.buperac.com`

### "Someone deleted the `agnonymous-news-redirect` Vercel project"

1. Recreate the two files at `C:/Users/kyle/Agriculture/agnonymous_news_redirect/`
   (see "The agnonymous.news redirect" section above)
2. `cd` into that directory, `vercel deploy --prod --yes`
3. The CLI will prompt to link/create a project. Accept defaults but rename to
   `agnonymous-news-redirect` when asked (or rename later via `vercel project rm`/recreate)
4. Disable SSO protection
5. Attach both domains via the Vercel API:
   ```bash
   TOKEN=$(cat ~/AppData/Roaming/com.vercel.cli/Data/auth.json | grep -o '"token"[^"]*"[^"]*"' | sed 's/.*"\([^"]*\)"$/\1/')
   PID=<new-project-id>
   TEAM=team_G5ANWxcnatlUPZiwb90vf4px
   curl -X POST "https://api.vercel.com/v10/projects/$PID/domains?teamId=$TEAM" \
     -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
     -d '{"name":"agnonymous.news"}'
   curl -X POST "https://api.vercel.com/v10/projects/$PID/domains?teamId=$TEAM" \
     -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
     -d '{"name":"www.agnonymous.news"}'
   ```
6. Issue certs: `vercel certs issue agnonymous.news www.agnonymous.news`
7. Update this doc with the new `projectId`

### "Firebase Hosting is serving traffic again"

We disabled it with a `SITE_DISABLE` release via the REST API. To reconfirm it's off:

```bash
TOKEN=$(gcloud auth print-access-token)
curl "https://firebasehosting.googleapis.com/v1beta1/sites/agnonymousbeta/releases?pageSize=1" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: agnonymousbeta"
```

The `type` on the most recent release should be `SITE_DISABLE`. If it's `DEPLOY`, something
re-enabled it. To disable again:

```bash
TOKEN=$(gcloud auth print-access-token)
curl -X POST "https://firebasehosting.googleapis.com/v1beta1/sites/agnonymousbeta/releases" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: agnonymousbeta" \
  -H "Content-Type: application/json" \
  -d '{"type":"SITE_DISABLE"}'
```

(Equivalent to `firebase hosting:disable` in the CLI, but works without reauthenticating.)

---

## Why two deploy approaches coexist in this repo

There's also a root-level `vercel.json` + `build.sh` that set up a **remote** build (Vercel
clones Flutter on their build servers every deploy). That path is:

- Slow: ~3-5 minute cold builds (Flutter SDK clone + pub get + build)
- Fragile: Vercel's build env changes silently and can break
- Not what we actually use for production

The `scripts/deploy-web.sh` path does a **local** build and uploads the prebuilt output.
Much faster (~70s), deterministic, matches your local dev environment.

If the local path ever breaks, the remote path is a fallback: `vercel deploy --prod` from
the repo root (not from `build/web/`) triggers it.

---

## Non-urgent housekeeping

- Delete the `hosting-site=agnonymousbeta` TXT record in Squarespace (Firebase verification,
  unused since hosting is disabled)
- Let `agnonymous.news` lapse at renewal (~Jun 5, 2026) — or keep it as a permanent redirect
- Consider deleting the `agnonymousbeta` Firebase project entirely once you're confident you
  won't need to re-enable anything from it
- `firebase-debug.log` files occasionally land in `agnonymous_news_redirect/` — safe to delete
