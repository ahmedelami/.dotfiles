return {
  "folke/flash.nvim",
  event = "VeryLazy",
  ---@type Flash.Config
  opts = {
    -- Label configuration
    labels = "asdfghjklqwertyuiopzxcvbnm",

    -- Search settings
    search = {
      multi_window = true,
      forward = true,
      wrap = true,
      mode = "exact",
      incremental = false,
      exclude = {
        "notify",
        "cmp_menu",
        "noice",
        "flash_prompt",
        function(win)
          -- Exclude non-focusable windows
          return not vim.api.nvim_win_get_config(win).focusable
        end,
      },
      trigger = "",
      max_length = false, -- Set to a number for maximum pattern length or false
    },

    -- Jump settings
    jump = {
      jumplist = true,
      pos = "start", -- Options: "start" | "end" | "range"
      history = false,
      register = false,
      nohlsearch = false,
      autojump = false,
      inclusive = nil, -- true, false, or nil
      offset = nil,     -- Number or nil
    },

    -- Label appearance and behavior
    label = {
      uppercase = true,
      exclude = "",
      current = true,
      after = true,
      before = false,
      style = "overlay", -- Options: "eol" | "overlay" | "right_align" | "inline"
      reuse = "lowercase", -- Options: "lowercase" | "all" | "none"
      distance = true,
      min_pattern_length = 0,
      rainbow = {
        enabled = false,
        shade = 5, -- Number between 1 and 9
      },
      format = function(opts)
        return { { opts.match.label, opts.hl_group } }
      end,
    },

    -- Highlighting settings
    highlight = {
      backdrop = true,
      matches = true,
      priority = 5000,
      groups = {
        match = "FlashMatch",
        current = "FlashCurrent",
        backdrop = "FlashBackdrop",
        label = "FlashLabel",
      },
    },

    -- Action to perform on label selection
    action = nil,

    -- Initial pattern
    pattern = "",

    -- Continue last search
    continue = false,

    -- Dynamic configuration function
    config = nil,

    -- Mode-specific configurations
    modes = {
      -- Configuration for regular search (`/` or `?`)
      search = {
        enabled = true,
        highlight = { backdrop = false },
        jump = { history = true, register = true, nohlsearch = true },
        search = {
          -- Keep `/` scoped to the active pane/window (no labels in other splits).
          multi_window = false,
        },
      },

      -- Configuration for character-based motions (`f`, `F`, `t`, `T`, `;`, `,`)
      char = {
        enabled = false,
        config = function(opts)
          -- Autohide Flash in operator-pending mode when yanking
          opts.autohide = opts.autohide or (vim.fn.mode(true):find("no") and vim.v.operator == "y")

          -- Disable jump labels under certain conditions
          opts.jump_labels = opts.jump_labels
          and vim.v.count == 0
          and vim.fn.reg_executing() == ""
          and vim.fn.reg_recording() == ""
        end,
        autohide = false,
        jump_labels = false,
        multi_line = true,
        label = { exclude = "hjkliardc" },
        keys = { "f", "F", "t", "T", ";", "," },
        char_actions = function(motion)
          return {
            [";"] = "next", -- Change to "right" to always go right
            [","] = "prev", -- Change to "left" to always go left
            [motion:lower()] = "next",
            [motion:upper()] = "prev",
          }
        end,
        search = { wrap = false },
        highlight = { backdrop = true },
        jump = {
          register = false,
          autojump = false,
        },
      },

      -- Configuration for Treesitter selections
      treesitter = {
        labels = "abcdefghijklmnopqrstuvwxyz",
        jump = { pos = "range", autojump = true },
        search = { incremental = false },
        label = { before = true, after = true, style = "inline" },
        highlight = {
          backdrop = false,
          matches = false,
        },
      },

      -- Configuration for Treesitter search
      treesitter_search = {
        jump = { pos = "range" },
        search = { multi_window = true, wrap = true, incremental = false },
        remote_op = { restore = true },
        label = { before = true, after = true, style = "inline" },
      },

      -- Configuration for remote flash
      remote = {
        remote_op = { restore = true, motion = true },
      },
    },

    -- Prompt window settings
    prompt = {
      enabled = true,
      prefix = { { "⚡", "FlashPromptIcon" } },
      win_config = {
        relative = "editor",
        width = 1,  -- Percentage of editor width when <=1
        height = 1, -- Percentage of editor height when <=1
        row = -1,   -- Offset from the bottom when negative
        col = 0,    -- Offset from the left
        zindex = 1000,
      },
    },

    -- Remote operator pending mode settings
    remote_op = {
      restore = false,
      motion = false, -- true to always enter new motion, false to use window's cursor position
    },
  },

  -- Key bindings
  -- stylua: ignore
  keys = {
    { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash" },
    { "S", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "Flash Treesitter" },
    { "r", mode = "o", function() require("flash").remote() end, desc = "Remote Flash" },
    { "R", mode = { "o", "x" }, function() require("flash").treesitter_search() end, desc = "Treesitter Search" },
    { "<c-s>", mode = { "c" }, function() require("flash").toggle() end, desc = "Toggle Flash Search" },
  },
}
