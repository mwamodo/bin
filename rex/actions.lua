-- Lazygit in a floating pane, opened in the focused pane's directory.
rex.action({
  name = 'lazygit_float',
  title = 'Lazygit',
  keywords = 'git float',
  run = function(ctx)
    local proc = rex.block.call('com.superlogical.terminal', 'process', { block_id = ctx.block_id })
    local cwd = proc and proc.foreground and proc.foreground.cwd

    local _, err = rex.session.new_layer({
      bounds = { 0.05, 0.05, 0.9, 0.9 },
      layout = rex.layout.block({
        flavor = 'com.superlogical.terminal.shell',
        options = { command = { 'lazygit' }, cwd = cwd, interactive = true },
      }),
      focus = true,
    })
    if err ~= nil then error(err, 0) end
  end,
})
