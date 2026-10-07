#!/usr/bin/env bash
# Checks that this public repo does not serve private gbrain data or the
# tenant registry. Uses the HTTP status: GitHub Pages returns 404 for removed
# paths and 200 for anything still served. Exits non-zero on any exposure.
# Usage: scripts/check-private-data-exposure.sh [host]
set -uo pipefail

HOST="${1:-https://mc-hermes.github.io/hermes-agent-cost}"

PRIVATE_PATHS=(
  "/gbrain-data.json"
  "/certava/gbrain-data.json"
  "/zaim/gbrain-data.json"
  "/hermes-demo-1/gbrain-data.json"
  "/gbrain-dashboard.html"
  "/zaim-gbrain-proposal.html"
  "/logs/achievements-2026-06.md"
)

fail=0
for p in "${PRIVATE_PATHS[@]}"; do
  code=$(curl -sL -o /dev/null -w "%{http_code}" "${HOST}${p}")
  if [ "$code" = "200" ]; then
    echo "EXPOSED  ${code}  ${HOST}${p}"
    fail=1
  else
    echo "ok       ${code}  ${HOST}${p}"
  fi
done

if [ "$fail" -eq 1 ]; then
  echo
  echo "FAIL: private data is publicly readable."
  exit 1
fi
echo
echo "PASS: no private data is publicly readable."