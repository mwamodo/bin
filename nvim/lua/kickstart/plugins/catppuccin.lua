return {
  {
    'catppuccin/nvim',
    name = 'catppuccin',
    priority = 1000,
    config = function()
      require('catppuccin').setup {
        -- Follow `background`: latte when light, mocha when dark
        flavour = 'auto',
        background = {
          light = 'latte',
          dark = 'mocha',
        },
      }

      -- AppleInterfaceStyle is 'Dark' in dark mode and unset (non-zero exit) in light mode
      local function system_background()
        local appearance = vim.fn.system('defaults read -g AppleInterfaceStyle 2>/dev/null'):gsub('%s+', '')
        return appearance == 'Dark' and 'dark' or 'light'
      end

      -- Setting `background` reloads the colorscheme, which picks the matching flavour
      local function sync_background()
        local background = system_background()
        if vim.o.background ~= background then
          vim.o.background = background
        end
      end

      vim.o.background = system_background()
      vim.cmd.colorscheme 'catppuccin'

      -- Pick up system appearance changes while nvim is open
      vim.api.nvim_create_autocmd('FocusGained', {
        group = vim.api.nvim_create_augroup('system-appearance', { clear = true }),
        callback = sync_background,
      })
    end,
  },
}
