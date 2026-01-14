return {
  "OXY2DEV/markview.nvim",
  lazy = false,
  priority = 900,
  config = function()
    require("markview").setup({
      preview = {
        enable = true,
        enable_hybrid_mode = true,
        filetypes = { "markdown" },
        modes = { "n", "no", "i", "c" },
        hybrid_modes = { "i" },
        linewise_hybrid_mode = true,
      },
    })
  end,
}

