local wezterm = require("wezterm")

local config = wezterm.config_builder()

local function scheme_for_appearance(appearance)
	if appearance:find("Dark") then
		return "Palenight (Gogh)"
	else
		return "flexoki-light"
	end
end

local function tabbar_for_appearance(appearance)
	if appearance:find("Dark") then
		return {
			frame_active_bg = "#1C1B1A",
			frame_inactive_bg = "#1C1B1A",
			active = {
				bg = "#1C1B1A",
				fg = "#CECDC3",
			},
			inactive = {
				bg = "#282726",
				fg = "#878580",
			},
			new_tab = {
				bg = "#1C1B1A",
				fg = "#CECDC3",
			},
		}
	else
		return {
			frame_active_bg = "#E6E4D9",
			frame_inactive_bg = "#E6E4D9",
			active = {
				bg = "#E6E4D9",
				fg = "#100F0F",
			},
			inactive = {
				bg = "#F2F0E5",
				fg = "#6F6E69",
			},
			new_tab = {
				bg = "#E6E4D9",
				fg = "#100F0F",
			},
		}
	end
end

config.font = wezterm.font("Dank Mono")
config.font_size = 23

config.window_background_opacity = 1
config.window_decorations = "RESIZE"

config.hide_tab_bar_if_only_one_tab = true
config.use_fancy_tab_bar = false

do
	local appearance = wezterm.gui.get_appearance()
	config.color_scheme = scheme_for_appearance(appearance)

	local t = tabbar_for_appearance(appearance)
	config.window_frame = {
		font = wezterm.font({ family = "Dank Mono", weight = "Bold" }),
		font_size = 15,
		active_titlebar_bg = t.frame_active_bg,
		inactive_titlebar_bg = t.frame_inactive_bg,
	}
	config.colors = {
		tab_bar = {
			active_tab = { bg_color = t.active.bg, fg_color = t.active.fg },
			inactive_tab = { bg_color = t.inactive.bg, fg_color = t.inactive.fg },
			new_tab = { bg_color = t.new_tab.bg, fg_color = t.new_tab.fg },
		},
	}
end

wezterm.on("window-config-reloaded", function(window, _)
	local appearance = wezterm.gui.get_appearance()
	local overrides = window:get_config_overrides() or {}
	overrides.color_scheme = scheme_for_appearance(appearance)

	local t = tabbar_for_appearance(appearance)
	overrides.window_frame = {
		active_titlebar_bg = t.frame_active_bg,
		inactive_titlebar_bg = t.frame_inactive_bg,
	}
	overrides.colors = overrides.colors or {}
	overrides.colors.tab_bar = {
		active_tab = { bg_color = t.active.bg, fg_color = t.active.fg },
		inactive_tab = { bg_color = t.inactive.bg, fg_color = t.inactive.fg },
		new_tab = { bg_color = t.new_tab.bg, fg_color = t.new_tab.fg },
	}

	window:set_config_overrides(overrides)
end)

return config
