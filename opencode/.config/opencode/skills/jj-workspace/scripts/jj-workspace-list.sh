#!/usr/bin/env bash
# JJ Workspace List Script
# Usage: ./jj-workspace-list.sh

set -euo pipefail

if ! jj --ignore-working-copy st >/dev/null 2>&1; then
  echo "ERROR: not inside a jj repository"
  echo "  Run from the project root where .jj/ lives."
  exit 1
fi

CURRENT="$(pwd -P)"

echo "JJ Workspaces:"
jj --ignore-working-copy workspace list -T 'name ++ "  " ++ root ++ "\n"' | while read -r name root; do
  marker=" "
  if [ "$CURRENT" = "$root" ]; then
    marker="*"
  fi
  printf "%s %-12s %s\n" "$marker" "$name" "$root"
done
echo ""
echo "Legend: * = current workspace (cwd)"
