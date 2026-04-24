#!/usr/bin/env bash
# Deploy the Flutter web app to Vercel (production).
#
# Usage:  bash scripts/deploy-web.sh
# Run from the repo root.
#
# What it does:
#   1. Loads SUPABASE_URL + SUPABASE_ANON_KEY from .env
#   2. Runs `flutter build web --release` with those as --dart-define
#   3. Copies deploy/vercel.prod.json → build/web/vercel.json (CSP + SPA rewrites)
#   4. Recreates build/web/.vercel/project.json if missing (so the upload
#      goes to the correct Vercel project)
#   5. Runs `vercel deploy --prod --yes` from build/web/
#   6. Prints the deploy URL and smoke-tests https://agnonymous.buperac.com/
#
# See DEPLOYMENT.md for background, disaster recovery, and manual-deploy steps.

set -euo pipefail

# ---- config (update DEPLOYMENT.md in lockstep if these change) --------------
readonly VERCEL_PROJECT_ID="prj_w6WXCPQ4TL0vj8ITJyFgThq3MYXT"
readonly VERCEL_ORG_ID="team_G5ANWxcnatlUPZiwb90vf4px"
readonly VERCEL_PROJECT_NAME="agnonymous"
readonly CANONICAL_URL="https://agnonymous.buperac.com/"

# ---- locate the repo root (script is portable regardless of cwd) ------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

# ---- pretty-print helpers ---------------------------------------------------
bold() { printf '\033[1m%s\033[0m\n' "$*"; }
warn() { printf '\033[33m!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[31m✗\033[0m %s\n' "$*" >&2; exit 1; }
ok()   { printf '\033[32m✓\033[0m %s\n' "$*"; }

# ---- preflight --------------------------------------------------------------
bold "▶ Preflight"

command -v flutter >/dev/null 2>&1 || die "flutter not on PATH. Install: https://docs.flutter.dev/get-started/install"
command -v vercel  >/dev/null 2>&1 || die "vercel CLI not on PATH. Install: npm i -g vercel"
command -v curl    >/dev/null 2>&1 || die "curl not on PATH"

[[ -f .env ]] || die ".env not found at repo root. Copy .env.example → .env and fill in Supabase creds."

# shellcheck disable=SC1091
set -a; source .env; set +a
: "${SUPABASE_URL:?SUPABASE_URL missing from .env}"
: "${SUPABASE_ANON_KEY:?SUPABASE_ANON_KEY missing from .env}"
ok ".env loaded (SUPABASE_URL=$SUPABASE_URL)"

[[ -f deploy/vercel.prod.json ]] || die "deploy/vercel.prod.json missing. This is the canonical production Vercel config."

# ---- build ------------------------------------------------------------------
bold "▶ flutter build web --release"
flutter build web --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
ok "build/web/ is ready"

# ---- stage Vercel config ----------------------------------------------------
bold "▶ Stage deploy/vercel.prod.json → build/web/vercel.json"
cp deploy/vercel.prod.json build/web/vercel.json
ok "CSP + SPA rewrites staged"

# ---- ensure .vercel link exists --------------------------------------------
bold "▶ Verify build/web/.vercel/project.json"
LINK_FILE="build/web/.vercel/project.json"
if [[ ! -f "$LINK_FILE" ]]; then
  warn "Vercel link missing — recreating from known project ID"
  mkdir -p build/web/.vercel
  cat > "$LINK_FILE" <<EOF
{
  "projectId": "$VERCEL_PROJECT_ID",
  "orgId": "$VERCEL_ORG_ID",
  "projectName": "$VERCEL_PROJECT_NAME"
}
EOF
  ok "Recreated $LINK_FILE"
else
  ok "Vercel link present"
fi

# ---- deploy -----------------------------------------------------------------
bold "▶ vercel deploy --prod --yes (from build/web/)"
pushd build/web >/dev/null

# Capture output so we can extract the Production URL for the summary.
DEPLOY_LOG="$(mktemp -t agnonymous-deploy.XXXXXX.log)"
trap 'rm -f "$DEPLOY_LOG"' EXIT

if ! vercel deploy --prod --yes 2>&1 | tee "$DEPLOY_LOG"; then
  popd >/dev/null
  die "vercel deploy failed — see output above"
fi

# The CLI prints the deploy URL as the last "https://...vercel.app" line.
DEPLOY_URL="$(grep -Eo 'https://[a-zA-Z0-9._/-]+\.vercel\.app' "$DEPLOY_LOG" | tail -n 1 || true)"
popd >/dev/null

if [[ -n "$DEPLOY_URL" ]]; then
  ok "Deploy URL: $DEPLOY_URL"
else
  warn "Could not parse deploy URL from CLI output (deploy may still have succeeded)"
fi

# ---- smoke test -------------------------------------------------------------
bold "▶ Smoke test $CANONICAL_URL"
# Give Vercel a beat to propagate the alias to the edge network.
sleep 3

HTTP_CODE="$(curl -sS -o /dev/null -w '%{http_code}' -L --max-time 15 "$CANONICAL_URL" || echo "000")"
case "$HTTP_CODE" in
  200) ok "$CANONICAL_URL → 200 OK" ;;
  000) warn "Smoke test network error — check connectivity and retry manually" ;;
  *)   warn "$CANONICAL_URL returned HTTP $HTTP_CODE (expected 200)" ;;
esac

bold "✅ Done."
[[ -n "$DEPLOY_URL" ]] && echo "   Deploy:    $DEPLOY_URL"
echo "   Canonical: $CANONICAL_URL"
