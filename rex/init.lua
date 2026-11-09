-- Migrated from tmux: ~/.tmux.conf and ~/bin/tmux/tmux.reset.conf.

-- Repeat mode stands in for tmux's `bind -r`: ctrl+a then ctrl+r enters it, enter or escape leaves.
rex.mode('repeat', { exclusive = true })
rex.bind('ctrl+a>ctrl+r', 'client.mode.enter', { name = 'repeat' })
rex.bind('repeat/enter', 'client.mode.exit')
rex.bind('repeat/escape', 'client.mode.exit')

-- ~/bin/tmux/tmux.reset.conf
-- Line 2 started this tab in $HOME; client.tab.new takes no directory.
rex.bind('ctrl+a>ctrl+c', 'client.tab.new')
rex.bind('ctrl+a>shift+h', 'client.tab.previous')
rex.bind('ctrl+a>shift+l', 'client.tab.next')
rex.bind('ctrl+a>r', 'client.tab.rename')
rex.bind('ctrl+a>z', 'pane.zoom')
rex.bind('ctrl+a>shift+s', 'session.switch')
rex.bind("ctrl+a>shift+'", 'session.switch')
rex.bind('ctrl+a>v', 'pane.split', { direction = 'right' })
rex.bind('ctrl+a>h', 'pane.focus', { direction = 'left' })
rex.bind('ctrl+a>j', 'pane.focus', { direction = 'down' })
rex.bind('ctrl+a>k', 'pane.focus', { direction = 'up' })
rex.bind('ctrl+a>l', 'pane.focus', { direction = 'right' })
rex.bind('ctrl+a>,', 'pane.resize', { amount = 20, direction = 'left' })
rex.bind('repeat/,', 'pane.resize', { amount = 20, direction = 'left' })
rex.bind('ctrl+a>.', 'pane.resize', { amount = 20, direction = 'right' })
rex.bind('repeat/.', 'pane.resize', { amount = 20, direction = 'right' })
rex.bind('ctrl+a>=', 'pane.resize', { amount = 7, direction = 'up' })
rex.bind('repeat/=', 'pane.resize', { amount = 7, direction = 'up' })
rex.bind('ctrl+a>x', 'pane.move', { direction = 'down' })

-- ~/.tmux.conf
rex.bind('ctrl+a>ctrl+space', 'pane.send_key', { key = 'ctrl+a' })
rex.bind('ctrl+a>n', 'client.tab.next')
rex.bind('repeat/n', 'client.tab.next')
rex.bind('ctrl+a>p', 'client.tab.previous')
rex.bind('repeat/p', 'client.tab.previous')
rex.bind('ctrl+a>ctrl+p', 'client.tab.previous')
rex.bind('ctrl+a>ctrl+n', 'client.tab.next')
rex.bind('ctrl+a>shift+\\', 'pane.split', { direction = 'right' })
rex.bind('ctrl+a>-', 'pane.split', { direction = 'down' })
rex.bind('ctrl+a>c', 'client.tab.new')

-- Custom actions
require('actions')
rex.bind('ctrl+a>g', 'lazygit_float')
rex.bind('ctrl+a>e', 'nvim_float')
