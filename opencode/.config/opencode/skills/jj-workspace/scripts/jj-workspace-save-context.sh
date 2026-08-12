#!/usr/bin/env bash
# JJ Workspace Save Context Script
# Usage: ./jj-workspace-save-context.sh NAME [--overwrite]

set -euo pipefail

usage() {
  echo "Usage: $0 NAME [--overwrite]"
  echo "  NAME: lowercase alphanumeric slug with hyphens (e.g., feat-publisher, cpnthi-42)"
  echo "  --overwrite: replace an existing handoff file"
  exit 1
}

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  usage
fi

NAME="$1"
OVERWRITE="${2:-}"

if [ "$OVERWRITE" != "--overwrite" ] && [ "$OVERWRITE" != "" ]; then
  usage
fi

if ! echo "$NAME" | grep -qE '^[a-z0-9][a-z0-9-]*[a-z0-9]$'; then
  echo "ERROR: NAME must be a lowercase alphanumeric slug (hyphens allowed, no slashes)"
  echo "  Valid:   feat-publisher, fix-payments, cpnthi-42"
  echo "  Invalid: Feature/Publisher, feat_x, x"
  exit 1
fi

if ! jj --ignore-working-copy workspace list -T 'name ++ "\n"' | grep -qx "$NAME"; then
  echo "ERROR: no workspace named '$NAME'"
  echo "  Run jj-workspace-list.sh to see existing workspaces."
  exit 1
fi

HANDOFF_DIR=".jj-workspaces/handoffs"
HANDOFF_FILE="$HANDOFF_DIR/$NAME.md"
mkdir -p "$HANDOFF_DIR"

if [ -f "$HANDOFF_FILE" ] && [ "$OVERWRITE" != "--overwrite" ]; then
  echo "ERROR: handoff already exists: $HANDOFF_FILE"
  echo "  Pass --overwrite to replace it."
  exit 1
fi

WS_CHANGE=$(jj --ignore-working-copy workspace list -T 'name ++ " " ++ target.change_id() ++ "\n"' | grep "^$NAME " | awk '{print $2}')
REVISION=$(jj --ignore-working-copy workspace list -T 'name ++ " " ++ target.change_id().short() ++ " " ++ target.description() ++ "\n"' | grep "^$NAME " | sed 's/^[^ ]* //' || echo "(unknown)")
COMMITS=$(jj --ignore-working-copy log -r "trunk()..$WS_CHANGE" --no-graph -T 'change_id.short() ++ " " ++ description ++ "\n"' 2>/dev/null || echo "(no commits ahead of trunk)")
CHANGED_FILES=$(jj --ignore-working-copy diff --from 'trunk()' --to "$WS_CHANGE" --stat 2>/dev/null | head -20 || echo "(none)")

cat > "$HANDOFF_FILE" <<EOF
# $NAME context handoff
revision: $REVISION
related: []
created: $(date +%Y-%m-%d)

## Commits
$COMMITS

## Changed files
$CHANGED_FILES

## What was done
- (fill in: what was implemented or changed)

## Key decisions
- (fill in: important choices made and why)

## Remaining work
- [ ] (fill in: what is left to do)

## Notes
(anything useful for someone continuing this work)
EOF

echo ""
echo "Handoff template saved: $HANDOFF_FILE"
echo "Fill it in with the session context: what was done, key decisions, remaining work."
echo ""
echo "  Tip: ask the agent to fill it in — it has the session context."
