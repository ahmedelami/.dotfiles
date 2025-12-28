return {
    "windwp/nvim-ts-autotag",
    event = "InsertEnter",
    config = function()
        require("nvim-ts-autotag").setup({
            close = {
                enabled = true,
                on_slash = false,
            },
            rename= {
                enabled = true,
            },
        })
    end,
}
