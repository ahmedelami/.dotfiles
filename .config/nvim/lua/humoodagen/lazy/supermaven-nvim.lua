-- lua/plugins/supermaven.lua
return {
  "supermaven-inc/supermaven-nvim",
  event = "InsertEnter",         -- or: lazy = false
  cmd = { "SupermavenStart","SupermavenStop","SupermavenRestart","SupermavenToggle",
          "SupermavenStatus","SupermavenUseFree","SupermavenUsePro",
          "SupermavenLogout","SupermavenShowLog","SupermavenClearLog" },
  config = function()
    require("supermaven-nvim").setup({
      disable_inline_completion = true,
      ignore_filetypes = { "bigfile", "snacks_input", "snacks_notif" },
    })
  end,
}

