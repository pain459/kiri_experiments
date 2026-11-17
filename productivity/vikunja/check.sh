#!/usr/bin/env bash
# Checks that vikunja's API responds and its SQLite database was created.
# The container is distroless, so everything here runs from the host.
set -euo pipefail

base="${BASE_URL:-http://127.0.0.1:3456}"

fail() { echo "FAIL: $*" >&2; exit 1; }

info="$(curl -fsS "$base/api/v1/info")" || fail "api/v1/info unreachable"
printf '%s' "$info" | grep -q '"version"' || fail "unexpected info payload"

[ -s ./data/files/vikunja.db ] || fail "database file missing"

echo "vikunja: all checks passed"
