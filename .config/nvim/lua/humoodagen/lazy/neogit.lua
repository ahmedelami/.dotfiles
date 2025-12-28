return {
  "NeogitOrg/neogit",
  dependencies = {
    "nvim-lua/plenary.nvim",         -- required
    "sindrets/diffview.nvim",        -- optional - Diff integration
    "nvim-telescope/telescope.nvim", -- optional
  },
  config = function()
    local neogit = require("neogit")

    neogit.setup({
      -- Hides the help hints until you press '?'
      disable_hint = false,
      -- Adds a column with signs of checked/unstaged/staged files
      disable_context_highlighting = false,
      disable_signs = false,
      -- Show the status in a floating window
      kind = "tab", 
      -- Use telescope for choosing things
      integrations = {
        telescope = true,
        diffview = true,
      },
      -- Customizing signs
      signs = {
        -- { CLOSED, OPENED }
        hunk = { "", "" },
        item = { "", "" },
        section = { "", "" },
      },
    })

    vim.keymap.set("n", "<leader>gs", neogit.open, { desc = "Neogit Status" })
  end,
}
