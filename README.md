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

