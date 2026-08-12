#!/usr/bin/env bash
# JJ Workspace Attach Script
# Usage: ./jj-workspace-attach.sh NAME [--agent KIND] [--no-herdr]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

usage() {
  echo "Usage: $0 NAME [--agent KIND] [--no-herdr]"
  echo "  NAME: lowercase alphanumeric slug with hyphens (e.g., feat-publisher, cpnthi-42)"
  echo "  --agent KIND: agent to start if the herdr workspace has to be built (default: claude)"
  echo "  --no-herdr:   print the cd line only, do not touch herdr"
  exit 1
}

NAME=""
AGENT="claude"
HERDR="yes"

while [ $# -gt 0 ]; do
  case "$1" in
    --agent) AGENT="${2:-}"; shift 2 ;;
    --no-herdr) HERDR="no"; shift ;;
    -h|--help) usage ;;
    -*) echo "unknown option: $1" >&2; usage ;;
    *) [ -n "$NAME" ] && usage; NAME="$1"; shift ;;
  esac
done

[ -n "$NAME" ] || usage

if ! echo "$NAME" | grep -qE '^[a-z0-9][a-z0-9-]*[a-z0-9]$'; then
  echo "ERROR: NAME must be a lowercase alphanumeric slug (hyphens allowed, no slashes)"
  echo "  Valid:   feat-publisher, fix-payments, cpnthi-42"
  echo "  Invalid: Feature/Publisher, feat_x, x"
  exit 1
fi

if ! WS_ABS="$(jj --ignore-working-copy workspace root --name "$NAME" 2>/dev/null)"; then
  echo "ERROR: no workspace named '$NAME'"
  echo "  Run jj-workspace-list.sh to see existing workspaces."
  exit 1
fi

# Inside herdr, attaching means switching to the workspace, not printing a path.
# Building it when it is missing is what makes attach work after a herdr restart.
if [ "$HERDR" = "yes" ] && [ -n "${HERDR_ENV:-}" ]; then
  "$SCRIPT_DIR/herdr-workspace-open.sh" "$NAME" --agent "$AGENT" --focus
  exit 0
fi

echo "Attach to workspace '$NAME':"
echo "  cd $WS_ABS"
echo ""
echo "Then: jj st    (status) / jj log    (history)"
