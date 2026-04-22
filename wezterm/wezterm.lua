local wezterm = require 'wezterm'

return {
	adjust_window_size_when_changing_font_size = false,
	-- color_scheme = 'termnial.sexy',
	color_scheme = 'Catppuccin Mocha',
	enable_tab_bar = false,
	font_size = 18.0,
	font = wezterm.font('Monaspace krypton'),
	-- macos_window_background_blur = 40,
	macos_window_background_blur = 30,

	--window_background_image = '/Users/mwamodo/Pictures/moon.jpg',
	-- window_background_image_hsb = {
	--	brightness = 0.10,
	-- 	hue = 1.0,
	-- 	saturation = 0.5,
	--},
	window_background_opacity = 0.52,
	window_decorations = 'RESIZE',
	keys = {
		{
			key = 'q',
			mods = 'CTRL',
			action = wezterm.action.ToggleFullScreen,
		},
		{
			key = '\'',
			mods = 'CTRL',
			action = wezterm.action.ClearScrollback 'ScrollbackAndViewport',
		},
	},
	mouse_bindings = {
	  {
	    event = { Up = { streak = 1, button = 'Left' } },
	    mods = 'CTRL',
	    action = wezterm.action.OpenLinkAtMouseCursor,
	  },
	},
}
