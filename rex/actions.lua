local terminal = 'com.superlogical.terminal'

-- Defines a palette action that runs a command in a floating pane, in spec.cwd or else the focused pane's directory.
-- spec.bounds is x, y, width, height as fractions of the window, nearly full-window by default.
local function float_action(spec)
  rex.action {
    name = spec.name,
    title = spec.title,
    keywords = spec.keywords,
    run = function(ctx)
      local cwd = spec.cwd
      if not cwd then
        local proc = rex.block.call(terminal, 'process', { block_id = ctx.block_id })
        cwd = proc and proc.foreground and proc.foreground.cwd
      end

      local _, err = rex.session.new_layer {
        bounds = spec.bounds or { 0.05, 0.05, 0.9, 0.9 },
        layout = rex.layout.block {
          flavor = terminal .. '.shell',
          -- interactive: Homebrew's PATH is set in .zshrc, which commands don't read otherwise.
          options = { command = spec.command, cwd = cwd, interactive = true },
        },
        focus = true,
      }
      if err ~= nil then
        error(err, 0)
      end
    end,
  }
end

float_action {
  name = 'lazygit_float',
  title = 'Lazygit',
  keywords = 'git float',
  command = { 'lazygit' },
}

float_action {
  name = 'nvim_float',
  title = 'Neovim',
  keywords = 'nvim vim editor float',
  command = { 'nvim', '.' },
}

float_action {
  name = 'notes_float',
  title = 'Notes',
  keywords = 'notes obsidian vault nvim editor float',
  command = { 'nvim', '.' },
  cwd = os.getenv 'HOME' .. '/notes',
  bounds = { 0.5, 0, 0.5, 1 },
}

-- Pick a project in the command palette and switch to its session, creating the session in the project's folder
-- if none is open. Passing dir skips the picker: rex do open_project dir="$HOME/bin"
rex.action {
  name = 'open_project',
  title = 'Open Project',
  keywords = 'project folder session open switch',
  args = { dir = 'string?' },
  run = function(ctx, args)
    local home = os.getenv 'HOME'
    local listed, err = rex.exec({ home .. '/.config/rex/list-projects.sh' }, { timeout = 10 })
    if listed == nil then
      error(err, 0)
    end
    if not listed.ok then
      error(listed.stderr, 0)
    end

    local dirs, shared = {}, {}
    for dir in listed.stdout:gmatch '[^\n]+' do
      local name = dir:match '[^/]+$'
      dirs[#dirs + 1] = dir
      shared[name] = (shared[name] or 0) + 1
    end

    -- A session is labelled with the project's folder name, or parent/name when two projects share a name.
    local function label(dir)
      local name = dir:match '[^/]+$'
      return (shared[name] or 0) > 1 and dir:match '[^/]+/[^/]+$' or name
    end

    local dir = args.dir and args.dir:gsub('/+$', '')
    if not dir then
      local items = {}
      for i, path in ipairs(dirs) do
        items[i] = { id = path, title = label(path), subtitle = '~' .. path:sub(#home + 1), icon = 'folder' }
      end

      local why, detail
      dir, why, detail = rex.ui.pick { title = 'Open project', placeholder = 'Filter projects', items = items }
      if dir == nil then
        if why == 'cancelled' or why == 'timeout' then
          return
        end
        error('project picker: ' .. (detail or why), 0)
      end
    end

    local sessions, list_err = rex.call 'session.list'
    if sessions == nil then
      error(list_err, 0)
    end

    local session_id
    for _, session in ipairs(sessions.sessions or {}) do
      if session.label == label(dir) then
        session_id = session.session_id
        break
      end
    end

    if not session_id then
      local created, create_err = rex.call('session.create', {
        label = label(dir),
        initial_windows = {
          { layout = rex.layout.block { flavor = terminal .. '.shell', options = { cwd = dir } } },
        },
      })
      if created == nil then
        error(create_err, 0)
      end
      session_id = created.session_id
    end

    rex.client.queue('session.select', { session_id = session_id })
  end,
}
