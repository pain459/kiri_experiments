#!/usr/bin/env bash
# Checks that the Stirling PDF UI and its internal status API respond.
set -euo pipefail

base="${BASE_URL:-http://127.0.0.1:8081}"

fail() { echo "FAIL: $*" >&2; exit 1; }

curl -fsS "$base/api/v1/info/status" >/dev/null || fail "status api"
curl -fsS "$base/" | grep -qi "stirling" || fail "web ui"

echo "stirling-pdf: all checks passed"
