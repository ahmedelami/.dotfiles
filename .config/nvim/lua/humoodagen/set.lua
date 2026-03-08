vim.opt.guicursor = ""

-- Keep the bottom line consistent (statusline/ruler) and avoid mode text like
-- "-- TERMINAL --" stealing space.
vim.opt.showmode = false
vim.opt.cmdheight = 0
vim.opt.laststatus = 3
require("humoodagen.statusline").setup()

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.cursorline = true

vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true

vim.opt.smartindent = true

vim.opt.wrap = true
vim.opt.linebreak = true
vim.opt.breakindent = true

vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.undodir = os.getenv("HOME") .. "/.vim/undodir"
vim.opt.undofile = true

vim.opt.hlsearch = false
vim.opt.incsearch = true

vim.opt.shortmess:append("I")

-- Silence deprecation warnings (stops the tailwind-tools/lspconfig flash)
vim.g.deprecation_warnings = false

vim.opt.termguicolors = true

vim.opt.scrolloff = 8
vim.opt.signcolumn = "yes"
vim.opt.isfname:append("@-@")

vim.opt.updatetime = 50  -- Back to original value

vim.opt.colorcolumn = "80"


-- Automatically reload files when they change on disk
vim.opt.autoread = true
vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold", "CursorHoldI", "FocusGained" }, {
    command = "if mode() != 'c' | checktime | endif",
    pattern = { "*" },
})
