# History
setopt SHARE_HISTORY 
setopt PROMPT_SUBST
HISTFILE=~/.history
HISTSIZE=10000
SAVEHIST=50000

# Prompt
if command -v starship &> /dev/null; then
  eval "$(starship init zsh)"
fi

[ -s "/Users/mat/.bun/_bun" ] && source "/Users/mat/.bun/_bun"
if command -v brew &> /dev/null; then
    source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh
else
    source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

# Completion
autoload -Uz compinit && compinit

source <(COMPLETE=zsh jj)
source <(fzf --zsh)

# load module for list-style selection
zmodload zsh/complist

# use the module above for autocomplete selection
zstyle ':completion:*' menu yes select

# now we can define keybindings for complist module
# you want to trigger search on autocomplete items
# so we'll bind some key to trigger history-incremental-search-forward function
bindkey -M menuselect '?' history-incremental-search-forward
bindkey "^[[A" history-search-backward
bindkey "^[[B" history-search-forward

# Exports
export EDITOR=nvim
export SUDO_EDITOR="$EDITOR"
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:/Users/mat/.cargo/bin:$HOME/.bin:$HOME/go/bin:$PATH"

# Aliases

# Docker
alias d="docker"
alias dc="docker compose"
alias dce="docker compose exec"

# Git
alias g="git"
alias gc="git commit"
alias gs="git status -s"
alias gpu="git pull origin"
alias gl="git log --graph --topo-order --pretty='%w(100,0,6)%C(yellow)%h%C(bold)%C(black)%d %C(cyan)%ar %C(green)%an%n%C(bold)%C(white)%s %N' --abbrev-commit"

# Dirs
alias ..="cd .."
alias ...="cd ../..; pwd"
alias ....="cd ../../..; pwd"
alias .....="cd ../../../..; pwd"
alias ......="cd ../../../../..; pwd"

# Eza
alias l="eza --group-directories-first -l --icons --git -a"
alias ls="eza --group-directories-first"
alias lt="eza --tree --level=2 --long --icons --git"
alias ltree="eza --tree --level=2 --long --icons --git"

# Fzf helpers
#if [[ "$TERM" == "xterm-kitty" ]]; then
  alias ff="fzf --preview 'case \$(file --mime-type -b {}) in image/*) kitty icat --clear --transfer-mode=memory --stdin=no --place=\${FZF_PREVIEW_COLUMNS}x\${FZF_PREVIEW_LINES}@0x0 {} ;; *) bat --style=numbers --color=always {} ;; esac'"
#else
#  alias ff="fzf --preview 'bat --style=numbers --color=always {}'"
#fi
alias eff='$EDITOR "$(ff)"'
sff() { if [ $# -eq 0 ]; then echo "Usage: sff <destination> (e.g. sff host:/tmp/)"; return 1; fi; local file; file=$(find . -type f -printf '%T@\t%p\n' | sort -rn | cut -f2- | ff) && [ -n "$file" ] && scp "$file" "$1"; }

# Zoxide (smart cd)
if command -v zoxide &> /dev/null; then
  alias cd="zd"
  zd() {
    if (( $# == 0 )); then
      builtin cd ~ || return
    elif [[ -d $1 ]]; then
      builtin cd "$1" || return
    else
      if ! z "$@"; then
        echo "Error: Directory not found"
        return 1
      fi
      printf "\U000F17A9 "
      pwd
    fi
  }
fi

# Tools
alias c='opencode'
alias cx='printf "\033[2J\033[3J\033[H" && claude --allow-dangerously-skip-permissions'
n() { if [ "$#" -eq 0 ]; then command nvim . ; else command nvim "$@"; fi; }
open() (
  xdg-open "$@" >/dev/null 2>&1 &
)
