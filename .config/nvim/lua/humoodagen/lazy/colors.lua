return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    lazy = false,
    config = function()
      vim.o.background = "light"

      require("catppuccin").setup({
        flavour = "latte",
        transparent_background = true,
        custom_highlights = function(_)
          return {
            NvimTreeFolderName = { fg = "#005eff", bold = true },
            NvimTreeOpenedFolderName = { fg = "#005eff", bold = true },
            NvimTreeEmptyFolderName = { fg = "#005eff", bold = true },
            NvimTreeFolderIcon = { fg = "#005eff", bold = true },
            NvimTreeFolderArrowOpen = { fg = "#005eff", bold = true },
            NvimTreeFolderArrowClosed = { fg = "#005eff", bold = true },

            NvimTreeNormal = { bg = "NONE" },
            NvimTreeNormalNC = { bg = "NONE" },
            NvimTreeWinSeparator = { fg = "#dbdbdb", bg = "NONE" },
            WinSeparator = { fg = "#dbdbdb", bg = "NONE" },
            VertSplit = { fg = "#dbdbdb", bg = "NONE" },

            CursorNormal = { fg = "#ffffff", bg = "#f28c28" },
            CursorInsert = { fg = "#ffffff", bg = "#000000" },
            CursorVisual = { fg = "#ffffff", bg = "#7a4cff" },
            CursorReplace = { fg = "#ffffff", bg = "#cf222e" },

            GitSignsAdd = { fg = "#1a7f37" },
            GitSignsChange = { fg = "#cf222e" },
            GitSignsDelete = { fg = "#cf222e" },
            GitSignsTopdelete = { fg = "#cf222e" },
            GitSignsChangedelete = { fg = "#cf222e" },
          }
        end,
      })

      vim.cmd.colorscheme("catppuccin")
    end,
  },
}
