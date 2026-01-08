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
        transparent_background = false,
        integrations = {
          nvimtree = true,
        },
        custom_highlights = function(_)
          return {
            CursorNormal = { fg = "#ffffff", bg = "#f28c28" },
            CursorInsert = { fg = "#ffffff", bg = "#000000" },
            CursorVisual = { fg = "#ffffff", bg = "#7a4cff" },
            CursorReplace = { fg = "#ffffff", bg = "#cf222e" },

            HumoodagenModeCursorNormal = { fg = "#ffffff", bg = "#f28c28" },
            HumoodagenModeCursorInsert = { fg = "#ffffff", bg = "#000000" },
            HumoodagenModeCursorVisual = { fg = "#ffffff", bg = "#7a4cff" },
            HumoodagenModeCursorReplace = { fg = "#ffffff", bg = "#cf222e" },

            -- Legacy cursor highlights (kept for compatibility)
            HumoodagenCursorLineNormal = { fg = "#f28c28", bg = "#f28c28" },
            HumoodagenCursorLineInsert = { fg = "#000000", bg = "#000000" },
            HumoodagenCursorLineVisual = { fg = "#7a4cff", bg = "#7a4cff" },
            HumoodagenCursorLineReplace = { fg = "#cf222e", bg = "#cf222e" },
          }
        end,
      })

      vim.cmd.colorscheme("catppuccin")

      -- Hide the extra inactive statusline bar under NvimTree.
      local augroup = vim.api.nvim_create_augroup("HumoodagenNvimTreeHighlights", { clear = true })
      local function fix_nvim_tree_statusline()
        local normal_bg = nil
        local normal_fg = nil
        local ok_hl, normal_hl = pcall(vim.api.nvim_get_hl, 0, { name = "Normal" })
        if ok_hl and type(normal_hl) == "table" then
          normal_bg = normal_hl.bg
          normal_fg = normal_hl.fg
        end

        -- Make window borders high-contrast (black) on Latte.
        local sep_hl = { fg = "#000000" }
        if normal_bg ~= nil then
          sep_hl.bg = normal_bg
        end
        vim.api.nvim_set_hl(0, "WinSeparator", sep_hl)
        vim.api.nvim_set_hl(0, "VertSplit", sep_hl)

        -- Make NvimTree blend with the main background (Catppuccin Latte).
        vim.api.nvim_set_hl(0, "NvimTreeNormal", { link = "Normal" })
        vim.api.nvim_set_hl(0, "NvimTreeNormalNC", { link = "Normal" })
        vim.api.nvim_set_hl(0, "NvimTreeEndOfBuffer", { link = "EndOfBuffer" })
        vim.api.nvim_set_hl(0, "NvimTreeWinSeparator", { link = "WinSeparator" })

        -- Hide the extra statusline bar under NvimTree (active + inactive).
        vim.api.nvim_set_hl(0, "NvimTreeStatusLine", { link = "NvimTreeNormal" })
        vim.api.nvim_set_hl(0, "NvimTreeStatusLineNC", { link = "NvimTreeNormal" })
        vim.api.nvim_set_hl(0, "NvimTreeStatuslineNC", { link = "NvimTreeNormal" })

        -- When ToggleTerm enables per-window statuslines for its tab bars, keep
        -- non-ToggleTerm statuslines completely invisible against Latte.
        vim.api.nvim_set_hl(0, "StatusLine", { link = "Normal" })
        vim.api.nvim_set_hl(0, "StatusLineNC", { link = "Normal" })

        -- Don't dim inactive terminal panes.
        vim.api.nvim_set_hl(0, "TermNormal", { link = "Normal" })
        vim.api.nvim_set_hl(0, "TermNormalNC", { link = "Normal" })
        vim.api.nvim_set_hl(0, "TermCursorNC", { link = "Normal" })

        -- Experimental: make both guides pure white.
        vim.api.nvim_set_hl(0, "ColorColumn", { bg = "#ffffff" })
        vim.api.nvim_set_hl(0, "CursorLine", { bg = "#ffffff" })

        -- Winbar (filename) should match the "white" guide styling.
        local winbar_hl = { bg = "#ffffff" }
        if normal_fg ~= nil then
          winbar_hl.fg = normal_fg
        end
        vim.api.nvim_set_hl(0, "WinBar", winbar_hl)
        vim.api.nvim_set_hl(0, "WinBarNC", winbar_hl)
      end

      fix_nvim_tree_statusline()
      vim.api.nvim_create_autocmd("ColorScheme", {
        group = augroup,
        callback = fix_nvim_tree_statusline,
      })
    end,
  },
}
