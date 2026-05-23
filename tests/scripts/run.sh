#!/usr/bin/env bash
# Runs every *_test.sh under tests/scripts/. Each test file sources _assert.sh
# and calls summary at end.
set -eu
cd "$(CDPATH= cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

shopt -s nullglob
files=( *_test.sh )
if [ ${#files[@]} -eq 0 ]; then
  echo "no tests found"
  exit 0
fi

rc=0
for t in "${files[@]}"; do
  echo "== $t =="
  bash "$t" || rc=$?
done
exit "$rc"
