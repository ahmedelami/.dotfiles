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
        color_overrides = {
          latte = {
            base = "#ffffff",
            mantle = "#ffffff",
            crust = "#ffffff",

            text = "#000000",
            subtext1 = "#000000",
            subtext0 = "#000000",
            overlay2 = "#000000",
            overlay1 = "#000000",
            overlay0 = "#000000",
          },
        },
        integrations = {
          nvimtree = true,
        },
        custom_highlights = function(_)
          return {
            Visual = { bg = "#dbdde3", bold = true },
            VisualNOS = { bg = "#dbdde3", bold = true },

            CursorNormal = { fg = "#ffffff", bg = "#f28c28" },
            CursorInsert = { fg = "#ffffff", bg = "#000000" },
            CursorVisual = { fg = "#ffffff", bg = "#7a4cff" },
            CursorReplace = { fg = "#ffffff", bg = "#cf222e" },

            HumoodagenModeCursorNormal = { fg = "#ffffff", bg = "#f28c28" },
            HumoodagenModeCursorInsert = { fg = "#ffffff", bg = "#000000" },
            HumoodagenModeCursorVisual = { fg = "#ffffff", bg = "#7a4cff" },
            HumoodagenModeCursorReplace = { fg = "#ffffff", bg = "#cf222e" },

            -- Keep GitSigns line-number "change" (orange) from distracting:
            -- show adds/deletes, but make modifications look like normal lines.
            GitSignsChangeNr = { link = "LineNr" },
            GitSignsChangedeleteNr = { link = "GitSignsDeleteNr" },

            -- Legacy cursor highlights (kept for compatibility)
            HumoodagenCursorLineNormal = { fg = "#f28c28", bg = "#f28c28" },
            HumoodagenCursorLineInsert = { fg = "#000000", bg = "#000000" },
            HumoodagenCursorLineVisual = { fg = "#7a4cff", bg = "#7a4cff" },
            HumoodagenCursorLineReplace = { fg = "#cf222e", bg = "#cf222e" },
          }
        end,
      })

      vim.cmd.colorscheme("catppuccin")

      -- Comments are the one place where dim grey is still useful. Keep them grey
      -- only in real file buffers so UI text that links to `Comment` stays black.
      local comment_ns = vim.api.nvim_create_namespace("HumoodagenFileComments")
      local function set_file_comment_highlights()
        local comment = { fg = "#6c6f85", italic = true }
        vim.api.nvim_set_hl(comment_ns, "Comment", comment)
        vim.api.nvim_set_hl(comment_ns, "@comment", comment)
        vim.api.nvim_set_hl(comment_ns, "@comment.documentation", comment)
        vim.api.nvim_set_hl(comment_ns, "@lsp.type.comment", comment)
        vim.api.nvim_set_hl(comment_ns, "TSComment", { link = "Comment" })
      end

      local function is_file_buf(buf)
        if not (buf and vim.api.nvim_buf_is_valid(buf)) then
          return false
        end

        if vim.bo[buf].buftype ~= "" then
          return false
        end

        local ft = vim.bo[buf].filetype
        if ft == "NvimTree" or ft == "toggleterm" then
          return false
        end

        return true
      end

      local function refresh_comment_namespace(win)
        if not (win and vim.api.nvim_win_is_valid(win)) then
          return
        end

        local buf = vim.api.nvim_win_get_buf(win)
        if is_file_buf(buf) then
          vim.api.nvim_win_set_hl_ns(win, comment_ns)
          pcall(vim.api.nvim_win_set_var, win, "humoodagen_comment_ns", true)
          return
        end

        local ok, active = pcall(vim.api.nvim_win_get_var, win, "humoodagen_comment_ns")
        if ok and active then
          vim.api.nvim_win_set_hl_ns(win, 0)
          pcall(vim.api.nvim_win_del_var, win, "humoodagen_comment_ns")
        end
      end

      set_file_comment_highlights()
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        refresh_comment_namespace(win)
      end

      local comment_group = vim.api.nvim_create_augroup("HumoodagenFileCommentHighlights", { clear = true })
      vim.api.nvim_create_autocmd({ "BufWinEnter", "WinEnter" }, {
        group = comment_group,
        callback = function()
          refresh_comment_namespace(vim.api.nvim_get_current_win())
        end,
      })
      vim.api.nvim_create_autocmd("ColorScheme", {
        group = comment_group,
        callback = function()
          set_file_comment_highlights()
          for _, win in ipairs(vim.api.nvim_list_wins()) do
            refresh_comment_namespace(win)
          end
        end,
      })

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

        -- Column guide should match cursorline grey on white background.
        vim.api.nvim_set_hl(0, "ColorColumn", { bg = "#f2f2f2" })

        -- Make the cursorline (current row highlight) light grey on the white background.
        local cursorline_hl = { bg = "#f2f2f2" }
        vim.api.nvim_set_hl(0, "CursorLine", cursorline_hl)
        vim.api.nvim_set_hl(0, "CursorLineNr", cursorline_hl)
        vim.api.nvim_set_hl(0, "CursorLineSign", cursorline_hl)
        vim.api.nvim_set_hl(0, "CursorLineFold", cursorline_hl)
        vim.api.nvim_set_hl(0, "NvimTreeCursorLine", cursorline_hl)
        vim.api.nvim_set_hl(0, "NvimTreeCursorLineNr", cursorline_hl)

        -- Winbar (filename) should match the cursorline grey styling.
        local winbar_hl = { bg = "#f2f2f2" }
        if normal_fg ~= nil then
          winbar_hl.fg = normal_fg
        end
        vim.api.nvim_set_hl(0, "WinBar", winbar_hl)
        vim.api.nvim_set_hl(0, "WinBarNC", winbar_hl)

        -- nvim-tree root folder header should match winbar styling.
        local tree_root_hl = { bg = "#f2f2f2", bold = true }
        if normal_fg ~= nil then
          tree_root_hl.fg = normal_fg
        end
        vim.api.nvim_set_hl(0, "NvimTreeRootFolder", tree_root_hl)
      end

      fix_nvim_tree_statusline()
      vim.api.nvim_create_autocmd("ColorScheme", {
        group = augroup,
        callback = fix_nvim_tree_statusline,
      })
    end,
  },
}
