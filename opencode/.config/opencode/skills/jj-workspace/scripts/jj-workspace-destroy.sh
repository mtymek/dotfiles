#!/usr/bin/env bash
# JJ Workspace Destroy Script
# Usage: ./jj-workspace-destroy.sh NAME [--force]

set -euo pipefail

usage() {
  echo "Usage: $0 NAME [--force]"
  echo "  NAME: lowercase alphanumeric slug with hyphens (e.g., feat-publisher, cpnthi-42)"
  echo "  --force: skip the context-handoff check and destroy anyway"
  exit 1
}

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  usage
fi

NAME="$1"
FORCE="${2:-}"

if [ "$FORCE" != "--force" ] && [ "$FORCE" != "" ]; then
  usage
fi

if ! echo "$NAME" | grep -qE '^[a-z0-9][a-z0-9-]*[a-z0-9]$'; then
  echo "ERROR: NAME must be a lowercase alphanumeric slug (hyphens allowed, no slashes)"
  echo "  Valid:   feat-publisher, fix-payments, cpnthi-42"
  echo "  Invalid: Feature/Publisher, feat_x, x"
  exit 1
fi

if ! jj --ignore-working-copy st >/dev/null 2>&1; then
  echo "ERROR: not inside a jj repository"
  echo "  Run from the project root where .jj/ lives."
  exit 1
fi

ROOT="$(jj --ignore-working-copy workspace root --name default)"
if [ "$(pwd -P)" != "$ROOT" ]; then
  echo "ERROR: run this from the project root (primary workspace):"
  echo "  cd $ROOT"
  exit 1
fi

# Resolve the directory from jj rather than assuming .jj-workspaces/$NAME.
# `jj workspace rename` changes the name and leaves the directory alone, so the
# two are not always the same string.
if ! WS="$(jj --ignore-working-copy workspace root --name "$NAME" 2>/dev/null)"; then
  echo "ERROR: no jj workspace named '$NAME'"
  echo "  Run jj-workspace-list.sh to see existing workspaces."
  exit 1
fi
if [ ! -d "$WS" ]; then
  echo "ERROR: workspace directory not found at $WS"
  echo "  It may already be removed; run jj-workspace-list.sh to check."
  exit 1
fi

HANDOFF=".jj-workspaces/handoffs/$NAME.md"
if [ "$FORCE" != "--force" ] && [ ! -f "$HANDOFF" ]; then
  echo "No context handoff found for '$NAME'."
  echo "  Save one first:  jj-workspace-save-context.sh $NAME"
  echo "  Then re-run destroy. Or pass --force to skip."
  exit 1
fi

# Close the herdr workspace first. Removing the directory under a live pane
# leaves panes sitting in a deleted cwd, and `task serve` holding files open is
# exactly what `db:reset` and `archive:clear` refuse to work around.
if [ -n "${HERDR_ENV:-}" ] && command -v herdr >/dev/null 2>&1; then
  REPO="$(basename "$ROOT")"
  LABEL="$REPO:$NAME"
  # Also match the pre-rename "<repo> - <name>" label, so destroy still closes
  # a workspace that was opened before the naming changed.
  LEGACY_LABEL="$REPO - $NAME"
  HERDR_WS="$(herdr workspace list 2>/dev/null \
    | jq -r --arg l "$LABEL" --arg o "$LEGACY_LABEL" \
      '.result.workspaces[] | select(.label == $l or .label == $o) | .workspace_id' \
    | head -1)"
  if [ -n "$HERDR_WS" ]; then
    if [ "$HERDR_WS" = "${HERDR_WORKSPACE_ID:-}" ]; then
      echo "ERROR: '$LABEL' is the herdr workspace you are running in."
      echo "  Switch to another workspace first, then re-run destroy."
      exit 1
    fi
    echo "Closing herdr workspace '$LABEL' ($HERDR_WS)..."
    herdr workspace close "$HERDR_WS" >/dev/null || \
      echo "WARNING: could not close $HERDR_WS; close it by hand" >&2
  fi
fi

echo "Forgetting jj workspace '$NAME'..."
jj workspace forget "$NAME"

echo "Removing $WS ..."
rm -rf "$WS"

echo "Workspace '$NAME' destroyed."
