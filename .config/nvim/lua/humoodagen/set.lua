vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Netrw: hide the big top banner/quick-help block (still accessible via :help).
vim.g.netrw_banner = 0

-- Cursor styles (terminal): block cursor with per-mode highlighting.
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

vim.opt.wrap = true
vim.opt.linebreak = true
vim.opt.breakindent = true
vim.opt.breakindentopt = "list:-1"
-- Better "hanging indent" when wrapping list items (e.g. "- item…" / "1. item…").
vim.opt.formatlistpat = "^\\s*\\(\\d\\+[\\]:.)}\\t ]\\|[-*+]\\)\\s\\+"

-- Keep wrap off in terminals/special panes (and the file tree), but default it
-- on for regular file buffers.
local nowrap_group = vim.api.nvim_create_augroup("HumoodagenNoWrapSpecial", { clear = true })
vim.api.nvim_create_autocmd({ "FileType", "TermOpen" }, {
    group = nowrap_group,
    callback = function()
        local buf = vim.api.nvim_get_current_buf()
        local bt = vim.bo[buf].buftype
        local ft = vim.bo[buf].filetype

        if ft == "NvimTree" then
            vim.opt_local.wrap = false
            return
        end

        if bt ~= "" or ft == "toggleterm" then
            vim.opt_local.wrap = false
        end
    end,
})

-- Allow non-standard "standalone" markdown task lines like:
--   [ ] item
--   [] item
-- to render like checkboxes (conceal only; underlying text remains).
local md_checkbox_group = vim.api.nvim_create_augroup("HumoodagenMarkdownPlainCheckbox", { clear = true })
vim.api.nvim_create_autocmd("FileType", {
    group = md_checkbox_group,
    pattern = { "markdown", "quarto", "rmd" },
    callback = function(args)
        if vim.b[args.buf].humoodagen_plain_checkbox_syntax then
            return
        end
        vim.b[args.buf].humoodagen_plain_checkbox_syntax = true

        vim.api.nvim_buf_call(args.buf, function()
            vim.cmd([[syntax match HumoodagenPlainCheckboxChecked /^\s*\(>\s*\)*\zs\[[xX]\]\ze/ conceal cchar=● contained containedin=ALLBUT,markdownCodeBlock]])
            vim.cmd([[syntax match HumoodagenPlainCheckboxUnchecked /^\s*\(>\s*\)*\zs\[\s\]\ze/ conceal cchar=○ contained containedin=ALLBUT,markdownCodeBlock]])
            vim.cmd([[syntax match HumoodagenPlainCheckboxUnchecked /^\s*\(>\s*\)*\zs\[\]\ze/ conceal cchar=○ contained containedin=ALLBUT,markdownCodeBlock]])
            vim.cmd([[highlight default link HumoodagenPlainCheckboxChecked Normal]])
            vim.cmd([[highlight default link HumoodagenPlainCheckboxUnchecked Normal]])
        end)
    end,
})

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

vim.opt.cmdheight = 1
if vim.g.humoodagen_profile == "ide_like_exp" then
    vim.g.humoodagen_base_laststatus = 2
    vim.opt.laststatus = 2
else
    vim.g.humoodagen_base_laststatus = 0
    vim.opt.laststatus = 0
end

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

-- Keep the classic bottom cmdline (no floating cmdline UI).
local cmdheight_group = vim.api.nvim_create_augroup("HumoodagenCmdheight", { clear = true })
local enforcing_cmdheight = false

local function enforce_cmdheight()
    if enforcing_cmdheight then
        return
    end
    if vim.o.cmdheight ~= 1 then
        enforcing_cmdheight = true
        vim.o.cmdheight = 1
        enforcing_cmdheight = false
    end
end

vim.api.nvim_create_autocmd({ "VimEnter", "UIEnter" }, {
    group = cmdheight_group,
    callback = function()
        enforce_cmdheight()
    end,
})

vim.api.nvim_create_autocmd("CmdlineEnter", {
    group = cmdheight_group,
    callback = function()
        enforce_cmdheight()
    end,
})

vim.api.nvim_create_autocmd("OptionSet", {
    group = cmdheight_group,
    pattern = "cmdheight",
    callback = function()
        enforce_cmdheight()
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

-- Make key sequences responsive, but still long enough to reliably parse
-- Ghostty's Cmd-based escape sequences (they start with ESC, so too-low values
-- break). Neovide isn't affected by terminal escape sequences, so give leader
-- combos a bit more time there.
if vim.g.neovide then
    vim.opt.timeoutlen = 800
else
    vim.opt.timeoutlen = 300
end
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

-- Fast-start: pre-create the final pane layout (tree + main + bottom) as early
-- as possible so the first visible frame is already "stable".
local function humoodagen_startup_overlay_should_show()
    if vim.g.humoodagen_profile ~= "ide_like_exp" then
        return false
    end
    if vim.env.HUMOODAGEN_GHOSTTY ~= "1" then
        return false
    end
    if vim.env.HUMOODAGEN_FAST_START ~= "1" then
        return false
    end
    if vim.fn.argc() ~= 0 then
        return false
    end
    if vim.env.HUMOODAGEN_NVIM_STARTUP_OVERLAY == "0" then
        return false
    end
    if #vim.api.nvim_list_uis() == 0 then
        return false
    end
    return true
end

local function humoodagen_startup_overlay_show()
    if not humoodagen_startup_overlay_should_show() then
        return
    end
    if vim.g.humoodagen_startup_overlay_win and vim.api.nvim_win_is_valid(vim.g.humoodagen_startup_overlay_win) then
        return
    end

    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].swapfile = false
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "", "  Launching…" })
    vim.bo[buf].modifiable = false

    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        row = 0,
        col = 0,
        width = vim.o.columns,
        height = vim.o.lines,
        style = "minimal",
        zindex = 200,
    })

    vim.wo[win].winhighlight = "Normal:Normal,NormalNC:Normal"
    vim.wo[win].number = false
    vim.wo[win].relativenumber = false
    vim.wo[win].signcolumn = "no"
    vim.wo[win].cursorline = false

    vim.g.humoodagen_startup_overlay_win = win
    vim.g.humoodagen_startup_overlay_buf = buf
end

local function humoodagen_startup_overlay_hide()
    local win = vim.g.humoodagen_startup_overlay_win
    if win and vim.api.nvim_win_is_valid(win) then
        pcall(vim.api.nvim_win_close, win, true)
    end
    vim.g.humoodagen_startup_overlay_win = nil
    vim.g.humoodagen_startup_overlay_buf = nil
end

local function humoodagen_precreate_startup_layout()
    if vim.g.humoodagen_startup_layout_precreated then
        return
    end
    if vim.g.humoodagen_profile ~= "ide_like_exp" then
        return
    end
    if vim.env.HUMOODAGEN_FAST_START ~= "1" then
        return
    end
    if vim.fn.argc() ~= 0 then
        return
    end
    if #vim.api.nvim_list_uis() == 0 then
        return
    end

    local main_win = nil
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_is_valid(win) then
            local cfg = vim.api.nvim_win_get_config(win)
            if cfg and cfg.relative == "" then
                main_win = win
                break
            end
        end
    end
    if main_win == nil then
        return
    end

    if not (main_win and vim.api.nvim_win_is_valid(main_win)) then
        return
    end

    -- Left "tree" split.
    vim.api.nvim_set_current_win(main_win)
    local tree_width = math.floor(vim.o.columns * 0.15)
    if tree_width < 10 then
        tree_width = 10
    end
    pcall(vim.cmd, "topleft " .. tostring(tree_width) .. "vsplit")
    local tree_win = vim.api.nvim_get_current_win()
    if tree_win and vim.api.nvim_win_is_valid(tree_win) then
        vim.g.humoodagen_startup_tree_winid = tree_win

        local tree_buf = vim.api.nvim_create_buf(false, true)
        vim.bo[tree_buf].buftype = "nofile"
        vim.bo[tree_buf].bufhidden = "wipe"
        vim.bo[tree_buf].swapfile = false
        vim.bo[tree_buf].modifiable = false
        vim.api.nvim_win_set_buf(tree_win, tree_buf)
        vim.wo[tree_win].number = false
        vim.wo[tree_win].relativenumber = false
        vim.wo[tree_win].signcolumn = "no"
        vim.wo[tree_win].winbar = ""
    end

    -- Return to main, then create bottom split.
    if main_win and vim.api.nvim_win_is_valid(main_win) then
        vim.api.nvim_set_current_win(main_win)
    end
    local bottom_height = 15
    pcall(vim.cmd, "rightbelow " .. tostring(bottom_height) .. "split")
    local bottom_win = vim.api.nvim_get_current_win()
    if bottom_win and vim.api.nvim_win_is_valid(bottom_win) then
        vim.g.humoodagen_startup_bottom_winid = bottom_win

        local bottom_buf = vim.api.nvim_create_buf(false, true)
        vim.bo[bottom_buf].buftype = "nofile"
        vim.bo[bottom_buf].bufhidden = "wipe"
        vim.bo[bottom_buf].swapfile = false
        vim.bo[bottom_buf].modifiable = false
        vim.api.nvim_win_set_buf(bottom_win, bottom_buf)
        vim.wo[bottom_win].number = false
        vim.wo[bottom_win].relativenumber = false
        vim.wo[bottom_win].signcolumn = "no"
        vim.wo[bottom_win].winbar = ""
    end

    vim.g.humoodagen_startup_layout_precreated = true
end

humoodagen_startup_overlay_show()
humoodagen_precreate_startup_layout()
if vim.env.HUMOODAGEN_FAST_START == "1" and vim.fn.argc() == 0 and vim.g.humoodagen_profile == "ide_like_exp" then
    vim.api.nvim_create_autocmd("UIEnter", {
        once = true,
        callback = function()
            humoodagen_startup_overlay_show()
            humoodagen_precreate_startup_layout()
        end,
    })
end

if humoodagen_startup_overlay_should_show() then
    local overlay_group = vim.api.nvim_create_augroup("HumoodagenStartupOverlay", { clear = true })
    vim.api.nvim_create_autocmd("User", {
        group = overlay_group,
        pattern = "HumoodagenToggletermPromptReady",
        once = true,
        callback = function()
            humoodagen_startup_overlay_hide()
            pcall(vim.cmd, "redraw")
        end,
    })
    vim.api.nvim_create_autocmd("VimResized", {
        group = overlay_group,
        callback = function()
            local win = vim.g.humoodagen_startup_overlay_win
            if win and vim.api.nvim_win_is_valid(win) then
                pcall(vim.api.nvim_win_set_config, win, {
                    relative = "editor",
                    row = 0,
                    col = 0,
                    width = vim.o.columns,
                    height = vim.o.lines,
                })
            end
        end,
    })
    vim.defer_fn(function()
        humoodagen_startup_overlay_hide()
    end, 1200)
end

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
