return {
  'mawkler/modicator.nvim',
  dependencies = 'catppuccin/nvim', -- Colorscheme dependency
  init = function()
    -- These are required for Modicator to work
    vim.o.cursorline = true
    vim.o.number = true
    vim.o.termguicolors = true
  end,
  opts = {
    show_warnings = false,
  }
}
