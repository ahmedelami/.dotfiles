return {
    "andymass/vim-matchup",
    event = "VeryLazy",
    config = function()
        vim.g.matchup_matchparen_offscreen = { method = "popup" }
    end,
    init = function()
        -- Integrate with treesitter
        vim.g.matchup_matchparen_deferred = 1
        vim.g.matchup_matchparen_hi_surround_always = 1
    end,
}


