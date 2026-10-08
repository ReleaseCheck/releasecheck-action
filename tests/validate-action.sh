#!/usr/bin/env bash
set -euo pipefail

test -f action.yml
test -f LICENSE
test -f scripts/run-releasecheck.sh
grep -q 'using: composite' action.yml
grep -q 'releasecheck-version' action.yml
grep -q 'sha256sum' scripts/run-releasecheck.sh
grep -q 'tar -xzf' scripts/run-releasecheck.sh
grep -q 'verify' scripts/run-releasecheck.sh
if grep -Eq 'npm install|pip install|curl.*\|.*sh|eval ' scripts/run-releasecheck.sh; then
  echo 'unsafe installation or shell execution found' >&2
  exit 1
fi
echo 'action-structure=PASS'
