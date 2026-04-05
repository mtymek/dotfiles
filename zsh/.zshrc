if command -v starship &> /dev/null; then
  eval "$(starship init zsh)"
fi

[ -s "/Users/mat/.bun/_bun" ] && source "/Users/mat/.bun/_bun"
source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# load module for list-style selection
zmodload zsh/complist

# use the module above for autocomplete selection
zstyle ':completion:*' menu yes select

# now we can define keybindings for complist module
# you want to trigger search on autocomplete items
# so we'll bind some key to trigger history-incremental-search-forward function
bindkey -M menuselect '?' history-incremental-search-forward
bindkey "^[[A" history-beginning-search-backward
bindkey "^[[B" history-beginning-search-forward

# Exports
export EDITOR=/opt/homebrew/bin/nvim
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
alias l="eza -l --icons --git -a"
alias ls="eza"
alias lt="eza --tree --level=2 --long --icons --git"
alias ltree="eza --tree --level=2  --icons --git"


