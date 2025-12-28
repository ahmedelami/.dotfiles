return {
  {
    "Mofiqul/vscode.nvim",
    name = "vscode",
    priority = 1000,
    config = function()
      require("vscode").setup({
        style = 'light',
        transparent = true,
        italic_comments = true,
        underline_links = true,
        disable_nvimtree_bg = true,
        color_overrides = {
          -- Ensure the background stays transparent for the whole UI
          bg = "NONE",
        },
        group_overrides = {
          -- Fix the 'style' error by using 'bold = true'
          -- And ensure the tree stays high-contrast blue/black
          NvimTreeFolderName = { fg = "#005eff", bold = true },
          NvimTreeOpenedFolderName = { fg = "#005eff", bold = true },
          NvimTreeEmptyFolderName = { fg = "#005eff", bold = true },
          NvimTreeFolderIcon = { fg = "#005eff", bold = true },
          NvimTreeFolderArrowOpen = { fg = "#005eff", bold = true },
          NvimTreeFolderArrowClosed = { fg = "#005eff", bold = true },
          
          -- Ensure NvimTree normal state is also transparent/neutral
          NvimTreeNormal = { bg = "NONE" },
          NvimTreeNormalNC = { bg = "NONE" },
          NvimTreeWinSeparator = { fg = "#dbdbdb", bg = "NONE" },

          -- GitSigns overrides
          GitSignsAdd = { fg = "#1a7f37" }, -- Solid Green
          GitSignsChange = { fg = "#9a6700" }, -- Solid Orange/Yellow
          GitSignsDelete = { fg = "#cf222e" }, -- Solid Red
          GitSignsTopdelete = { fg = "#cf222e" }, -- Solid Red
          GitSignsChangedelete = { fg = "#cf222e" }, -- Solid Red
        }
      })
      vim.cmd.colorscheme("vscode")
    end,
  },
}
