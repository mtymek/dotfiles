-- Learn how to configure Hyprland: https://wiki.hypr.land/Configuring/Start/

-- Omarchy's bootstrap keeps path setup out of this user config.
dofile((os.getenv("OMARCHY_PATH") or "/usr/share/omarchy") .. "/default/hypr/bootstrap.lua")

-- Disable all Omarchy default bindings. Add your own in hypr/bindings.lua.
-- omarchy_default_bindings = false
--
-- Or disable only bindings for Omarchy's preinstalled apps/web apps while
-- keeping core window-manager bindings:
-- omarchy_preinstalled_bindings = false

-- Load Omarchy defaults.
require("default.hypr.omarchy")

-- Put your personal overrides in these files. They're loaded after Omarchy's
-- defaults so package updates can improve the defaults without rewriting your
-- ~/.config/hypr files.
require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.autostart")

-- Toggle config flags dynamically.
require("default.hypr.toggles")

-- Add any other personal Hyprland configuration below.
-- o.window("qemu", { workspace = "5" })

-- PHP Command Card cheat sheet: a popup that floats over whatever is underneath
-- instead of taking a tile. Deliberately not pinned, so it stays on the
-- workspace it was opened on rather than following you around.
o.window("^chrome-__home_mat_Work_cheatsheets_nvim-php\\.html-Default$", {
  float = true,
  center = true,
  size = { 1600, 1000 },
})

-- monstar: count it as a terminal so shared terminal handling applies.
-- The +terminal tag drives the clipboard copy/paste remap, see
-- default/hypr/bindings/clipboard.lua and default/hypr/apps/terminals.lua.
o.window("dev\\.rockorager\\.monstar", { tag = "+terminal" })
