return {
    "rktjmp/fwatch.nvim",
    event = { "BufReadPost", "BufNewFile", "BufWritePost" },
    config = function()
        require("humoodagen.fwatch")
    end,
}
