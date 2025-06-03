-- TODO: maybe use this https://github.com/cpplain/flexoki.nvim instead. Might have better syntax highlighting --
return {
    { 'kepano/flexoki-neovim', name = 'flexoki' },
    {
        'neanias/everforest-nvim',
        priority = 1000,
        config = function()
            -- Function to set the appropriate theme based on system appearance
            local function set_theme()
                local appearance = vim.fn.system('defaults read -g AppleInterfaceStyle'):gsub('%s+', '')
                if appearance == 'Dark' then
                    vim.cmd.colorscheme 'flexoki-dark'
                else
                    vim.cmd.colorscheme 'flexoki-light'
                end
            end

            -- Set initial theme
            set_theme()

            -- Watch for system appearance changes
            vim.api.nvim_create_autocmd('Signal', {
                pattern = 'SIGUSR1',
                callback = set_theme
            })
        end,
    }
}
