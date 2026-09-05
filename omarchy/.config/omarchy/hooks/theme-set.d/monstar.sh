#!/bin/bash
# monstar picks up the active Omarchy theme through the symlinked theme file
# ~/.config/monstar/themes/omarchy, whose target `omarchy theme set` rewrites.
# Reload running monstar instances so the new colors show immediately.
pkill -USR1 -x monstar 2>/dev/null || true
