return {
    {
        "Mofiqul/vscode.nvim",
        priority = 1000,
        config = function()
            local vscode_theme = require("humoodagen.vscode_theme")
            local theme = vscode_theme.refresh()

            vim.o.background = "light"

            require("vscode").setup({
                style = "light",
                transparent = false,
                disable_nvimtree_bg = true,
                color_overrides = vscode_theme.color_overrides(theme),
            })

            vim.cmd.colorscheme("vscode")
            vscode_theme.setup()
            vscode_theme.apply(theme)
        end,
    },
}
