vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Block cursor, with mode feedback drawn via `HumoodagenModeCursor*` highlights.
vim.opt.guicursor = table.concat({
    "n-v:block-HumoodagenModeCursorNormal",
    "i-ci:block-HumoodagenModeCursorInsert",
    "c:block-HumoodagenModeCursorInsert",
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

vim.opt.shortmess:append("IS")

vim.opt.cmdheight = 0
vim.opt.laststatus = 0

-- Never allow Insert-mode in NvimTree (it's a non-modifiable buffer and will
-- throw E21 on any keypress if something forces `startinsert`).
local tree_mode_group = vim.api.nvim_create_augroup("HumoodagenNoInsertInTree", { clear = true })
vim.api.nvim_create_autocmd("InsertEnter", {
    group = tree_mode_group,
    callback = function()
        local buf = vim.api.nvim_get_current_buf()
        if vim.bo[buf].filetype == "NvimTree" then
            vim.cmd("stopinsert")
        end
    end,
})

-- With `cmdheight=0`, the cmdline/search UI is drawn over the bottom-most split,
-- which can look like the cursor "jumps" into whichever pane is on the bottom.
-- Temporarily increase cmdheight while the cmdline is active so it gets its own row.
local cmdheight_group = vim.api.nvim_create_augroup("HumoodagenCmdheight", { clear = true })
local cmdheight_restore = nil
vim.api.nvim_create_autocmd("CmdlineEnter", {
    group = cmdheight_group,
    callback = function()
        if vim.o.cmdheight == 0 then
            cmdheight_restore = vim.o.cmdheight
            vim.o.cmdheight = 1
        end
    end,
})
vim.api.nvim_create_autocmd("CmdlineLeave", {
    group = cmdheight_group,
    callback = function()
        if cmdheight_restore ~= nil then
            vim.o.cmdheight = cmdheight_restore
            cmdheight_restore = nil
        end
    end,
})

-- Silence deprecation warnings (stops the tailwind-tools/lspconfig flash)
vim.g.deprecation_warnings = false

vim.opt.termguicolors = true

vim.opt.fillchars = vim.tbl_extend("force", vim.opt.fillchars:get(), {
    horiz = "─",
    horizup = "┴",
    horizdown = "┬",
    vert = "│",
    vertleft = "┤",
    vertright = "├",
    verthoriz = "┼",
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

-- Sync Neovim cwd to terminals that emit OSC 7 (current working directory).
-- This is used by the floating "command terminal" so `cd`/`z` updates the
-- file tree root (via nvim-tree's sync_root_with_cwd).
local osc7_group = vim.api.nvim_create_augroup("HumoodagenOsc7Cwd", { clear = true })

local function parse_osc7_dir(seq)
    if type(seq) ~= "string" then
        return nil
    end
    if seq:sub(1, 4) ~= "\x1b]7;" then
        return nil
    end

    local dir = seq:gsub("^\x1b]7;file://[^/]*", "")
    dir = dir:gsub("\x1b\\$", ""):gsub("\x07$", "")
    dir = vim.trim(dir)
    if dir == "" then
        return nil
    end
    return dir
end

local function cd_if_changed(dir)
    if type(dir) ~= "string" or dir == "" then
        return
    end
    if vim.fn.isdirectory(dir) == 0 then
        return
    end
    if vim.loop.cwd() == dir then
        return
    end
    vim.cmd("cd " .. vim.fn.fnameescape(dir))
end

vim.api.nvim_create_autocmd("TermRequest", {
    group = osc7_group,
    callback = function(ev)
        local dir = parse_osc7_dir(ev.data and ev.data.sequence or nil)
        if not dir then
            return
        end

        vim.b[ev.buf].humoodagen_osc7_dir = dir
        if vim.b[ev.buf].humoodagen_term_cwd_sync then
            cd_if_changed(dir)
        end
    end,
})

vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
    group = osc7_group,
    callback = function(ev)
        local buf = ev.buf
        if not (buf and vim.api.nvim_buf_is_valid(buf)) then
            return
        end
        if not vim.b[buf].humoodagen_term_cwd_sync then
            return
        end
        local dir = vim.b[buf].humoodagen_osc7_dir
        if type(dir) == "string" and dir ~= "" then
            cd_if_changed(dir)
        end
    end,
})
