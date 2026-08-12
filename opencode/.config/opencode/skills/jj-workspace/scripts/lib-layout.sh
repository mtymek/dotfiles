#!/usr/bin/env bash
# Shared layout-file resolution. Sourced by jj-workspace-create.sh and
# herdr-workspace-open.sh so the two never disagree about which file is in play.

# resolve_layout [explicit-path] -> prints the layout file path, or nothing.
# Order: the explicit path, then <repo>/.jj-workspaces/layout.json, then the
# skill's own default.
resolve_layout() {
  local explicit="${1:-}" skill_dir repo_root candidate
  skill_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

  if [ -n "$explicit" ]; then
    printf '%s' "$explicit"
    return 0
  fi

  if repo_root="$(jj --ignore-working-copy workspace root --name default 2>/dev/null)"; then
    candidate="$repo_root/.jj-workspaces/layout.json"
    if [ -f "$candidate" ]; then
      printf '%s' "$candidate"
      return 0
    fi
  fi

  candidate="$skill_dir/layouts/default.json"
  if [ -f "$candidate" ]; then
    printf '%s' "$candidate"
    return 0
  fi

  return 1
}
