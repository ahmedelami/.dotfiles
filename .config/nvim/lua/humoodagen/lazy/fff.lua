return {
    "dmtrKovalenko/fff.nvim",
    lazy = false,
    build = function()
        require("fff.download").download_or_build_binary()
    end,
    opts = {
        lazy_sync = true,
        preview = {
            enabled = false,
        },
        keymaps = {
            move_up = { "<Up>", "<C-p>" },
            move_down = { "<Down>", "<C-n>" },
        },
    },
    config = function(_, opts)
        require("fff").setup(opts)

        local integration = require("humoodagen.fff_integration")

        vim.keymap.set("n", "<leader>pv", integration.find_files_cwd, { desc = "Find files (cwd)" })
        vim.keymap.set("n", "<leader>pf", integration.find_files_cwd, { desc = "Find files (cwd)" })
        vim.keymap.set("n", "<C-p>", integration.git_files_or_files_cwd, { desc = "Git files (or cwd files)" })
        vim.keymap.set("n", "<leader>ps", integration.live_grep_cwd, { desc = "Live grep (cwd)" })
        vim.keymap.set("n", "<C-j>", integration.live_grep_cwd, { desc = "Live grep (cwd)" })
        vim.keymap.set({ "v", "x" }, "<C-j>", integration.live_grep_visual_cwd, {
            desc = "Live grep selection (cwd)",
        })

        vim.keymap.set("n", "<M-k>", integration.find_files_cwd, { desc = "Find files (cwd)" })
        vim.keymap.set("n", "<C-k>", integration.find_files_cwd, { desc = "Find/create files (cwd)" })
        vim.keymap.set({ "v", "x" }, "<C-k>", integration.find_files_visual_cwd, {
            desc = "Find/create files (cwd)",
        })

        vim.keymap.set("n", "<C-g>", integration.ctrl_g, { desc = "Git changes / review" })
        vim.keymap.set("t", "<C-g>", integration.ctrl_g_from_terminal, { desc = "Git changes / review" })
        vim.keymap.set("i", "<C-g>", integration.ctrl_g_from_insert, { desc = "Git changes / review" })
    end,
}
