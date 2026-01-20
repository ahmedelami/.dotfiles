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
vim.opt.numberwidth = 1
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

-- Show the current file name at the top of the window (winbar) instead of using
-- a statusline. ToggleTerm and NvimTree override this locally.
local humoodagen_file_winbar = " %<%t"
-- Don't set a global winbar (it would show up in NvimTree/term panes). We'll
-- apply it only to real file windows below.
vim.opt.winbar = ""

-- Only show the winbar in real file buffers; hide it in terminals and special
-- panes (otherwise ToggleTerm shows "zsh; #toggleterm#…" and wastes height).
local winbar_group = vim.api.nvim_create_augroup("HumoodagenWinbar", { clear = true })

local function sync_winbar_for_win(win)
    if not (win and vim.api.nvim_win_is_valid(win)) then
        return
    end
    local cfg = vim.api.nvim_win_get_config(win)
    if cfg and cfg.relative and cfg.relative ~= "" then
        return
    end
    local buf = vim.api.nvim_win_get_buf(win)
    if not (buf and vim.api.nvim_buf_is_valid(buf)) then
        return
    end

    local bt = vim.bo[buf].buftype
    local ft = vim.bo[buf].filetype
    if bt == "" and ft ~= "toggleterm" and ft ~= "NvimTree" then
        vim.wo[win].winbar = humoodagen_file_winbar
        return
    end

    vim.wo[win].winbar = ""
end

local function sync_all_winbars()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        sync_winbar_for_win(win)
    end
end

vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter", "WinEnter", "TermOpen", "FileType", "VimEnter" }, {
    group = winbar_group,
    callback = function()
        pcall(sync_all_winbars)
    end,
})

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

-- Disable mini.diff line-number coloring (git_review provides the diff view).
vim.g.minidiff_disable = true

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
vim.opt.signcolumn = "number"
vim.opt.isfname:append("@-@")

vim.opt.updatetime = 50  -- Back to original value

vim.opt.colorcolumn = "80"

-- Make Escape responsive, but still long enough to reliably parse Ghostty's
-- Cmd-based escape sequences (they start with ESC, so too-low values break).
vim.opt.timeoutlen = 300
vim.opt.ttimeoutlen = 10

-- Allow mapping <C-s>/<C-q> in terminal Neovim by disabling XON/XOFF flow control.
-- Many terminals default to `stty ixon`, which swallows Ctrl+S/Ctrl+Q.
if vim.fn.has("unix") == 1 and vim.fn.has("ttyin") == 1 and vim.fn.has("ttyout") == 1 and not vim.g.neovide then
    pcall(vim.fn.system, "stty -ixon < /dev/tty >/dev/null 2>&1")
end


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
    if type(seq) ~= "string" or seq == "" then
        return nil
    end

    -- Strip common OSC terminators (ST or BEL).
    local cleaned = seq:gsub("\x1b\\$", ""):gsub("\x07$", "")

    -- Neovim/terminals may hand us either the full OSC sequence
    -- (`ESC]7;file://...`) or just the payload portion. Still ensure this is
    -- OSC 7 (cwd) so we don't accidentally treat other OSC sequences (like
    -- OSC 8 hyperlinks) as directory changes.
    local payload = nil
    local osc_idx = cleaned:find("]7;file://", 1, true)
    if osc_idx then
        payload = cleaned:sub(osc_idx + 3) -- after "]7;"
    elseif cleaned:sub(1, 9) == "7;file://" then
        payload = cleaned:sub(3) -- after "7;"
    elseif cleaned:sub(1, 7) == "file://" then
        payload = cleaned
    else
        return nil
    end

    -- Drop hostname (may be empty) and keep the absolute path.
    local rest = payload:sub(8)
    local slash = rest:find("/", 1, true)
    if not slash then
        return nil
    end

    local dir = vim.trim(rest:sub(slash))
    if dir == "" then
        return nil
    end

    -- URI decode (%xx) so `isdirectory()` works with spaces, etc.
    dir = dir:gsub("%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16))
    end)
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
        if not vim.b[ev.buf].humoodagen_term_cwd_sync then
            return
        end

        local dirty = vim.b[ev.buf].humoodagen_term_cwd_sync_dirty
        if not dirty then
            local baseline = vim.b[ev.buf].humoodagen_term_cwd_sync_baseline
            if type(baseline) ~= "string" or baseline == "" then
                vim.b[ev.buf].humoodagen_term_cwd_sync_baseline = dir
                return
            end
            if dir == baseline then
                return
            end
            vim.b[ev.buf].humoodagen_term_cwd_sync_dirty = true
        end

        -- TermRequest runs inside an autocmd callback; without scheduling,
        -- the resulting DirChanged autocommands (nvim-tree sync) won't run.
        -- Only change cwd when this terminal is focused; otherwise just record
        -- the dir and let BufEnter/WinEnter apply it when you return.
        if vim.api.nvim_get_current_buf() ~= ev.buf then
            return
        end
        vim.schedule(function()
            cd_if_changed(dir)
        end)
    end,
})

vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
    group = osc7_group,
    callback = function(ev)
        local buf = ev.buf
        vim.schedule(function()
            if not (buf and vim.api.nvim_buf_is_valid(buf)) then
                return
            end
            if vim.api.nvim_get_current_buf() ~= buf then
                return
            end
            if not vim.b[buf].humoodagen_term_cwd_sync then
                return
            end

            local dir = vim.b[buf].humoodagen_osc7_dir
            if type(dir) == "string" and dir ~= "" then
                cd_if_changed(dir)
            end
        end)
    end,
})
