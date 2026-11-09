return {
  { -- Highlight, edit, and navigate code
    'nvim-treesitter/nvim-treesitter',
    build = ':TSUpdate',
    -- [[ Configure Treesitter ]] See `:help nvim-treesitter`
    opts = {
      ensure_installed = { 'bash', 'c', 'diff', 'html', 'lua', 'luadoc', 'markdown', 'markdown_inline', 'query', 'vim', 'vimdoc' },
      -- Autoinstall languages that are not installed
      auto_install = true,
      highlight = {
        enable = true,
        -- Some languages depend on vim's regex highlighting system (such as Ruby) for indent rules.
        --  If you are experiencing weird indenting issues, add the language to
        --  the list of additional_vim_regex_highlighting and disabled languages for indent.
        additional_vim_regex_highlighting = { 'ruby' },
      },
      indent = { enable = true, disable = { 'ruby' } },
    },
    config = function(_, opts)
      -- The frozen `master` branch registers its query handlers with `all = false`,
      -- which Nvim 0.12 ignores: captures always arrive as TSNode[], so handlers like
      -- `set-lang-from-info-string!` crash on any fenced code block. Re-register them
      -- with each capture narrowed to its last node, which is what `all = false` did.
      -- Delete this when moving to nvim-treesitter's `main` branch.
      local query = vim.treesitter.query
      local add_directive, add_predicate = query.add_directive, query.add_predicate
      local function with_single_nodes(add)
        return function(name, handler, add_opts)
          add(name, function(match, ...)
            local single = setmetatable({}, {
              __index = function(_, id)
                local nodes = match[id]
                return type(nodes) == 'table' and nodes[#nodes] or nodes
              end,
            })
            return handler(single, ...)
          end, add_opts)
        end
      end
      query.add_directive, query.add_predicate = with_single_nodes(add_directive), with_single_nodes(add_predicate)
      package.loaded['nvim-treesitter.query_predicates'] = nil
      require 'nvim-treesitter.query_predicates'
      query.add_directive, query.add_predicate = add_directive, add_predicate

      require('nvim-treesitter.configs').setup(opts)
    end,
    -- There are additional nvim-treesitter modules that you can use to interact
    -- with nvim-treesitter. You should go explore a few and see what interests you:
    --
    --    - Incremental selection: Included, see `:help nvim-treesitter-incremental-selection-mod`
    --    - Show your current context: https://github.com/nvim-treesitter/nvim-treesitter-context
    --    - Treesitter + textobjects: https://github.com/nvim-treesitter/nvim-treesitter-textobjects
  },
}
