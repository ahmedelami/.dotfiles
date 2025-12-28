return {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewFileHistory" },
    config = function()
        local actions = require("diffview.actions")

        require("diffview").setup({
            enhanced_diff_hl = true,
            view = {
                merge_tool = { layout = "diff3_mixed" },
            },
            file_panel = {
                listing_style = "list", -- Clean list of changed files
                win_config = {
                    width = 35,
                },
            },
            -- This setting hides the unchanged parts of the file (hunk-only view)
            hooks = {
                diff_buf_read = function(bufnr)
                    vim.opt_local.foldmethod = "diff"
                    vim.opt_local.foldlevel = 0 -- Fold everything that hasn't changed
                end,
            },
            keymaps = {
                view = {
                    -- CTRL + J to jump to the actual file in the main editor
                    { "n", "<C-j>", actions.goto_file_edit, { desc = "Jump to file" } },
                },
                file_panel = {
                    { "n", "<C-j>", actions.goto_file_edit, { desc = "Jump to file" } },
                },
            },
        })

        -- Setup Toggle Function
        local function toggle_diffview()
            local lib = require("diffview.lib")
            local view = lib.get_current_view()
            if view then
                vim.cmd("DiffviewClose")
            else
                vim.cmd("DiffviewOpen")
            end
        end

        vim.keymap.set("n", "<C-g>", toggle_diffview, { desc = "Toggle Git Diff View" })
    end
}
