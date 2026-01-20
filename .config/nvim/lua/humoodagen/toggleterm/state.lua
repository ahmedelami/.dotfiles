local M = {}

function M.new()
  local term_module = require("toggleterm.terminal")
  local ui = require("toggleterm.ui")

  return {
    term_module = term_module,
    ui = ui,
    Terminal = term_module.Terminal,
    debug = require("humoodagen.debug"),
    term_sets = {
      horizontal = { terms = {}, current = 1 },
      vertical = { terms = {}, current = 1 },
    },
    base_laststatus = vim.o.laststatus,
    base_statusline = vim.go.statusline,
    pending_term_exit = {},
    last_main_win = nil,
    float_term = nil,
    border_char = (vim.opt.fillchars:get() or {}).horiz or "─",
    border_cache = {},
  }
end

return M
