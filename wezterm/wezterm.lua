local wezterm = require 'wezterm'

local config = wezterm.config_builder()

config.color_scheme = 'Catppuccin Mocha'

config.font = wezterm.font('Dank Mono')
config.font_size = 18

config.window_background_opacity = 0.9

return config
