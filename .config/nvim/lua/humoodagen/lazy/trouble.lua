return {
    {
        "folke/trouble.nvim",
        keys = {
            { "<leader>tt", function() require("trouble").toggle() end, desc = "Trouble Toggle" },
            { "[t", function() require("trouble").next({ skip_groups = true, jump = true }) end, desc = "Trouble Next" },
            { "]t", function() require("trouble").previous({ skip_groups = true, jump = true }) end, desc = "Trouble Prev" },
        },
        config = function()
            require("trouble").setup({
                icons = false,
            })
        end
    },
}
