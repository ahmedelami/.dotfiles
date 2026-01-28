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
	    base_laststatus = type(vim.g.humoodagen_base_laststatus) == "number" and vim.g.humoodagen_base_laststatus or vim.o.laststatus,
	    base_statusline = vim.go.statusline,
	    pending_term_exit = {},
	    last_main_win = nil,
	    float_term = nil,
    bottom_workspace_main_buf = {},
    bottom_workspace_view = {},
    border_char = (vim.opt.fillchars:get() or {}).horiz or "─",
    border_cache = {},
  }
end

return M
