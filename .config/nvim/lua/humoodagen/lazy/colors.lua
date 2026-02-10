return {
  {
    "Mofiqul/vscode.nvim",
    priority = 1000,
    lazy = false,
    config = function()
      vim.o.background = "light"

      local vscode = require("vscode")
      vscode.setup({
        -- Match VSCode "Default Dark+" / "Default Light+" depending on `background`.
        style = vim.o.background == "light" and "light" or "dark",
        color_overrides = {
          -- Make file text true black in the light theme.
          vscFront = vim.o.background == "light" and "#000000" or "#D4D4D4",
          -- VSCode default line numbers are gray (not green) in the gutter.
          vscLineNumber = vim.o.background == "light" and "#A0A0A0" or "#5A5A5A",
        },
        transparent = false,
        italic_comments = false,
        disable_nvimtree_bg = true,
      })
      vscode.load()

      -- Command line & messages: keep text readable in the bottom cmdline area.
      local ui_fg = vim.o.background == "light" and "#000000" or "#ffffff"
      local ui_bg = vim.o.background == "light" and "#ffffff" or "#000000"
      vim.api.nvim_set_hl(0, "MsgArea", { fg = ui_fg, bg = ui_bg })
      vim.api.nvim_set_hl(0, "Cmdline", { fg = ui_fg, bg = ui_bg })
      vim.api.nvim_set_hl(0, "ModeMsg", { fg = ui_fg, bg = ui_bg })
      vim.api.nvim_set_hl(0, "MsgSeparator", { fg = ui_fg, bg = ui_bg })

      vim.api.nvim_set_hl(0, "HumoodagenModeCursorNormal", { fg = "#ffffff", bg = "#f28c28" })
      vim.api.nvim_set_hl(0, "HumoodagenModeCursorInsert", { fg = "#ffffff", bg = "#000000" })
      vim.api.nvim_set_hl(0, "HumoodagenModeCursorVisual", { fg = "#ffffff", bg = "#7a4cff" })
      vim.api.nvim_set_hl(0, "HumoodagenModeCursorReplace", { fg = "#ffffff", bg = "#cf222e" })

      -- Keep GitSigns line-number "change" (orange) from distracting:
      -- show adds/deletes, but make modifications look like normal lines.
      vim.api.nvim_set_hl(0, "GitSignsChangeNr", { link = "LineNr" })
      vim.api.nvim_set_hl(0, "GitSignsChangedeleteNr", { link = "GitSignsDeleteNr" })

      -- Terminal prompt palette (match SwiftTerm/UT7 side panel + Ghostty config)
      vim.g.terminal_color_0 = "#000000"
      vim.g.terminal_color_1 = "#c23621"
      vim.g.terminal_color_2 = "#25bc24"
      vim.g.terminal_color_3 = "#adad27"
      vim.g.terminal_color_4 = "#492ee1"
      vim.g.terminal_color_5 = "#d338d3"
      vim.g.terminal_color_6 = "#33bbc8"
      vim.g.terminal_color_7 = "#cbcccd"
      vim.g.terminal_color_8 = "#818383"
      vim.g.terminal_color_9 = "#fc391f"
      vim.g.terminal_color_10 = "#31e722"
      vim.g.terminal_color_11 = "#eaec23"
      vim.g.terminal_color_12 = "#5833ff"
      vim.g.terminal_color_13 = "#f935f8"
      vim.g.terminal_color_14 = "#14f0f0"
      vim.g.terminal_color_15 = "#e9ebeb"

      -- Hide the extra inactive statusline bar under NvimTree.
      local augroup = vim.api.nvim_create_augroup("HumoodagenNvimTreeHighlights", { clear = true })
      local function fix_nvim_tree_statusline()
        local function rgb_parts(color)
          if type(color) ~= "number" then
            return nil, nil, nil
          end
          local r = math.floor(color / 65536) % 256
          local g = math.floor(color / 256) % 256
          local b = color % 256
          return r, g, b
        end

        local function rgb_join(r, g, b)
          r = math.max(0, math.min(255, math.floor(r + 0.5)))
          g = math.max(0, math.min(255, math.floor(g + 0.5)))
          b = math.max(0, math.min(255, math.floor(b + 0.5)))
          return r * 65536 + g * 256 + b
        end

        local function mix(a, b, t)
          local ar, ag, ab = rgb_parts(a)
          local br, bg, bb = rgb_parts(b)
          if not (ar and ag and ab and br and bg and bb) then
            return a
          end
          return rgb_join(
            ar + (br - ar) * t,
            ag + (bg - ag) * t,
            ab + (bb - ab) * t
          )
        end

        local normal_bg = nil
        local normal_fg = nil
        local ok_hl, normal_hl = pcall(vim.api.nvim_get_hl, 0, { name = "Normal" })
        if ok_hl and type(normal_hl) == "table" then
          normal_bg = normal_hl.bg
          normal_fg = normal_hl.fg
        end

        local win_sep_fg = vim.o.background == "light" and "#000000" or "#3c3c3c"
        local sep_hl = { fg = win_sep_fg }
        if normal_bg ~= nil then
          sep_hl.bg = normal_bg
        end
        vim.api.nvim_set_hl(0, "WinSeparator", sep_hl)
        vim.api.nvim_set_hl(0, "VertSplit", sep_hl)

        -- Make NvimTree blend with the main background.
        vim.api.nvim_set_hl(0, "NvimTreeNormal", { link = "Normal" })
        vim.api.nvim_set_hl(0, "NvimTreeNormalNC", { link = "Normal" })
        vim.api.nvim_set_hl(0, "NvimTreeEndOfBuffer", { link = "EndOfBuffer" })
        vim.api.nvim_set_hl(0, "NvimTreeWinSeparator", { link = "WinSeparator" })

        -- Hide the extra statusline bar under NvimTree (active + inactive).
        vim.api.nvim_set_hl(0, "NvimTreeStatusLine", { link = "NvimTreeNormal" })
        vim.api.nvim_set_hl(0, "NvimTreeStatusLineNC", { link = "NvimTreeNormal" })
        vim.api.nvim_set_hl(0, "NvimTreeStatuslineNC", { link = "NvimTreeNormal" })

        -- When ToggleTerm enables per-window statuslines for its tab bars, keep
        -- non-ToggleTerm statuslines completely invisible against the main background.
        if vim.g.humoodagen_profile == "ide_like_exp" then
          vim.api.nvim_set_hl(0, "StatusLine", { link = "Normal" })
          vim.api.nvim_set_hl(0, "StatusLineNC", { link = "Normal" })
        end

        -- Don't dim inactive terminal panes.
        vim.api.nvim_set_hl(0, "TermNormal", { link = "Normal" })
        vim.api.nvim_set_hl(0, "TermNormalNC", { link = "Normal" })
        vim.api.nvim_set_hl(0, "TermCursorNC", { link = "Normal" })

        local cursor_bg = nil
        local ok_cursor, cursor_hl = pcall(vim.api.nvim_get_hl, 0, { name = "CursorLine", link = false })
        if ok_cursor and type(cursor_hl) == "table" then
          cursor_bg = cursor_hl.bg
        end
        if cursor_bg == nil then
          cursor_bg = vim.o.background == "light" and 0xf2f2f2 or 0x2a2d2e
        end
        local base_bg = type(normal_bg) == "number" and normal_bg or (vim.o.background == "light" and 0xffffff or 0x000000)
        cursor_bg = mix(cursor_bg, base_bg, 1 / 3)

        -- Keep cursorline-related backgrounds consistent across panes.
        local cursorline_bg_hl = { bg = cursor_bg }
        vim.api.nvim_set_hl(0, "CursorLine", cursorline_bg_hl)
        local ok_linenr, linenr_hl = pcall(vim.api.nvim_get_hl, 0, { name = "LineNr", link = false })
        local cursorline_nr_hl = { bg = cursor_bg }
        if ok_linenr and type(linenr_hl) == "table" and linenr_hl.fg ~= nil then
          cursorline_nr_hl.fg = linenr_hl.fg
        end
        vim.api.nvim_set_hl(0, "CursorLineNr", cursorline_nr_hl)
        vim.api.nvim_set_hl(0, "LineNrAbove", { link = "LineNr" })
        vim.api.nvim_set_hl(0, "LineNrBelow", { link = "LineNr" })
        vim.api.nvim_set_hl(0, "CursorLineSign", cursorline_bg_hl)
        vim.api.nvim_set_hl(0, "CursorLineFold", cursorline_bg_hl)
        vim.api.nvim_set_hl(0, "NvimTreeCursorLine", cursorline_bg_hl)
        vim.api.nvim_set_hl(0, "NvimTreeCursorLineNr", cursorline_nr_hl)
        vim.api.nvim_set_hl(0, "ColorColumn", cursorline_bg_hl)

        -- Winbar (filename) should match the cursorline styling.
        local winbar_hl = { bg = cursor_bg }
        if normal_fg ~= nil then
          winbar_hl.fg = normal_fg
        end
        winbar_hl.underline = true
        winbar_hl.sp = sep_hl.fg
        vim.api.nvim_set_hl(0, "WinBar", winbar_hl)
        vim.api.nvim_set_hl(0, "WinBarNC", winbar_hl)

        -- nvim-tree root folder header should match winbar styling.
        local tree_root_hl = { bg = cursor_bg, bold = true }
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
