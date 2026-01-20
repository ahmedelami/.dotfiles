local M = {}

function M.setup()
  require("toggleterm").setup({
    start_in_insert = true,
    persist_size = true,
    shade_terminals = false,
    direction = "horizontal",
    env = { DISABLE_TMUX_AUTO = "1", HUMOODAGEN_NVIM_TOGGLETERM = "1" },
    size = function(term)
      if term.direction == "horizontal" then
        return 15
      end
      if term.direction == "vertical" then
        return math.floor(vim.o.columns * 0.3)
      end
      return 15
    end,
  })

  local state = require("humoodagen.toggleterm.state").new()
  local mode = require("humoodagen.toggleterm.mode")
  local termset = require("humoodagen.toggleterm.termset")
  local statusline = require("humoodagen.toggleterm.statusline")
  local panes = require("humoodagen.toggleterm.panes")

  mode.setup(state)
  statusline.setup(state, termset)
  panes.setup(state, mode, termset)
end

return M
