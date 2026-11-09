local terminal = 'com.superlogical.terminal'

-- Defines a palette action that runs a command in a floating pane, in the focused pane's directory.
local function float_action(spec)
  rex.action({
    name = spec.name,
    title = spec.title,
    keywords = spec.keywords,
    run = function(ctx)
      local proc = rex.block.call(terminal, 'process', { block_id = ctx.block_id })
      local cwd = proc and proc.foreground and proc.foreground.cwd

      local _, err = rex.session.new_layer({
        bounds = { 0.05, 0.05, 0.9, 0.9 },
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
