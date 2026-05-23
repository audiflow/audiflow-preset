#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
. "$HERE/_assert.sh"

S="$ROOT/scripts/ci/pick-winning-tags.sh"

run() { printf '%s\n' "$@" | bash "$S" 2>/dev/null | sort; }

# Per (env, major) keep highest minor.
input1=(prod/v7.0 prod/v7.10 prod/v7.2 dev/v7.5 dev/v7.6 prod/v8.0)
expected1="dev 7 6 dev/v7.6
prod 7 10 prod/v7.10
prod 8 0 prod/v8.0"
assert_eq "max-minor across envs+majors" "$expected1" "$(run "${input1[@]}")"

# Numeric sort (not lexicographic): v7.10 > v7.2
input2=(prod/v7.2 prod/v7.10)
assert_eq "numeric sort 10>2" "prod 7 10 prod/v7.10" "$(run "${input2[@]}")"

# Invalid tags are silently dropped.
input3=(prod/v7.1 stg/v7.1 garbage prod/v7.2)
assert_eq "ignore invalid" "prod 7 2 prod/v7.2" "$(run "${input3[@]}")"

# Empty stdin -> empty stdout, exit 0.
assert_eq "empty input" "" "$(printf '' | bash "$S" 2>/dev/null)"

summary
