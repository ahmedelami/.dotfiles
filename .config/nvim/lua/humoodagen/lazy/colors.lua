-- Define a helper to adjust background highlights (optional)
local function ColorMyPencils()
  vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
  vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
end

return {
  {
    "rose-pine/neovim",
    name = "rose-pine",
    lazy = false,         -- Ensure the plugin loads immediately
    priority = 1000,      -- Load early to ensure proper colorscheme setup
    opts = {
      variant = "main",         -- Use the "main" variant
      dark_variant = "moon",    -- Use "moon" for dark mode
      disable_background = false, -- Set to false if you want a solid background
      enable = {
        terminal = true,         -- Enable terminal colors
      },
      -- You can add further customization here if needed
    },
    config = function(_, opts)
      -- Set up the theme before applying the colorscheme
      require("rose-pine").setup(opts)
      -- Load the colorscheme explicitly
      vim.cmd("colorscheme rose-pine")
      -- Optionally adjust highlights after setting the colorscheme
      ColorMyPencils()
    end,
  },
}

