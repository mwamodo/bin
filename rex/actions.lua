local terminal = 'com.superlogical.terminal'

-- Defines a palette action that runs a command in a floating pane, in spec.cwd or else the focused pane's directory.
-- spec.bounds is x, y, width, height as fractions of the window, nearly full-window by default.
local function float_action(spec)
  rex.action({
    name = spec.name,
    title = spec.title,
    keywords = spec.keywords,
    run = function(ctx)
      local cwd = spec.cwd
      if not cwd then
        local proc = rex.block.call(terminal, 'process', { block_id = ctx.block_id })
        cwd = proc and proc.foreground and proc.foreground.cwd
      end

      local _, err = rex.session.new_layer({
        bounds = spec.bounds or { 0.05, 0.05, 0.9, 0.9 },
        layout = rex.layout.block({
          flavor = terminal .. '.shell',
          -- interactive: Homebrew's PATH is set in .zshrc, which commands don't read otherwise.
          options = { command = spec.command, cwd = cwd, interactive = true },
        }),
        focus = true,
      })
      if err ~= nil then error(err, 0) end
    end,
  })
end

float_action({
  name = 'lazygit_float',
  title = 'Lazygit',
  keywords = 'git float',
  command = { 'lazygit' },
})

float_action({
  name = 'nvim_float',
  title = 'Neovim',
  keywords = 'nvim vim editor float',
  command = { 'nvim', '.' },
})

float_action({
  name = 'notes_float',
  title = 'Notes',
  keywords = 'notes obsidian vault nvim editor float',
  command = { 'nvim', '.' },
  cwd = os.getenv('HOME') .. '/notes',
  bounds = { 0.5, 0, 0.5, 1 },
})

float_action({
  name = 'open_project',
  title = 'Open Project',
  keywords = 'project folder session open switch',
  command = { os.getenv('HOME') .. '/.config/rex/open-project.sh' },
  bounds = { 0.25, 0.2, 0.5, 0.5 },
})
