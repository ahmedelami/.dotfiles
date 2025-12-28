return {
    "stevearc/oil.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    cmd = "Oil",
    keys = {
        {
            "-",
            function()
                require("oil").open()
            end,
            desc = "Oil: open parent directory",
        },
        {
            "<leader>o",
            function()
                require("oil").open(vim.fn.getcwd())
            end,
            desc = "Oil: open cwd",
        },
    },
    opts = {
        columns = { "icon" },
        view_options = {
            show_hidden = true,
        },
        use_default_keymaps = true,
        skip_confirm_for_simple_edits = true,
    },
}
