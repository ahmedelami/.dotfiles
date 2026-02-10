local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
    spec = "humoodagen.lazy",
    change_detection = { notify = false },
    performance = {
      cache = {
        enabled = true,
      },
      reset_packpath = true,
      rtp = {
        reset = true,
        disabled_plugins = (function()
	          local disabled = {
	          "gzip",
	          "matchit",
	          "matchparen",
	          "tarPlugin",
	          "tohtml",
	          "tutor",
	          "zipPlugin",
	          }

          return disabled
        end)(),
      },
    },
})
