return {
  "OXY2DEV/markview.nvim",
  lazy = false,
  priority = 900,
  dependencies = { "nvim-treesitter/nvim-treesitter" },
  config = function()
    require("markview").setup({
      preview = {
        modes = { "n", "no", "i" },
        hybrid_modes = { "n", "i" },
        linewise_hybrid_mode = true,
      },
      markdown = {
        list_items = {
          marker_minus = { text = "•", hl = "Normal" },
          marker_plus = { text = "•", hl = "Normal" },
          marker_star = { text = "•", hl = "Normal" },
        },
        metadata_minus = { enable = false },
        metadata_plus = { enable = false },
      },
    })

    local function plain_markview_highlights()
      local ok, groups = pcall(vim.fn.getcompletion, "Markview", "highlight")
      if not ok or type(groups) ~= "table" then
        return
      end

      for _, group in ipairs(groups) do
        if type(group) == "string" and group:match("^Markview") then
          vim.api.nvim_set_hl(0, group, { link = "Normal" })
        end
      end
    end

    local augroup = vim.api.nvim_create_augroup("HumoodagenMarkviewPlain", { clear = true })
    vim.api.nvim_create_autocmd({ "VimEnter", "ColorScheme" }, {
      group = augroup,
      callback = function()
        vim.schedule(plain_markview_highlights)
      end,
    })
  end,
}
