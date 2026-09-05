# mtymek's dotfiles

My dotfiles managed by gnu stow.

## Installation

Clone the repository and use stow to symlink dotfiles:

```bash
git clone https://github.com/mtymek/dotfiles.git ~/dotfiles
cd ~/dotfiles
stow */  # Stow all packages
```

## Packages

### opencode

OpenCode configuration for AI-assisted development.

**Features:**
- Global OpenCode settings managed via dotfiles
- MCP Atlassian integration (disabled by default, enable manually as needed)
- Wrapper script bundled with configuration (fully portable)
- Consistent configuration across all machines

**Setup:**

1. **Initial setup** (included in standard stow):
   ```bash
   stow opencode
   ```
   This creates symlinks for:
   - `~/.config/opencode/opencode.json` - Configuration
   - `~/.local/bin/mcp-atlassian-wrapper` - MCP wrapper script

2. **Enable Atlassian MCP** (optional):
   - Copy the template: `cp ~/.config/opencode/.env.atlassian.example ~/.config/opencode/.env.atlassian`
   - Edit `~/.config/opencode/.env.atlassian` with your Atlassian credentials
   - Enable in OpenCode when needed by changing `"enabled": true` in `opencode.json`

**Files:**
- `opencode.json` - Version controlled, uses `${HOME}` for portability
- `.local/bin/mcp-atlassian-wrapper` - Version controlled wrapper script
- `.env.atlassian` - Machine-local secrets (gitignored, never committed)
- `.env.atlassian.example` - Template for setting up credentials

**Portability:**
The configuration is fully portable across machines. Just clone the repo and run `stow opencode` on any machine with OpenCode installed.

### herdr

[Herdr](https://herdr.dev) configuration — terminal workspace manager for AI coding agents.

**Features:**
- Enriched, commented `config.toml` (full option reference from `herdr --default-config`)
- Active settings limited to personal preferences (`onboarding = false`, `show_agent_labels_on_pane_borders = false`)
- Runtime files (logs, sockets, session state) kept out of version control

**Setup:**
```bash
stow herdr
```
This symlinks `~/.config/herdr/config.toml` into place. After editing, reload the running server with `herdr server reload-config`.

**Files:**
- `config.toml` - Version controlled, fully commented option reference
- `.gitignore` - Excludes Herdr runtime files (`*.log`, `*.sock`, `release-notes.json`, `session.json`)


### omarchy

Omarchy (Hyprland) configuration, including the monstar terminal integration.

**Features:**

- monstar terminal as the default terminal (`xdg-terminal-exec` resolves it for Super+Return, `omarchy launch tui`, etc.)
- Theme follows Omarchy: `monstar/config` points `theme =` at `~/.local/state/omarchy/current/theme/ghostty.conf`, which `omarchy theme set` regenerates in place
- Hooks reload monstar on theme switches and keep its `font-family` in sync with `omarchy font set`
- `monstar-sync.path` systemd user unit watches the ghostty config so `omarchy display text size` font-size changes propagate to monstar
- Universal clipboard binds (Super+C/V) send Ctrl+Shift+C/V to monstar windows, which bind copy/paste on those keys instead of the Insert keys the stock shortcuts send
- `xdg-terminals.list` lists a user copy of monstar's desktop entry whose id contains `ghostty`, purely so the packaged `omarchy-launch-screensaver` accepts the default terminal and runs the real ghostty binary for the idle screensaver

**Setup:**

```bash
stow omarchy
systemctl --user daemon-reload
systemctl --user enable --now monstar-sync.path
```

The `theme =` absolute path in `monstar/config` assumes home `/home/mat`. The alias desktop entry is a hack keyed to a substring match in `omarchy-launch-screensaver`; if Omarchy adds monstar to its terminal allowlist upstream, replace the first line of `xdg-terminals.list` with `dev.rockorager.monstar.desktop` and delete `dev.rockorager.monstar-ghostty.desktop`.

**Files:**

- `.config/monstar/config` - monstar settings (font, padding, opacity, theme)
- `.config/xdg-terminals.list` - default terminal preference order
- `.config/systemd/user/monstar-sync.{path,service}` - font-size sync watcher
- `.local/bin/monstar-sync-from-ghostty` - the sync script the unit runs
- `.local/share/applications/dev.rockorager.monstar-ghostty.desktop` - desktop entry alias for the screensaver check
- `.config/omarchy/hooks/{theme-set.d,font-set.d}/monstar.sh` - reload/sync hooks
