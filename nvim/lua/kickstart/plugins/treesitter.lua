return {
  { -- Highlight, edit, and navigate code
    'nvim-treesitter/nvim-treesitter',
    branch = 'main',
    lazy = false, -- nvim-treesitter does not support lazy-loading
    build = ':TSUpdate',
    -- [[ Configure Treesitter ]] See `:help nvim-treesitter`
    config = function()
      local ts = require 'nvim-treesitter'

      ts.install {
        'bash',
        'blade',
        'c',
        'css',
        'diff',
        'html',
        'javascript',
        'json',
        'lua',
        'luadoc',
        'markdown',
        'markdown_inline',
        'php',
        'php_only',
        'phpdoc',
        'query',
        'sql',
        'toml',
        'tsx',
        'typescript',
        'vim',
        'vimdoc',
        'yaml',
      }

      local function attach(buf, lang)
        if not vim.api.nvim_buf_is_valid(buf) or not pcall(vim.treesitter.start, buf, lang) then
          return
        end
        if lang == 'ruby' then
          vim.bo[buf].syntax = 'ON' -- Ruby's indent rules depend on regex highlighting
        elseif vim.treesitter.query.get(lang, 'indents') then
          vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end
      end

      vim.api.nvim_create_autocmd('FileType', {
        group = vim.api.nvim_create_augroup('kickstart-treesitter', { clear = true }),
        callback = function(args)
          local buf = args.buf
          local lang = vim.treesitter.language.get_lang(args.match) or args.match
          if vim.treesitter.language.add(lang) then
            attach(buf, lang)
          elseif vim.list_contains(ts.get_available(), lang) then
            ts.install(lang):await(vim.schedule_wrap(function(err)
              if not err then
                attach(buf, lang)
              end
            end))
          end
        end,
      })
    end,
  },
}
