---
name: jj-workspace
description: Create and manage isolated Jujutsu (jj) workspaces for any project, stored under PROJ_DIR/.jj-workspaces/. Use when the user asks to "create a jj workspace", "start an isolated workspace", "make a workspace for feature X", "work in a separate workspace", "list workspaces", "attach/resume a workspace", "destroy/remove/delete a workspace", or wants parallel or isolated working copies of the same repo.
---

# JJ Workspace

Create and manage isolated jj workspaces under `.jj-workspaces/` for any project. Each workspace is a separate working copy backed by the same jj repo, letting multiple pieces of feature work proceed in parallel without sharing a dirty working copy.

**Announce at start:** "Using the jj-workspace skill to manage isolated workspaces."

## Prerequisites

- `jj` installed and the repo initialized (`.jj/` exists at the project root)
- `.jj-workspaces/` gitignored — configured globally in `~/.config/git/ignore`. To share the rule with teammates, add `.jj-workspaces/` to the project's `.gitignore`.
- Run all commands from the **project root** (the primary workspace), not from inside another workspace
- For the herdr integration: `herdr`, `jq` and `socat` on PATH, and a shell inside a herdr pane (`HERDR_ENV=1`). Without them every script still works; the herdr steps skip themselves.

## Workflow Overview

create → work → list / attach → save-context → destroy

Scripts live in `scripts/` relative to this skill. Invoke them with `bash scripts/<script>.sh ...` (paths relative to the skill base directory).

## Creating a Workspace

Run `jj-workspace-create.sh NAME [REVISION]` from the project root:

```bash
bash scripts/jj-workspace-create.sh feat-publisher
bash scripts/jj-workspace-create.sh cpnthi-42 origin/main
bash scripts/jj-workspace-create.sh feat-publisher --agent opencode --focus
```

- `NAME`: lowercase alphanumeric slug with hyphens (e.g. `feat-publisher`, `cpnthi-42`)
- `REVISION`: jj revset to base the workspace on. Defaults to the **parent of the current working copy** (`@-`), so in-progress changes in the primary workspace are NOT inherited. Pass `@` explicitly to include them. Other useful choices: `@-`, `trunk()`, `origin/main`.
- `--agent KIND`: which agent to start in the layout's agent pane. Default `claude`. Any kind herdr supports, including `opencode`, `codex`, `gemini`.
- `--no-setup`: skip the layout's bootstrap command.
- `--no-herdr`: create the jj workspace only.
- `--focus`: switch to the new herdr workspace once it is built.

The script validates the slug, the revision, and that it runs from the project root; fails if the workspace already exists; then runs `jj workspace add --name <NAME> .jj-workspaces/<NAME>`. The workspace is created at `.jj-workspaces/<NAME>/`, and any available context handoffs are listed.

It then runs the layout's `setup` command in the new directory, and hands off to `herdr-workspace-open.sh`.

**Bookmarks are global** — creating a bookmark in any workspace makes it visible in all. The script does not create bookmarks automatically; create them manually when needed.

## Working in a Workspace

```bash
cd .jj-workspaces/feat-publisher
jj st        # status
jj log       # history
jj desc -m "..."   # describe work
```

The workspace shares the repo store with the primary workspace: commits, bookmarks, and change IDs are all shared.

## The herdr workspace

Inside herdr, a jj workspace gets a herdr workspace of its own, labelled `<repo>:<name>` — `cto-dashboard:velocity-extensions`, `cto-dashboard:mcp-access` — with its tabs and pane splits built from a declarative layout. `<repo>` is the basename of the primary workspace root, `<name>` the jj workspace slug. Outside herdr every script behaves as it always did.

```bash
bash scripts/herdr-workspace-open.sh feat-publisher --agent claude --focus
```

The script is idempotent. A workspace already carrying the label is focused, never rebuilt, because rebuilding kills whatever is running in it. Open and destroy also match the pre-rename `<repo> - <name>` label on the read side, so a workspace built before the naming changed is still found rather than duplicated.

### The layout file

Resolution order: `--layout FILE`, then `<repo>/.jj-workspaces/layout.json`, then `layouts/default.json` in this skill. Note that `.jj-workspaces/` is gitignored, so a per-project layout is not shared with teammates. Commit it elsewhere in the repo and point `--layout` at it if you want that.

```json
{
  "setup": "task setup -- --from default",
  "env": {},
  "tabs": [
    {
      "label": "Agent",
      "root": {
        "type": "split", "direction": "right", "ratio": 0.5,
        "first":  { "type": "pane", "agent": "${AGENT}" },
        "second": { "type": "pane" }
      }
    },
    {
      "label": "nvim",
      "root": {
        "type": "pane",
        "command": ["nvim", "."],
        "env": { "GIT_CEILING_DIRECTORIES": "${WORKSPACE_PARENT}" }
      }
    },
    { "label": "server", "root": { "type": "pane", "command": ["task", "serve"] } }
  ]
}
```

Each `tabs[].root` is a herdr `LayoutNode`: a `pane` with optional `command`, `cwd`, `env`, `label`, or a `split` with `direction` (`right` or `down`), `ratio`, `first` and `second`. `cwd` is filled in automatically with the new workspace path, so leave it out.

### Pane environment

The top-level `env` applies to every pane; a pane's own `env` is merged over it. Three placeholders are expanded in the values, because the useful ones are paths a layout file cannot know: `${WORKSPACE}` is the workspace directory, `${WORKSPACE_PARENT}` is `.jj-workspaces`, `${WORKSPACE_NAME}` is the slug.

`PWD` is always set to the workspace directory. herdr sets a pane's cwd but leaves the inherited `PWD` alone, so a pane launching a command directly rather than a shell reports the terminal's original directory to anything reading `$PWD` instead of calling `getcwd`. A shell pane overwrites it anyway, so setting it is never wrong.

**Why the editor pane sets `GIT_CEILING_DIRECTORIES`.** A jj workspace is not a git worktree, so `.jj-workspaces/<name>` has no `.git` and git resolves upward to the main repo, where `.jj-workspaces/` is ignored. Every file in the workspace then answers `git check-ignore` positively and editors that filter on gitignore show the whole tree as hidden. The ceiling stops the upward walk, git reports no repository, and the filter has nothing to act on. Nothing useful is lost: `git ls-files` inside a workspace already returns 0.

Set it per pane, not at the top level. `git show`, `git ls-tree`, `git diff` and `git cat-file` are the documented read-only escape hatch in a jj repo, and a pane with the ceiling set cannot run them.

`agent` is this skill's own key, not herdr's. It is stripped before the layout is sent, and the pane is then handed to `herdr agent start <workspace-name> --kind <kind> --pane <id>`, which waits for the agent to become interactive and registers it for lifecycle tracking. `"${AGENT}"` takes the value of `--agent`. A literal kind such as `"agent": "codex"` pins that pane regardless.

`setup` is run by `jj-workspace-create.sh`, in the new directory, **before** any herdr workspace exists. It does not run in a pane, for two reasons that both bit during development. Wrangler and friends prompt `continue? (Y/n)` on a TTY and a pane is a TTY. And `herdr pane wait-output` searches existing output before polling, so a sentinel echoed as the shell types the command line matches immediately and the wait returns before the work has started. Running it here gives a real exit code and a non-TTY.

### How the layout is applied

`layout.export`, `layout.apply` and `layout.set_split_ratio` exist only on herdr's socket API. There is no `herdr layout` subcommand, so the script speaks newline-delimited JSON over `$HERDR_SOCKET_PATH` with `socat`. One `layout.apply` per tab.

**`layout.apply` is destructive against an existing tab.** With `workspace_id` and `tab_label` and no `tab_id` it creates a tab, which is the only form this skill uses. With `tab_id` herdr "creates the replacement tab first and then closes the old tab": the tab gets a new id, every pane in it dies, and naming an existing `pane_id` in the tree does not preserve it. Never point it at a tab holding a live agent.

`layout.export` returns structure and `cwd` but not the running command, so it cannot round-trip a live workspace on its own. Pair it with `herdr pane process-info --pane <id>` if you ever want to capture one.

### Optional: herdr-jj for the read side

[herdr-jj](https://github.com/OliverGilan/herdr-jj) adds a workspace picker, `$jj_change` and `$jj_status` in the sidebar, and keybindings. Its read paths resolve through `jj workspace root --name <name>`, so they work on workspaces this skill created.

Do not use its create action alongside this skill. It hard-codes `<workspace_root>/<repo>/<slug>` as the checkout path, which cannot produce `.jj-workspaces/<name>`, and it hard-codes `trunk()` as the revision against this skill's `@-` default.

## Listing and Attaching

```bash
bash scripts/jj-workspace-list.sh                  # all workspaces + paths, * marks cwd
bash scripts/jj-workspace-attach.sh feat-publisher # focus the herdr workspace
bash scripts/jj-workspace-attach.sh feat-publisher --no-herdr   # print the cd command
```

Use `attach` when resuming work on an existing workspace. It's idempotent. Inside herdr it focuses the workspace, building it from the layout first if it is missing, which is what makes attach work after a herdr restart.

## Saving Context (before destroy)

Save a context handoff before destroying a workspace so future workspaces can pick up where it left off:

```bash
bash scripts/jj-workspace-save-context.sh feat-publisher
```

Creates `.jj-workspaces/handoffs/feat-publisher.md` with a pre-filled template (workspace revision, commits, changed files). **Fill it in** — write a useful summary of what was done, key decisions, and remaining work. Update the `related: []` field to link related workspaces.

Load a handoff into a new workspace with:

```bash
cp .jj-workspaces/handoffs/<name>.md .jj-workspaces/<new-slug>/CONTEXT.md
```

Handoffs live under `.jj-workspaces/`, so they stay gitignored.

## Destroying a Workspace

```bash
bash scripts/jj-workspace-destroy.sh feat-publisher
bash scripts/jj-workspace-destroy.sh feat-publisher --force   # skip handoff check
```

The script refuses to destroy unless a context handoff exists (or `--force` is passed), closes the matching herdr workspace, then runs `jj workspace forget <NAME>` to detach the workspace from the repo, and removes `.jj-workspaces/<NAME>/`.

The herdr workspace is closed **first**. Removing the directory under live panes leaves them in a deleted cwd, and a dev server still holding files open is exactly the state those panes would be in. Destroying the herdr workspace you are currently sitting in is refused; switch away first.

**`jj workspace forget` does not delete files** — destroy handles both. Commits created in the destroyed workspace remain in the repo (reachable by change ID / bookmarks), so committed work is never lost.

## Common Issues

- **"not inside a jj repository"** — run from the project root where `.jj/` lives.
- **"run this from the project root"** — the primary workspace is `$(jj workspace root)`; run all scripts from there, not from inside `.jj-workspaces/<name>/`.
- **"workspace already exists"** — use a different NAME, or destroy the existing one first.
- **"unknown revision"** — the revset does not resolve; check it with `jj log -r trunk()`.
- **New workspace inherits uncommitted changes** — the default base is the parent of `@`; only explicit `--revision @` includes in-progress changes.
- **"jq is required" / "socat is required"** — `layout.apply` has no CLI subcommand, so the herdr step needs both. Install them, or pass `--no-herdr`.
- **The herdr step did nothing** — `HERDR_ENV` is unset, so the shell is not in a herdr pane. The jj workspace is still created; run `herdr-workspace-open.sh NAME` from inside herdr afterwards.
- **The agent pane is a bare shell** — `herdr agent start` failed, usually a kind that is not installed. The layout is still correct; start the agent by hand in that pane.
- **`setup` failed** — the jj workspace exists and no herdr workspace was built. Fix the cause, run the setup command by hand in the workspace, then `herdr-workspace-open.sh NAME`.
- **The editor shows every file as hidden or ignored** — the pane is missing `GIT_CEILING_DIRECTORIES`. See "Pane environment" above. Confirm with `git check-ignore -v README.md` inside the workspace; if it names `**/.jj-workspaces/`, that is the cause.
