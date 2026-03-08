return {
    {
        "Mofiqul/vscode.nvim",
        priority = 1000,
        config = function()
            vim.o.background = "light"

            require("vscode").setup({
                style = "light",
                transparent = false,
                disable_nvimtree_bg = true,
                color_overrides = {
                    vscFront = "#000000",
                },
            })

            vim.cmd.colorscheme("vscode")
        end,
    },
}
