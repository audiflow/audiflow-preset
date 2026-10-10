#!/usr/bin/env bash
# Setup GitHub repository rulesets for branch protection.
# Requires: gh CLI authenticated with admin access.
#
# Usage: ./scripts/setup-github-rulesets.sh
#
# Bypass actors:
#   - RepositoryRole ID 5 (admin) — repo owner can bypass
#   - audiflow-ci-bot (Integration) — CI can push version bumps
# Validate check is NOT required in the ruleset — the workflow's
# path filter ensures it runs only when patterns/**.json changes.

set -euo pipefail

REPO="audiflow/audiflow-preset"

echo "=== Creating ruleset: base-branches ==="
gh api "repos/${REPO}/rulesets" \
  --method POST \
  --input - <<'EOF'
{
  "name": "base-branches",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["refs/heads/main", "refs/heads/prod/*", "refs/heads/stg/*", "refs/heads/dev/*"],
      "exclude": []
    }
  },
  "bypass_actors": [
    {
      "actor_id": 5,
      "actor_type": "RepositoryRole",
      "bypass_mode": "always"
    },
    {
      "actor_id": 3096359,
      "actor_type": "Integration",
      "bypass_mode": "always"
    }
  ],
  "rules": [
    {
      "type": "creation"
    },
    {
      "type": "deletion"
    },
    {
      "type": "non_fast_forward"
    },
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 1,
        "dismiss_stale_reviews_on_push": true,
        "require_code_owner_review": true,
        "require_last_push_approval": false,
        "required_review_thread_resolution": true
      }
    }
  ]
}
EOF

echo ""
echo "=== Done ==="
echo ""
echo "Manual step required:"
echo "  Go to Settings > Pages and change source to:"
echo "    Deploy from a branch: gh-pages / (root)"
