vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Block cursor, with mode feedback drawn via `HumoodagenModeCursor*` highlights.
vim.opt.guicursor = table.concat({
    "n-v-c:block-HumoodagenModeCursorNormal",
    "i-ci:block-HumoodagenModeCursorInsert",
    "r-cr:block-HumoodagenModeCursorReplace",
    "o:block-HumoodagenModeCursorNormal",
    "v-ve:block-HumoodagenModeCursorVisual",
    "sm:block-HumoodagenModeCursorNormal",
    "t:block-HumoodagenModeCursorInsert",
}, ",")

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.cursorline = true
vim.opt.splitright = true
vim.opt.splitbelow = true

vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true

vim.opt.smartindent = true

vim.opt.wrap = false
vim.opt.linebreak = true
vim.opt.breakindent = true

vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.undodir = os.getenv("HOME") .. "/.vim/undodir"
vim.opt.undofile = true

vim.opt.hlsearch = false
vim.opt.incsearch = true

vim.opt.wildmenu = true
vim.opt.wildmode = "longest:full,full"
vim.opt.wildoptions = "pum"

vim.opt.shortmess:append("I")

vim.opt.cmdheight = 0
vim.opt.laststatus = 0

-- Silence deprecation warnings (stops the tailwind-tools/lspconfig flash)
vim.g.deprecation_warnings = false

vim.opt.termguicolors = true

vim.opt.fillchars:append({
    horiz = "-",
    horizup = "+",
    horizdown = "+",
    verthoriz = "+",
})



vim.opt.scrolloff = 8
vim.opt.signcolumn = "yes"
vim.opt.isfname:append("@-@")

vim.opt.updatetime = 50  -- Back to original value

vim.opt.colorcolumn = "80"

-- Make Escape responsive, but still long enough to reliably parse Ghostty's
-- Cmd-based escape sequences (they start with ESC, so too-low values break).
vim.opt.timeoutlen = 300
vim.opt.ttimeoutlen = 10


-- Automatically reload files when they change on disk
vim.opt.autoread = true
vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold", "CursorHoldI", "FocusGained" }, {
    callback = function()
        if vim.fn.mode() ~= 'c' and vim.fn.getcmdwintype() == '' then
            pcall(vim.cmd, 'checktime')
        end
    end,
    pattern = { "*" },
})
