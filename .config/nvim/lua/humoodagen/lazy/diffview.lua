return {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewFileHistory" },
    config = function()
        local diffview_review = require("humoodagen.diffview_review")

        require("diffview").setup({
            enhanced_diff_hl = true,
            view = {
                merge_tool = { layout = "diff3_mixed" },
            },
            keymaps = {
                file_panel = {
                    { "n", "<cr>", diffview_review.open_selected_entry_in_review, { desc = "Open current file with unified diff review" } },
                    { "n", "o", diffview_review.open_selected_entry_in_review, { desc = "Open current file with unified diff review" } },
                    { "n", "l", diffview_review.open_selected_entry_in_review, { desc = "Open current file with unified diff review" } },
                    { "n", "<2-LeftMouse>", diffview_review.open_selected_entry_in_review, { desc = "Open current file with unified diff review" } },
                },
            },
        })
    end
}
