return {
    {
        "numToStr/Comment.nvim",
        dependencies = {
            "JoosepAlviste/nvim-ts-context-commentstring",  -- ensure it’s installed
        },
        opts = {
            pre_hook = function(ctx)
                -- Defer the require call so that it happens at usage time
                local ts_comment = require("ts_context_commentstring.integrations.comment_nvim")
                return ts_comment.create_pre_hook()(ctx)
            end,
            -- Other Comment.nvim options...
        },
    },
}

