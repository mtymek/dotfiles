-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- To disable every Omarchy default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.omarchy"), then add
-- only the bindings you want below:
--   omarchy_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
--   omarchy_preinstalled_bindings = false

-- Add a new binding.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Change an existing binding by unbinding it first, then binding the key again.
-- This example changes SUPER+SPACE from the launcher to the Omarchy root menu.
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "Omarchy menu", "omarchy-menu toggle root")

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")

-- Logitech MX Keys examples:
-- o.bind("SUPER + SHIFT + S", nil, "omarchy-capture-screenshot")
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, "omarchy-shell shell toggle omarchy.emojis")

-- Voice to text (dictation): hold F5 to talk instead of F9.
hl.unbind("F9")
o.bind("F5", "Start dictation (push-to-talk)", "voxtype record start")
o.bind("F5", "Stop dictation (push-to-talk)", "voxtype record stop", { release = true })



-- PHP/Neovim cheat sheet popup. Press once to pop it up, press again to dismiss
-- it. Window geometry is set by the rule at the bottom of hyprland.lua.
o.bind("SUPER + SHIFT + H", "PHP Command Card", "/home/mat/Work/cheatsheets/toggle-card.sh")

-- Universal clipboard with monstar support. Re-binds SUPER+C and SUPER+V from
-- default/hypr/bindings/clipboard.lua, which sends Ctrl+Insert / Shift+Insert
-- to terminal windows: ghostty/kitty/foot bind those keys, monstar only
-- implements Ctrl+Shift+C / Ctrl+Shift+V, so it needs its own chord.
local function send_shortcut_once(mods, key)
  return function()
    hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "down" }))

    hl.timer(function()
      hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "up" }))
    end, { timeout = 50, type = "oneshot" })
  end
end

-- monstar windows launched by `omarchy launch tui` carry a different app-id,
-- so also recognize the emulator by the process behind the window.
local function window_belongs_to_monstar(window)
  if window == nil then
    return false
  end
  if window.class == "dev.rockorager.monstar" then
    return true
  end
  local pid = window.pid
  if pid == nil then
    return false
  end
  local ok, handle = pcall(io.open, string.format("/proc/%d/comm", pid))
  if ok and handle then
    local comm = handle:read("*l") or ""
    handle:close()
    return comm == "monstar"
  end
  return false
end

-- Lean on the terminal tag from default/hypr/apps/terminals.lua. Dynamic tags
-- carry a trailing "*".
local function active_window_is_terminal()
  local window = hl.get_active_window()
  if not window then
    return false
  end

  for _, tag in ipairs(window.tags or {}) do
    if tag:gsub("%*$", "") == "terminal" then
      return true
    end
  end

  return false
end

local function universal_clipboard_shortcut(default_mods, default_key, terminal_mods, terminal_key, monstar_mods, monstar_key)
  return function()
    if window_belongs_to_monstar(hl.get_active_window()) then
      send_shortcut_once(monstar_mods, monstar_key)()
    elseif active_window_is_terminal() then
      send_shortcut_once(terminal_mods, terminal_key)()
    else
      send_shortcut_once(default_mods, default_key)()
    end
  end
end

-- SUPER+C/V were previously the plain universal clipboard shortcuts from
-- default/hypr/bindings/clipboard.lua; these keep that behavior everywhere
-- else and add the monstar chord.
hl.unbind("SUPER + C")
o.bind("SUPER + C", "Universal copy", universal_clipboard_shortcut("CTRL", "C", "CTRL", "Insert", "CTRL+SHIFT", "C"))

hl.unbind("SUPER + V")
o.bind("SUPER + V", "Universal paste", universal_clipboard_shortcut("CTRL", "V", "SHIFT", "Insert", "CTRL+SHIFT", "V"))
