#!/usr/bin/env bash
#
# Build and deploy the website.
#
# THIS SCRIPT EXISTS BECAUSE THE BARE COMMAND IS A TRAP.
#
# `flutter build web --release` succeeds, produces a perfect-looking bundle, and
# points every visitor's browser at http://localhost:8787 — because API_BASE_URL
# comes from --dart-define and silently falls back to the development default
# when the flag is missing.
#
# The site then loads, renders every page, and cannot sign anybody in, register
# anybody, or fetch a single record. Every failure reports itself as "we could
# not reach the archive", which sends people to check an internet connection
# that was never the problem. It happened, in production, to real people.
#
# So: build through this script, never by hand.
set -euo pipefail

API_BASE_URL="${API_BASE_URL:-https://ekoli-yeden-api.ndovera.workers.dev}"
SITE_URL="${SITE_URL:-https://ekoli.pages.dev}"
PROJECT="${PAGES_PROJECT:-ekoli}"

echo "→ Building against ${API_BASE_URL}"
flutter build web --release \
  --dart-define=API_BASE_URL="${API_BASE_URL}" \
  --dart-define=ENVIRONMENT=production \
  --dart-define=SITE_URL="${SITE_URL}"

# Prove the flag actually took. A bundle that still mentions the development
# default is the exact failure this script exists to prevent, and shipping it
# is worse than not shipping at all.
if grep -q "localhost:8787" build/web/main.dart.js; then
  echo "✗ REFUSING TO DEPLOY: the bundle still points at localhost:8787." >&2
  echo "  The --dart-define did not take effect. Do not deploy this." >&2
  exit 1
fi

if ! grep -q "${API_BASE_URL#https://}" build/web/main.dart.js; then
  echo "✗ REFUSING TO DEPLOY: the bundle does not mention ${API_BASE_URL}." >&2
  exit 1
fi

echo "✓ Bundle verified: points at ${API_BASE_URL}"
npx wrangler pages deploy build/web --project-name "${PROJECT}" --branch main
