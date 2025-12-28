return {
  "folke/noice.nvim",
  event = "VeryLazy",
  dependencies = {
    "MunifTanjim/nui.nvim",
    "rcarriga/nvim-notify",
  },
  config = function()
    require("notify").setup({
      background_colour = "#000000", -- Use a default black background for notifications
      timeout = 3000,
    })

    require("noice").setup({
      lsp = {
        -- override markdown rendering so that **cmp** and other plugins use **Treesitter**
        override = {
          ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
          ["vim.lsp.util.stylize_markdown"] = true,
          ["cmp.entry.get_documentation"] = true,
        },
      },
      -- you can enable a preset for easier configuration
      presets = {
        bottom_search = true,         -- use a classic bottom cmdline for search
        command_palette = true,       -- position the cmdline and popupmenu together
        long_message_to_split = true, -- long messages will be sent to a split
        inc_rename = false,           -- enables an input dialog for inc-rename.nvim
        lsp_doc_border = true,        -- add a border to hover docs and signature help
      },
      routes = {
        {
          filter = {
            event = "msg_show",
            any = {
              { find = "%d+L, %d+B" },
              { find = "; after #%d+" },
              { find = "; before #%d+" },
            },
          },
          view = "mini",
        },
      },
    })

    -- Keybindings
    vim.keymap.set("n", "<leader>nl", function()
      require("noice").cmd("last")
    end, { desc = "Noice Last Message" })

    vim.keymap.set("n", "<leader>nh", function()
      require("noice").cmd("history")
    end, { desc = "Noice History" })

    vim.keymap.set("n", "<leader>nd", function()
      require("notify").dismiss({ silent = true, pending = true })
    end, { desc = "Dismiss All Notifications" })

    vim.keymap.set({ "n", "i", "s" }, "<c-f>", function()
      if not require("noice.util").scroll(4) then
        return "<c-f>"
      end
    end, { silent = true, expr = true, desc = "Scroll Forward" })

    vim.keymap.set({ "n", "i", "s" }, "<c-b>", function()
      if not require("noice.util").scroll(-4) then
        return "<c-b>"
      end
    end, { silent = true, expr = true, desc = "Scroll Backward" })
  end,
}
