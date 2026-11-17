#!/usr/bin/env bash
# Verifies the smoke stack: proxy health, service discovery, and app page.
set -euo pipefail

base="${BASE_URL:-http://127.0.0.1:8080}"

fail() { echo "FAIL: $*" >&2; exit 1; }

[ "$(curl -fsS "$base/healthz")" = "proxy ok" ] || fail "proxy health"
echo "proxy health: ok"

[ "$(curl -fsS "$base/upstream")" = "smoke-app" ] || fail "service discovery"
echo "service discovery: ok"

curl -fsS "$base/" | grep -q "kiri smoke test" || fail "app page"
echo "app page: ok"

echo "smoke: all checks passed"
