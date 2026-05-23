#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
. "$HERE/_assert.sh"

S="$ROOT/scripts/ci/parse-tag.sh"

run() { bash "$S" "$1" 2>/dev/null; }

assert_eq "prod simple"     "prod 7 0"  "$(run prod/v7.0)"
assert_eq "dev two-digit"   "dev 12 345" "$(run dev/v12.345)"
assert_eq "prod minor zero" "prod 8 0"  "$(run prod/v8.0)"

run_rc() { bash "$S" "$1" >/dev/null 2>&1; echo $?; }
assert_exit "missing env"       1 "$(run_rc v7.1)"
assert_exit "bad env"           1 "$(run_rc stg/v7.1)"
assert_exit "missing minor"     1 "$(run_rc prod/v7)"
assert_exit "non-numeric major" 1 "$(run_rc prod/vX.1)"
assert_exit "leading zero ok"   0 "$(run_rc prod/v07.1)"
assert_exit "trailing junk"     1 "$(run_rc prod/v7.1-rc1)"
assert_exit "no arg"            1 "$(run_rc '')"

summary
