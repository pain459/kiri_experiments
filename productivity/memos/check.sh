#!/usr/bin/env bash
# Checks that memos is serving and its SQLite store is writable.
set -euo pipefail

DOCKER="${DOCKER:-kiri}"
base="${BASE_URL:-http://127.0.0.1:5230}"

fail() { echo "FAIL: $*" >&2; exit 1; }

curl -fsS "$base/healthz" >/dev/null || fail "healthz"
curl -fsS "$base/" | grep -qi "memos" || fail "web ui"

[ "$("$DOCKER" compose exec -T memos sh -c 'test -w /var/opt/memos && echo writable' 2>/dev/null)" = "writable" ] \
  || fail "data volume not writable"

echo "memos: all checks passed"
