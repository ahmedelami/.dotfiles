local M = {}

function M.setup()
  require("toggleterm").setup({
    start_in_insert = true,
    persist_size = true,
    shade_terminals = false,
    direction = "horizontal",
    env = {
      DISABLE_TMUX_AUTO = "1",
      HUMOODAGEN_NVIM_TOGGLETERM = "1",
      HUMOODAGEN_NVIM_WRAPPER = vim.fn.stdpath("config") .. "/bin/nvim",
      HUMOODAGEN_ZDOTDIR_ORIG = vim.env.ZDOTDIR or (vim.env.HOME or ""),
      HUMOODAGEN_REAL_NVIM = vim.v.progpath,
      HISTFILE = (vim.env.ZDOTDIR or (vim.env.HOME or "")) .. "/.zsh_history",
      NVIM = vim.v.servername,
      PATH = vim.fn.stdpath("config") .. "/bin:" .. (vim.env.PATH or ""),
      ZDOTDIR = vim.fn.stdpath("config") .. "/.toggleterm-zdotdir",
      ZSH_SESSION_DIR = vim.fn.stdpath("state") .. "/humoodagen/zsh_sessions",
    },
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
