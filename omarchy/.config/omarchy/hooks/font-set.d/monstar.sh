#!/bin/bash
# omarchy-font-set only rewrites alacritty/kitty/ghostty/foot. Keep monstar's
# font-family in sync with the font name passed as $1, then reload it.
config="$HOME/.config/monstar/config"
[[ -f $config ]] || exit 0
[[ -n ${1:-} ]] && sed -i -E "s/^font-family = .*/font-family = $1/" "$config"
pkill -USR1 -x monstar 2>/dev/null || true
