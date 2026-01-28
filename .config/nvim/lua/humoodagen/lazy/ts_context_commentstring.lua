return {
  {
    "JoosepAlviste/nvim-ts-context-commentstring",
    event = "VeryLazy",
    config = function()
      -- Disable the deprecated module (if you haven’t already done this somewhere else)
      vim.g.skip_ts_context_commentstring_module = true

      require("ts_context_commentstring").setup {
        config = {
          javascript = {
            __default = "// %s",
            jsx_element = "{/* %s */}",
            jsx_fragment = "{/* %s */}",
            jsx_attribute = "// %s",
            comment = "// %s",
          },
          typescript = {
            __default = "// %s",
            __multiline = "/* %s */",
          },
          tsx = {
            __default = "// %s",
            __multiline = "/* %s */",
          },
        },
      }
    end,
  },
}
