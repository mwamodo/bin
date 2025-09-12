local wezterm = require 'wezterm'

local config = wezterm.config_builder()

config.color_scheme = 'Catppuccin Mocha'

config.font = wezterm.font('Dank Mono')
config.font_size = 18

config.window_background_opacity = 0.9
config.window_decorations = 'RESIZE'

config.hide_tab_bar_if_only_one_tab = true
config.use_fancy_tab_bar = false

config.window_frame = {
    font = wezterm.font { family = 'Dank Mono', weight = 'Bold' },
    font_size = 15,

    active_titlebar_bg = '#1e1e2e',
    inactive_titlebar_bg = '#1e1e2e',
}

config.colors = {
    tab_bar = {
        active_tab = {
            bg_color = '#1e1e2e',
            fg_color = '#cdd6f4'
        },
        inactive_tab = {
            bg_color = '#181825',
            fg_color = '#cdd6f4',
        },
        new_tab = {
            bg_color = '#1e1e2e',
            fg_color = '#cdd6f4',
        }
    }
}

return config
