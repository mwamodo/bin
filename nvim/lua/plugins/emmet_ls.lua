return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      -- @type lspconfig.options
      servers = {
        emmet_ls = {
          filetypes = {
            "blade",
            "css",
            "html",
            "htmldjango",
          },
        },
      },
    },
  },
}
