#!/usr/bin/env bash
# Open a jj workspace as a herdr workspace, arranged by a declarative layout.
# Usage: ./herdr-workspace-open.sh NAME [--agent KIND] [--layout FILE]
#                                       [--focus] [--quiet]
#
# Bootstrap (npm ci and friends) is NOT run here. It belongs to
# jj-workspace-create.sh, which runs it outside herdr where there is no TTY to
# prompt at and a real exit code to wait on.
#
# Idempotent: if a herdr workspace already carries the label, it is focused
# rather than rebuilt. Exits 0 without doing anything when herdr is not running,
# so callers can invoke it unconditionally.

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=lib-layout.sh
. "$SKILL_DIR/scripts/lib-layout.sh"

usage() {
  echo "Usage: $0 NAME [--agent KIND] [--layout FILE] [--focus] [--quiet]"
  echo "  NAME:     jj workspace name (must already exist)"
  echo "  --agent:  agent kind for panes declared as \${AGENT} (default: claude)"
  echo "  --layout: layout JSON. Default: <repo>/.jj-workspaces/layout.json,"
  echo "            falling back to $SKILL_DIR/layouts/default.json"
  echo "  --focus:  focus the workspace when done (default: leave focus alone)"
  exit 1
}

NAME=""
AGENT="claude"
LAYOUT=""
FOCUS="no"
QUIET="no"

while [ $# -gt 0 ]; do
  case "$1" in
    --agent) AGENT="${2:-}"; shift 2 ;;
    --layout) LAYOUT="${2:-}"; shift 2 ;;
    --focus) FOCUS="yes"; shift ;;
    --quiet) QUIET="yes"; shift ;;
    -h|--help) usage ;;
    -*) echo "unknown option: $1" >&2; usage ;;
    *) [ -n "$NAME" ] && usage; NAME="$1"; shift ;;
  esac
done

[ -n "$NAME" ] || usage

say() { [ "$QUIET" = "yes" ] || echo "$@"; }

# herdr absent or not running is not an error. The jj workspace is still usable.
if [ -z "${HERDR_ENV:-}" ] || ! command -v herdr >/dev/null 2>&1; then
  say "herdr not detected (HERDR_ENV unset); skipping the herdr workspace."
  exit 0
fi

SOCKET="${HERDR_SOCKET_PATH:-$HOME/.config/herdr/herdr.sock}"
if [ ! -S "$SOCKET" ]; then
  say "herdr socket not found at $SOCKET; skipping the herdr workspace."
  exit 0
fi

for tool in jq socat; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "ERROR: $tool is required (layout.apply has no CLI subcommand)" >&2
    exit 1
  fi
done

# layout.export / layout.apply exist only on the socket API, so speak it directly.
# Newline-delimited JSON, one request per connection, no handshake.
api() {
  local response
  response="$(printf '%s\n' "$1" | timeout 15 socat -t10 - "UNIX-CONNECT:$SOCKET")"
  if [ -z "$response" ]; then
    echo "ERROR: no response from herdr socket" >&2
    return 1
  fi
  if printf '%s' "$response" | jq -e '.error' >/dev/null 2>&1; then
    echo "ERROR: herdr $(printf '%s' "$response" | jq -c '.error')" >&2
    return 1
  fi
  printf '%s' "$response"
}

if ! WS_PATH="$(jj --ignore-working-copy workspace root --name "$NAME" 2>/dev/null)"; then
  echo "ERROR: no jj workspace named '$NAME'" >&2
  exit 1
fi

REPO="$(basename "$(jj --ignore-working-copy workspace root --name default)")"
LABEL="$REPO:$NAME"
# Workspaces created before the rename carry "<repo> - <name>". Matched on the
# read side only, so an existing one is found and focused instead of being
# duplicated under the new label, which would kill nothing but confuse the list.
LEGACY_LABEL="$REPO - $NAME"

# Already open: focus it and stop. Rebuilding would kill whatever is running.
EXISTING="$(herdr workspace list | jq -r --arg l "$LABEL" --arg o "$LEGACY_LABEL" \
  '.result.workspaces[] | select(.label == $l or .label == $o) | .workspace_id' | head -1)"
if [ -n "$EXISTING" ]; then
  say "herdr workspace '$LABEL' already exists ($EXISTING)."
  [ "$FOCUS" = "yes" ] && herdr workspace focus "$EXISTING" >/dev/null
  echo "$EXISTING"
  exit 0
fi

LAYOUT="$(resolve_layout "$LAYOUT" || true)"
if [ -z "$LAYOUT" ] || [ ! -f "$LAYOUT" ]; then
  echo "ERROR: layout file not found: $LAYOUT" >&2
  exit 1
fi
if ! jq -e '.tabs | arrays and length > 0' "$LAYOUT" >/dev/null 2>&1; then
  echo "ERROR: $LAYOUT has no non-empty .tabs array" >&2
  exit 1
fi

say "Creating herdr workspace '$LABEL' from $(basename "$LAYOUT") ..."
CREATED="$(herdr workspace create --cwd "$WS_PATH" --label "$LABEL" --no-focus)"
WS_ID="$(printf '%s' "$CREATED" | jq -r '.result.workspace.workspace_id')"
ROOT_TAB="$(printf '%s' "$CREATED" | jq -r '.result.tab.tab_id')"

# herdr sets a pane's cwd but leaves the inherited PWD alone, so a pane that
# launches a command directly rather than a shell reports the terminal's
# original directory to anything reading $PWD instead of calling getcwd. A shell
# pane overwrites this on its own, so setting it is never wrong.
BASE_ENV="$(jq -c --arg ws "$WS_PATH" '{PWD: $ws} + (.env // {})' "$LAYOUT")"
TAB_COUNT="$(jq '.tabs | length' "$LAYOUT")"
for i in $(seq 0 $((TAB_COUNT - 1))); do
  TAB_LABEL="$(jq -r --argjson i "$i" '.tabs[$i].label // ("tab" + ($i|tostring))' "$LAYOUT")"
  RAW_ROOT="$(jq -c --argjson i "$i" '.tabs[$i].root' "$LAYOUT")"

  # Every pane runs in the new workspace. `agent` is ours, not herdr's: strip it
  # before sending, and start the agent afterwards with `herdr agent start`,
  # which waits for readiness and registers lifecycle state. A raw argv in
  # layout.apply would do neither.
  #
  # env is the layout's top-level env with the pane's own merged over it, and
  # ${WORKSPACE}, ${WORKSPACE_PARENT} and ${WORKSPACE_NAME} expanded. The
  # placeholders exist because the useful values are paths the layout file
  # cannot know.
  SEND_ROOT="$(printf '%s' "$RAW_ROOT" | jq -c \
    --arg ws "$WS_PATH" --arg parent "$(dirname "$WS_PATH")" --arg name "$NAME" \
    --argjson baseenv "$BASE_ENV" '
    def subst: gsub("\\$\\{WORKSPACE_PARENT\\}"; $parent)
             | gsub("\\$\\{WORKSPACE_NAME\\}"; $name)
             | gsub("\\$\\{WORKSPACE\\}"; $ws);
    def prep:
      if .type == "pane" then
        (.cwd = $ws
         | .env = (($baseenv + (.env // {})) | with_entries(.value |= subst))
         | if (.env | length) == 0 then del(.env) else . end
         | del(.agent))
      else (.first |= prep | .second |= prep) end;
    prep')"

  RESP="$(api "$(jq -nc --arg ws "$WS_ID" --arg label "$TAB_LABEL" --argjson root "$SEND_ROOT" \
    '{id:"jjws:apply", method:"layout.apply",
      params:{workspace_id:$ws, tab_label:$label, focus:false, root:$root}}')")"
  NEW_TAB="$(printf '%s' "$RESP" | jq -r '.result.layout.tab_id')"
  say "  tab $TAB_LABEL -> $NEW_TAB"

  # Same tree shape comes back, so a request path indexes the response.
  AGENTS="$(printf '%s' "$RAW_ROOT" | jq -c '
    [ ([], paths) as $p | getpath($p) as $n
      | select(($n|type) == "object" and $n.type == "pane" and $n.agent != null)
      | {path: $p, kind: $n.agent} ]')"

  AGENT_COUNT="$(printf '%s' "$AGENTS" | jq 'length')"
  for j in $(seq 0 $((AGENT_COUNT - 1))); do
    KIND="$(printf '%s' "$AGENTS" | jq -r --argjson j "$j" '.[$j].kind')"
    [ "$KIND" = '${AGENT}' ] && KIND="$AGENT"
    APATH="$(printf '%s' "$AGENTS" | jq -c --argjson j "$j" '.[$j].path')"
    PANE="$(printf '%s' "$RESP" | jq -r --argjson p "$APATH" \
      '.result.layout.root | getpath($p) | .pane_id')"
    say "  starting $KIND in $PANE ..."
    if ! herdr agent start "$NAME" --kind "$KIND" --pane "$PANE" >/dev/null 2>&1; then
      echo "WARNING: could not start $KIND in $PANE; the pane is left at a shell" >&2
    fi
  done
done

# The workspace shipped with a default tab. Close it once the real ones exist.
herdr tab close "$ROOT_TAB" >/dev/null 2>&1 || true

[ "$FOCUS" = "yes" ] && herdr workspace focus "$WS_ID" >/dev/null

say "herdr workspace ready: $LABEL ($WS_ID)"
echo "$WS_ID"
