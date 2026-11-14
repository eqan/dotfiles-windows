local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- Keep PowerShell 7 as the default shell while using WezTerm as the emulator.
config.default_prog = { 'pwsh.exe', '-NoLogo' }

config.font = wezterm.font 'JetBrainsMono Nerd Font'
config.font_size = 11.0
config.line_height = 1.05
config.colors = {
  foreground = '#D8DEE9',
  background = '#0B0E14',
  cursor_bg = '#88C0D0',
  cursor_fg = '#0B0E14',
  selection_bg = '#3B4252',
  selection_fg = '#ECEFF4',
  ansi = {
    '#0B0E14', '#BF616A', '#A3BE8C', '#EBCB8B',
    '#81A1C1', '#B48EAD', '#88C0D0', '#D8DEE9',
  },
  brights = {
    '#4C566A', '#D08770', '#B8D89C', '#F0DFAF',
    '#8FBCBB', '#C89FC9', '#8FBCBB', '#ECEFF4',
  },
}
config.window_background_opacity = 0.96
config.hide_tab_bar_if_only_one_tab = false
config.use_fancy_tab_bar = true
config.tab_bar_at_bottom = false
config.show_new_tab_button_in_tab_bar = true
config.window_padding = { left = 8, right = 8, top = 6, bottom = 4 }
config.default_cursor_style = 'SteadyBar'
config.audible_bell = 'Disabled'
config.scrollback_lines = 10000

config.keys = {
  { key = 't', mods = 'CTRL|SHIFT', action = wezterm.action.SpawnTab 'CurrentPaneDomain' },
  { key = 'w', mods = 'CTRL|SHIFT', action = wezterm.action.CloseCurrentTab { confirm = true } },
  { key = 'LeftArrow', mods = 'CTRL|SHIFT', action = wezterm.action.ActivateTabRelative(-1) },
  { key = 'RightArrow', mods = 'CTRL|SHIFT', action = wezterm.action.ActivateTabRelative(1) },
  { key = 'Enter', mods = 'ALT', action = wezterm.action.SpawnWindow },
}

return config
