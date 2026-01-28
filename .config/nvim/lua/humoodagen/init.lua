require("humoodagen.set")
require("humoodagen.views")
require("humoodagen.neovide")
require("humoodagen.remap")
require("humoodagen.commands")
require("humoodagen.lazy_init")
local debug = require("humoodagen.debug")

require("humoodagen.mode_cursor").setup()

-- DO.not
-- DO NOT INCLUDE THIS

-- If i want to keep doing lsp debugging
-- function restart_htmx_lsp()
--     require("lsp-debug-tools").restart({ expected = {}, name = "htmx-lsp", cmd = { "htmx-lsp", "--level", "DEBUG" }, root_dir = vim.loop.cwd(), });
-- end

-- DO NOT INCLUDE THIS
-- DO.not

local augroup = vim.api.nvim_create_augroup
local ThePrimeagenGroup = augroup('ThePrimeagen', {})

local autocmd = vim.api.nvim_create_autocmd
local yank_group = augroup('HighlightYank', {})

function R(name)
    require("plenary.reload").reload_module(name)
end

vim.filetype.add({
    extension = {
        templ = 'templ',
        cls = 'tex',
        tikz = 'tex',
    }
})

if vim.g.tex_flavor == nil then
    vim.g.tex_flavor = "latex"
end

autocmd('TextYankPost', {
    group = yank_group,
    pattern = '*',
    callback = function()
        vim.highlight.on_yank({
            higroup = 'IncSearch',
            timeout = 40,
        })
    end,
})

autocmd({"BufWritePre"}, {
    group = ThePrimeagenGroup,
    pattern = "*",
    command = [[%s/\s\+$//e]],
})

local pane_mode_group = augroup("HumoodagenPaneModeRestore", { clear = true })

local function pane_mode_table()
    if type(vim.g.humoodagen_pane_mode) ~= "table" then
        vim.g.humoodagen_pane_mode = {}
    end

    local t = vim.g.humoodagen_pane_mode
    if type(t.tree) ~= "string" then
        t.tree = "n"
    end
    if type(t.main) ~= "string" then
        t.main = "n"
    end
    if type(t.bottom) ~= "string" then
        t.bottom = "t"
    end
    if type(t.right) ~= "string" then
        t.right = "t"
    end
    return t
end

local function is_main_buf(buf)
    if not (buf and vim.api.nvim_buf_is_valid(buf)) then
        return false
    end

    if vim.bo[buf].buftype ~= "" then
        return false
    end

    local ft = vim.bo[buf].filetype
    if ft == "NvimTree" or ft == "toggleterm" then
        return false
    end

    return true
end

autocmd("InsertEnter", {
    group = pane_mode_group,
    callback = function()
        local buf = vim.api.nvim_get_current_buf()
        if not is_main_buf(buf) then
            return
        end

        local mode = vim.api.nvim_get_mode().mode
        pane_mode_table().main = mode
        debug.log("pane_mode.main <- " .. mode .. " source=InsertEnter")
    end,
})

autocmd("ModeChanged", {
    group = pane_mode_group,
    callback = function()
        local buf = vim.api.nvim_get_current_buf()
        if not is_main_buf(buf) then
            return
        end

        local new_mode = vim.v.event and vim.v.event.new_mode or vim.api.nvim_get_mode().mode
        if type(new_mode) ~= "string" or new_mode == "" then
            return
        end

        local first = new_mode:sub(1, 1)
        if first == "v" or new_mode == "V" or new_mode == "\022" then
            pane_mode_table().main = new_mode
            debug.log("pane_mode.main <- " .. new_mode .. " source=ModeChanged(visual)")
        end
    end,
})

autocmd("WinEnter", {
    group = pane_mode_group,
    callback = function()
        local win = vim.api.nvim_get_current_win()
        local buf = vim.api.nvim_get_current_buf()
        if not is_main_buf(buf) then
            return
        end

        local desired = pane_mode_table().main or "n"
        local first = desired:sub(1, 1)

        debug.log("pane_restore WinEnter desired=" .. desired)

        local function attempt_restore(tag)
            if not vim.api.nvim_win_is_valid(win) then
                debug.log("pane_restore skip(" .. tag .. ") reason=invalid_win desired=" .. desired)
                return
            end
            if vim.api.nvim_get_current_win() ~= win then
                debug.log("pane_restore skip(" .. tag .. ") reason=win_changed desired=" .. desired)
                return
            end
            if not is_main_buf(vim.api.nvim_get_current_buf()) then
                debug.log("pane_restore skip(" .. tag .. ") reason=not_main_buf desired=" .. desired)
                return
            end
            if vim.api.nvim_get_mode().mode:sub(1, 1) ~= "n" then
                debug.log("pane_restore skip(" .. tag .. ") reason=mode_not_normal desired=" .. desired)
                return
            end

            if first == "i" then
                debug.log("pane_restore apply(" .. tag .. ") action=startinsert desired=" .. desired)
                pcall(vim.cmd, "startinsert")
                return
            end

            if first == "v" or desired == "V" or desired == "\022" then
                debug.log("pane_restore apply(" .. tag .. ") action=gv desired=" .. desired)
                pcall(vim.cmd, "normal! gv")
                return
            end
        end

        vim.schedule(function()
            attempt_restore("schedule")
        end)
        vim.defer_fn(function()
            attempt_restore("defer10")
        end, 10)
        vim.defer_fn(function()
            attempt_restore("defer50")
        end, 50)
    end,
})

local tmux_state_group = augroup("HumoodagenTmuxState", { clear = true })

local function tmux_set_pane_option(args)
    if not (vim.env.TMUX and vim.env.TMUX_PANE) then
        return
    end

    local tmux_bin = vim.env.HUMOODAGEN_TMUX_BIN
    if type(tmux_bin) ~= "string" or tmux_bin == "" then
        tmux_bin = "tmux"
    end

    local cmd = { tmux_bin, "set-option", "-p", "-t", vim.env.TMUX_PANE }
    for _, part in ipairs(args) do
        table.insert(cmd, part)
    end

    pcall(vim.fn.jobstart, cmd, { detach = true })
end

autocmd("VimEnter", {
    group = tmux_state_group,
    callback = function()
        tmux_set_pane_option({ "@pane_is_nvim", "1" })
    end,
})

autocmd("VimLeavePre", {
    group = tmux_state_group,
    callback = function()
        tmux_set_pane_option({ "-u", "@pane_is_nvim" })
    end,
})

local ghostty_group = augroup("HumoodagenGhosttyCwd", { clear = true })

local function write_ghostty_cwd()
    if vim.env.HUMOODAGEN_GHOSTTY ~= "1" then
        return
    end

    local state_home = vim.env.XDG_STATE_HOME
    if type(state_home) ~= "string" or state_home == "" then
        state_home = (vim.env.HOME or "") .. "/.local/state"
    end
    if state_home == "" then
        return
    end

    local dir = vim.fn.getcwd()
    if type(dir) ~= "string" or dir == "" or vim.fn.isdirectory(dir) ~= 1 then
        return
    end

    local out_dir = state_home .. "/humoodagen"
    pcall(vim.fn.mkdir, out_dir, "p")
    pcall(vim.fn.writefile, { dir }, out_dir .. "/ghostty-cwd", "b")
end

autocmd("VimLeavePre", {
    group = ghostty_group,
    callback = function()
        write_ghostty_cwd()
    end,
})

-- autocmd('BufEnter', {
--     group = ThePrimeagenGroup,
--     callback = function()
--         if vim.bo.filetype == "zig" then
--             vim.cmd.colorscheme("tokyonight-night")
--         else
--             vim.cmd.colorscheme("rose-pine-moon")
--         end
--     end
-- })


-- Fallback LSP keybindings via LspAttach autocmd
-- This ensures keybindings work even if on_attach isn't called
autocmd('LspAttach', {
    group = ThePrimeagenGroup,
    callback = function(e)
        local opts = { buffer = e.buf }
        vim.keymap.set("n", "gd", function() vim.lsp.buf.definition() end, opts)
        vim.keymap.set("n", "gD", function() vim.lsp.buf.declaration() end, opts)
        vim.keymap.set("n", "K", function() vim.lsp.buf.hover() end, opts)
        vim.keymap.set("n", "gi", function() vim.lsp.buf.implementation() end, opts)
        vim.keymap.set("n", "<leader>sh", function() vim.lsp.buf.signature_help() end, opts)
        vim.keymap.set("n", "<leader>rn", function() vim.lsp.buf.rename() end, opts)
        vim.keymap.set("n", "<leader>ca", function() vim.lsp.buf.code_action() end, opts)
        vim.keymap.set("n", "gr", function() vim.lsp.buf.references() end, opts)
        vim.keymap.set("n", "<leader>d", function() vim.diagnostic.open_float() end, opts)
        vim.keymap.set("n", "[d", function() vim.diagnostic.goto_next() end, opts)
        vim.keymap.set("n", "]d", function() vim.diagnostic.goto_prev() end, opts)
    end
})
