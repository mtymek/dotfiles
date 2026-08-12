#!/usr/bin/env bash
# JJ Workspace Create Script
# Usage: ./jj-workspace-create.sh NAME [REVISION] [--agent KIND] [--no-setup]
#                                 [--no-herdr] [--focus]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=lib-layout.sh
. "$SCRIPT_DIR/lib-layout.sh"

usage() {
  echo "Usage: $0 NAME [REVISION] [--agent KIND] [--no-setup] [--no-herdr] [--focus]"
  echo "  NAME: lowercase alphanumeric slug with hyphens (e.g., feat-publisher, cpnthi-42)"
  echo "  REVISION: jj revset to base the workspace on."
  echo "            Defaults to the parent of the current working copy (safe: ignores in-progress changes)."
  echo "            Common choices: @, @-, trunk(), origin/main"
  echo "  --agent KIND: agent to start in the layout's agent pane (default: claude)."
  echo "                Any kind herdr supports, e.g. claude, opencode, codex."
  echo "  --no-setup:   skip the layout's setup command."
  echo "  --no-herdr:   create the jj workspace only, no herdr workspace."
  echo "  --focus:      switch to the new herdr workspace when it is ready."
  exit 1
}

NAME=""
REVISION=""
AGENT="claude"
HERDR="yes"
SETUP="yes"
FOCUS=""

while [ $# -gt 0 ]; do
  case "$1" in
    --agent) AGENT="${2:-}"; shift 2 ;;
    --no-setup) SETUP="no"; shift ;;
    --no-herdr) HERDR="no"; shift ;;
    --focus) FOCUS="--focus"; shift ;;
    -h|--help) usage ;;
    -*) echo "unknown option: $1" >&2; usage ;;
    *)
      if [ -z "$NAME" ]; then NAME="$1"
      elif [ -z "$REVISION" ]; then REVISION="$1"
      else usage
      fi
      shift ;;
  esac
done

if [ -z "$NAME" ]; then
  usage
fi

if ! echo "$NAME" | grep -qE '^[a-z0-9][a-z0-9-]*[a-z0-9]$'; then
  echo "ERROR: NAME must be a lowercase alphanumeric slug (hyphens allowed, no slashes)"
  echo "  Valid:   feat-publisher, fix-payments, cpnthi-42"
  echo "  Invalid: Feature/Publisher, feat_x, x"
  exit 1
fi

if [ -n "$REVISION" ] && ! jj --ignore-working-copy log -r "$REVISION" --no-graph >/dev/null 2>&1; then
  echo "ERROR: unknown revision: $REVISION"
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

WS=".jj-workspaces/$NAME"
if [ -e "$WS" ]; then
  echo "ERROR: workspace already exists at $WS"
  echo "  Use a different NAME, or destroy the existing one first."
  exit 1
fi

mkdir -p .jj-workspaces

echo "Creating jj workspace '$NAME' at $WS on revision ${REVISION:-"(parent of @)"}..."
if [ -n "$REVISION" ]; then
  jj workspace add --name "$NAME" "$WS" --revision "$REVISION"
else
  jj workspace add --name "$NAME" "$WS"
fi

HANDOFF_DIR=".jj-workspaces/handoffs"
if [ -d "$HANDOFF_DIR" ] && ls "$HANDOFF_DIR"/*.md >/dev/null 2>&1; then
  echo ""
  echo "Available context handoffs:"
  for f in "$HANDOFF_DIR"/*.md; do
    fname=$(basename "$f" .md)
    desc=$(grep '^## What was done' -A 1 "$f" 2>/dev/null | tail -1 | sed 's/^- //')
    printf "  %-20s %s\n" "$fname" "${desc:-(no summary)}"
    if grep -q "$NAME" "$f" 2>/dev/null; then
      echo "    ^ possible match (mentioned in handoff)"
    fi
  done
  echo ""
  echo "To load a handoff: cp .jj-workspaces/handoffs/<name>.md $WS/CONTEXT.md"
fi

# Bootstrap runs HERE, not in a herdr pane. Two reasons, both measured: wrangler
# prompts "continue? (Y/n)" on a TTY and a pane is a TTY, and there is no honest
# way to wait for a pane command to finish. `pane wait-output` searches existing
# output first, so a sentinel echoed by the shell as it types the command line
# matches instantly and the wait returns before the work has started.
if [ "$SETUP" = "yes" ]; then
  LAYOUT_FILE="$(resolve_layout "" || true)"
  if [ -n "$LAYOUT_FILE" ] && [ -f "$LAYOUT_FILE" ] && command -v jq >/dev/null 2>&1; then
    SETUP_CMD="$(jq -r '.setup // ""' "$LAYOUT_FILE")"
    if [ -n "$SETUP_CMD" ]; then
      echo ""
      echo "Running setup in $WS: $SETUP_CMD"
      if ! ( cd "$WS" && eval "$SETUP_CMD" ); then
        echo "ERROR: setup failed in $WS" >&2
        echo "  The jj workspace exists. Fix the problem, re-run setup by hand," >&2
        echo "  then: herdr-workspace-open.sh $NAME --agent $AGENT" >&2
        exit 1
      fi
    fi
  fi
fi

echo ""
echo "Workspace ready: $WS"
echo "  cd $WS"
echo "  destroy: jj-workspace-destroy.sh $NAME"

# The herdr side is additive. It skips itself outside herdr, and a failure there
# must not make a perfectly good jj workspace look broken.
if [ "$HERDR" = "yes" ]; then
  echo ""
  if ! "$SCRIPT_DIR/herdr-workspace-open.sh" "$NAME" --agent "$AGENT" ${FOCUS:+"$FOCUS"}; then
    echo "WARNING: the herdr workspace was not created. The jj workspace at $WS is fine." >&2
    echo "  Retry with: herdr-workspace-open.sh $NAME --agent $AGENT" >&2
  fi
fi
