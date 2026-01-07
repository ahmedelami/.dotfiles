vim.g.mapleader = " "
-- vim.keymap.set('n', '<leader>pv', vim.cmd.Ex)

vim.keymap.set({ "n", "v" }, "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })
vim.keymap.set({ "n", "v" }, "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })

vim.keymap.set("n", "<C-c>", "<cmd>q<CR>")

-- highlight and move
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")

vim.keymap.set("n", "<C-d>", "<C-d>zz")
vim.keymap.set("n", "<C-u>", "<C-u>zz")
vim.keymap.set("n", "n", "nzzzv")
vim.keymap.set("n", "N", "Nzzzv")

-- next greatest remap ever : asbjornHaland
vim.keymap.set({"n", "v"}, "<leader>y", [["+y]])
vim.keymap.set("n", "<leader>Y", [["+Y]])

-- apparently dont go to Q ever? so disable it
vim.keymap.set("n", "Q", "<nop>")

vim.keymap.set("n", "<leader>f", vim.lsp.buf.format)

-- make executable
vim.keymap.set("n", "<leader>x", "<cmd>!chmod +x %<CR>", { silent = true })

local debug = require("humoodagen.debug")

local pending_main_normal = nil

local function cancel_pending_main_normal()
    pending_main_normal = nil
end

local function cancel_pending_toggleterm_exit()
    local fn = rawget(_G, "HumoodagenCancelToggletermPendingExit")
    if type(fn) == "function" then
        pcall(fn)
    end
end

local function set_main_mode_normal()
    vim.g.humoodagen_pane_mode = vim.g.humoodagen_pane_mode or {}
    vim.g.humoodagen_pane_mode.main = "n"
    debug.log("pane_mode.main <- n source=main_exit")
end

local function schedule_main_mode_normal(buf)
    pending_main_normal = buf
    debug.log("pane_mode.main schedule <- n source=main_exit buf=" .. tostring(buf))
    vim.defer_fn(function()
        if pending_main_normal ~= buf then
            debug.log("pane_mode.main schedule canceled buf=" .. tostring(buf))
            return
        end
        pending_main_normal = nil
        set_main_mode_normal()
    end, 30)
end

vim.keymap.set("i", "<Esc>", function()
    local buf = vim.api.nvim_get_current_buf()
    if vim.bo[buf].buftype == "" then
        local ft = vim.bo[buf].filetype
        if ft ~= "NvimTree" and ft ~= "toggleterm" then
            local has_pending = vim.fn.getchar(1) ~= 0
            if not has_pending then
                if vim.g.neovide then
                    schedule_main_mode_normal(buf)
                else
                    set_main_mode_normal()
                end
            end
        end
    end
    return "<Esc>"
end, { expr = true, silent = true, desc = "Exit insert (remember per pane)" })

vim.keymap.set("i", "<C-[>", function()
    local buf = vim.api.nvim_get_current_buf()
    if vim.bo[buf].buftype == "" then
        local ft = vim.bo[buf].filetype
        if ft ~= "NvimTree" and ft ~= "toggleterm" then
            local has_pending = vim.fn.getchar(1) ~= 0
            if not has_pending then
                if vim.g.neovide then
                    schedule_main_mode_normal(buf)
                else
                    set_main_mode_normal()
                end
            end
        end
    end
    return "<C-[>"
end, { expr = true, silent = true, desc = "Exit insert (remember per pane)" })

vim.keymap.set({ "v", "x" }, "<Esc>", function()
    local buf = vim.api.nvim_get_current_buf()
    if vim.bo[buf].buftype == "" then
        local ft = vim.bo[buf].filetype
        if ft ~= "NvimTree" and ft ~= "toggleterm" then
            local has_pending = vim.fn.getchar(1) ~= 0
            if not has_pending then
                if vim.g.neovide then
                    schedule_main_mode_normal(buf)
                else
                    set_main_mode_normal()
                end
            end
        end
    end
    return "<Esc>"
end, { expr = true, silent = true, desc = "Exit visual (remember per pane)" })

vim.keymap.set({ "v", "x" }, "<C-[>", function()
    local buf = vim.api.nvim_get_current_buf()
    if vim.bo[buf].buftype == "" then
        local ft = vim.bo[buf].filetype
        if ft ~= "NvimTree" and ft ~= "toggleterm" then
            local has_pending = vim.fn.getchar(1) ~= 0
            if not has_pending then
                if vim.g.neovide then
                    schedule_main_mode_normal(buf)
                else
                    set_main_mode_normal()
                end
            end
        end
    end
    return "<C-[>"
end, { expr = true, silent = true, desc = "Exit visual (remember per pane)" })

local function toggle_nvim_tree_any_mode()
    local mode = vim.api.nvim_get_mode().mode
    local mode_prefix = mode:sub(1, 1)
    local suppressed = false
    if mode_prefix == "t" then
        local buf = vim.api.nvim_get_current_buf()
        if vim.bo[buf].filetype == "toggleterm" then
            vim.b.humoodagen_term_mode = "t"
        end
        vim.g.humoodagen_suppress_toggleterm_mode_capture = (vim.g.humoodagen_suppress_toggleterm_mode_capture or 0) + 1
        suppressed = true
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true), "n", false)
    elseif mode_prefix == "c" then
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-c>", true, false, true), "n", false)
    end

    vim.schedule(function()
        pcall(function()
            require("nvim-tree.api").tree.toggle()
        end)
        if suppressed then
            vim.g.humoodagen_suppress_toggleterm_mode_capture = math.max(0, (vim.g.humoodagen_suppress_toggleterm_mode_capture or 0) - 1)
        end
    end)
end

local function toggle_nvim_tree_visibility_any_mode()
    local mode = vim.api.nvim_get_mode().mode
    local mode_prefix = mode:sub(1, 1)
    local suppressed = false
    if mode_prefix == "t" then
        local buf = vim.api.nvim_get_current_buf()
        if vim.bo[buf].filetype == "toggleterm" then
            vim.b.humoodagen_term_mode = "t"
        end
        vim.g.humoodagen_suppress_toggleterm_mode_capture = (vim.g.humoodagen_suppress_toggleterm_mode_capture or 0) + 1
        suppressed = true
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true), "n", false)
    elseif mode_prefix == "c" then
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-c>", true, false, true), "n", false)
    end

    vim.schedule(function()
        local ok, api = pcall(require, "nvim-tree.api")
        if not ok then
            if suppressed then
                vim.g.humoodagen_suppress_toggleterm_mode_capture = math.max(0, (vim.g.humoodagen_suppress_toggleterm_mode_capture or 0) - 1)
            end
            return
        end
        api.tree.toggle({ focus = false })
        if suppressed then
            vim.g.humoodagen_suppress_toggleterm_mode_capture = math.max(0, (vim.g.humoodagen_suppress_toggleterm_mode_capture or 0) - 1)
        end
    end)
end

local function focus_nvim_tree_any_mode()
    local mode = vim.api.nvim_get_mode().mode
    local mode_prefix = mode:sub(1, 1)
    local suppressed = false
    if mode_prefix == "t" then
        local buf = vim.api.nvim_get_current_buf()
        if vim.bo[buf].filetype == "toggleterm" then
            vim.b.humoodagen_term_mode = "t"
        end
        vim.g.humoodagen_suppress_toggleterm_mode_capture = (vim.g.humoodagen_suppress_toggleterm_mode_capture or 0) + 1
        suppressed = true
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true), "n", false)
    elseif mode_prefix == "c" then
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-c>", true, false, true), "n", false)
    end

    vim.schedule(function()
        local ok, api = pcall(require, "nvim-tree.api")
        if not ok then
            if suppressed then
                vim.g.humoodagen_suppress_toggleterm_mode_capture = math.max(0, (vim.g.humoodagen_suppress_toggleterm_mode_capture or 0) - 1)
            end
            return
        end
        api.tree.focus()
        if suppressed then
            vim.g.humoodagen_suppress_toggleterm_mode_capture = math.max(0, (vim.g.humoodagen_suppress_toggleterm_mode_capture or 0) - 1)
        end
    end)
end

local save_current_pane_mode

local function jump_or_toggle_filetree_any_mode()
    cancel_pending_main_normal()
    cancel_pending_toggleterm_exit()
    debug.log("jump filetree")
    if save_current_pane_mode then
        save_current_pane_mode()
    end
    local buf = vim.api.nvim_get_current_buf()
    if vim.bo[buf].filetype == "NvimTree" then
        toggle_nvim_tree_visibility_any_mode()
        return
    end

    focus_nvim_tree_any_mode()
end

vim.keymap.set("n", "h", function()
    local buf = vim.api.nvim_get_current_buf()
    if vim.bo[buf].buftype == "" then
        local ft = vim.bo[buf].filetype
        if ft ~= "NvimTree" and ft ~= "toggleterm" then
            local _, col = unpack(vim.api.nvim_win_get_cursor(0))
            if col == 0 and vim.v.count == 0 then
                jump_or_toggle_filetree_any_mode()
                return
            end
        end
    end

    vim.cmd("normal! " .. vim.v.count1 .. "h")
end, { silent = true, desc = "Smart left: cursor-left or filetree" })

local function resize_window_any_mode(cmd_or_fn)
    local mode = vim.api.nvim_get_mode().mode
    local mode_prefix = mode:sub(1, 1)
    local was_term_job = mode_prefix == "t"
    if mode_prefix == "t" then
        local buf = vim.api.nvim_get_current_buf()
        if vim.bo[buf].filetype == "toggleterm" then
            vim.b.humoodagen_term_mode = "t"
        end
        vim.g.humoodagen_suppress_toggleterm_mode_capture = (vim.g.humoodagen_suppress_toggleterm_mode_capture or 0) + 1
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true), "n", false)
    elseif mode_prefix == "c" then
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-c>", true, false, true), "n", false)
    end

    vim.schedule(function()
        local ok, err = pcall(function()
            if type(cmd_or_fn) == "function" then
                cmd_or_fn()
            else
                vim.cmd(cmd_or_fn)
            end
        end)

        if was_term_job then
            local buf = vim.api.nvim_get_current_buf()
            if vim.bo[buf].filetype == "toggleterm" then
                vim.cmd("startinsert")
            end
            vim.g.humoodagen_suppress_toggleterm_mode_capture = math.max(0, (vim.g.humoodagen_suppress_toggleterm_mode_capture or 0) - 1)
        end

        if not ok then
            error(err)
        end
    end)
end

local function current_toggleterm_direction()
    local buf = vim.api.nvim_get_current_buf()
    if vim.bo[buf].filetype ~= "toggleterm" then
        return nil
    end

    local term_id = vim.b[buf].toggle_number
    if not term_id then
        return nil
    end

    local ok, term_module = pcall(require, "toggleterm.terminal")
    if not ok then
        return nil
    end

    local term = term_module.get(term_id, true)
    return term and term.direction or nil
end

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

local function current_pane_key()
    local buf = vim.api.nvim_get_current_buf()
    local ft = vim.bo[buf].filetype
    if ft == "NvimTree" then
        return "tree"
    end

    if ft == "toggleterm" then
        local direction = current_toggleterm_direction()
        if direction == "horizontal" then
            return "bottom"
        end
        if direction == "vertical" then
            return "right"
        end
        return nil
    end

    if vim.bo[buf].buftype == "" then
        return "main"
    end

    return nil
end

save_current_pane_mode = function()
    local pane = current_pane_key()
    if not pane then
        return
    end
    local mode = vim.api.nvim_get_mode().mode
    if pane ~= "main" then
        pane_mode_table()[pane] = mode
    end
end

local function block_vertical_resize()
    local buf = vim.api.nvim_get_current_buf()
    if vim.bo[buf].filetype == "NvimTree" then
        return true
    end

    return current_toggleterm_direction() == "vertical"
end

local function resize_toward(direction, shrink_cmd)
    resize_window_any_mode(function()
        local neighbor_nr = vim.fn.winnr(direction)
        if neighbor_nr ~= 0 then
            local neighbor_win = vim.fn.win_getid(neighbor_nr)
            if neighbor_win ~= 0 then
                vim.api.nvim_win_call(neighbor_win, function()
                    vim.cmd(shrink_cmd)
                end)
                return
            end
        end

        vim.cmd(shrink_cmd)
    end)
end

local function resize_left()
    resize_toward("h", "vertical resize -5")
end

local function resize_right()
    resize_toward("l", "vertical resize -5")
end

local function resize_down()
    if block_vertical_resize() then
        return
    end
    resize_toward("j", "resize -2")
end

local function resize_up()
    if block_vertical_resize() then
        return
    end
    resize_toward("k", "resize -2")
end

local all_modes = { "n", "i", "v", "x", "s", "o", "t", "c" }
vim.keymap.set(all_modes, "<C-f>", "<C-e>", { desc = "Ctrl-E default" })
vim.keymap.set(all_modes, "<C-e>", toggle_nvim_tree_any_mode, { desc = "Toggle NvimTree" })
vim.keymap.set(all_modes, "<C-S-h>", resize_left, { desc = "Resize split left" })
vim.keymap.set(all_modes, "<C-S-l>", resize_right, { desc = "Resize split right" })
vim.keymap.set(all_modes, "<C-S-j>", resize_down, { desc = "Resize split down" })
vim.keymap.set(all_modes, "<C-S-k>", resize_up, { desc = "Resize split up" })

local function find_main_win()
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        local cfg = vim.api.nvim_win_get_config(win)
        if cfg.relative == "" then
            local buf = vim.api.nvim_win_get_buf(win)
            if vim.bo[buf].buftype == "" then
                local ft = vim.bo[buf].filetype
                if ft ~= "NvimTree" and ft ~= "toggleterm" then
                    return win
                end
            end
        end
    end
    return nil
end

local function ensure_main_win()
    local win = find_main_win()
    if win and vim.api.nvim_win_is_valid(win) then
        return win
    end

    local wins = vim.api.nvim_tabpage_list_wins(0)
    if #wins == 0 then
        return nil
    end

    local anchor = wins[1]
    if anchor and vim.api.nvim_win_is_valid(anchor) then
        vim.api.nvim_set_current_win(anchor)
    end

    vim.cmd("vsplit")
    vim.cmd("enew")
    return vim.api.nvim_get_current_win()
end

local untitled_prompt_group = vim.api.nvim_create_augroup("HumoodagenUntitledPrompt", { clear = true })

local function is_untitled_buf(buf)
    if not (buf and vim.api.nvim_buf_is_valid(buf)) then
        return false
    end
    if vim.bo[buf].buftype ~= "" then
        return false
    end
    local ft = vim.bo[buf].filetype
    if ft == "NvimTree" or ft == "toggleterm" or ft == "TelescopePrompt" then
        return false
    end
    return vim.api.nvim_buf_get_name(buf) == ""
end

local function untitled_has_content(buf)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    for _, line in ipairs(lines) do
        if line ~= "" then
            return true
        end
    end
    return false
end

local function prompt_save_untitled(buf)
    if not is_untitled_buf(buf) then
        return
    end
    if not vim.bo[buf].modified then
        return
    end
    if not untitled_has_content(buf) then
        vim.bo[buf].modified = false
        return
    end

    local name = vim.fn.input("Type file name then Enter to save, or 'n' then Enter to discard: ", "", "file")
    name = vim.fn.trim(name)
    if name:lower() == "n" then
        vim.api.nvim_buf_delete(buf, { force = true })
        return
    end
    if name == "" then
        local win = vim.api.nvim_get_current_win()
        vim.schedule(function()
            if vim.api.nvim_win_is_valid(win) then
                vim.api.nvim_set_current_win(win)
            end
        end)
        return
    end

    local full_path = vim.fn.fnamemodify(name, ":p")
    vim.fn.mkdir(vim.fn.fnamemodify(full_path, ":h"), "p")
    vim.cmd("silent keepalt saveas " .. vim.fn.fnameescape(full_path))
end

vim.api.nvim_create_autocmd("WinLeave", {
    group = untitled_prompt_group,
    callback = function()
        if #vim.api.nvim_list_uis() == 0 then
            return
        end

        local buf = vim.api.nvim_get_current_buf()
        if not is_untitled_buf(buf) then
            return
        end
        if vim.b[buf].humoodagen_untitled_prompting then
            return
        end
        if not vim.bo[buf].modified then
            return
        end

        vim.b[buf].humoodagen_untitled_prompting = true
        local ok, err = pcall(prompt_save_untitled, buf)
        vim.b[buf].humoodagen_untitled_prompting = false
        if not ok then
            error(err)
        end
    end,
})

local ctrl_k_toggleterm_group = vim.api.nvim_create_augroup("HumoodagenToggletermCtrlK", { clear = true })
vim.api.nvim_create_autocmd("FileType", {
    group = ctrl_k_toggleterm_group,
    pattern = "toggleterm",
    callback = function(event)
        vim.keymap.set({ "t", "n" }, "<C-k>", function()
            if save_current_pane_mode then
                save_current_pane_mode()
            end

            local origin_win = vim.api.nvim_get_current_win()
            local origin_buf = vim.api.nvim_get_current_buf()
            local origin_mode = vim.api.nvim_get_mode().mode
            if origin_mode:sub(1, 1) == "t" then
                vim.b[origin_buf].humoodagen_term_mode = "t"
            else
                vim.b[origin_buf].humoodagen_term_mode = "nt"
            end

            local suppressed = false
            if origin_mode:sub(1, 1) == "t" then
                vim.g.humoodagen_suppress_toggleterm_mode_capture =
                    (vim.g.humoodagen_suppress_toggleterm_mode_capture or 0) + 1
                suppressed = true
                vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true), "n", false)
            end

            vim.schedule(function()
                local ok, err = pcall(function()
                    local main_win = ensure_main_win()
                    if main_win and vim.api.nvim_win_is_valid(main_win) then
                        vim.api.nvim_set_current_win(main_win)
                    end

                    local ok_lazy, lazy = pcall(require, "lazy")
                    if ok_lazy then
                        lazy.load({ plugins = { "fzf-lua" } })
                    end

                    if type(_G.HumoodagenFindFilesOrCreate) == "function" then
                        _G.HumoodagenFindFilesOrCreate({ origin_win = origin_win, origin_buf = origin_buf })
                        return
                    end

                    local map = vim.fn.maparg("<C-k>", "n", false, true)
                    if map and type(map.callback) == "function" then
                        map.callback({ origin_win = origin_win, origin_buf = origin_buf })
                        return
                    end

                    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-k>", true, false, true), "m", false)
                end)

                if suppressed then
                    vim.g.humoodagen_suppress_toggleterm_mode_capture =
                        math.max(0, (vim.g.humoodagen_suppress_toggleterm_mode_capture or 0) - 1)
                end

                if not ok then
                    error(err)
                end
            end)
        end, { buffer = event.buf, nowait = true, silent = true, desc = "Find/create files (cwd) (Ctrl+K)" })
    end,
})

local esc = "\x1b"

local function call_toggleterm_action(action)
    local actions = _G.HumoodagenPanes
    if not actions then
        local ok_lazy, lazy = pcall(require, "lazy")
        if ok_lazy then
            lazy.load({ plugins = { "toggleterm.nvim" } })
        end
        actions = _G.HumoodagenPanes
    end
    if actions and actions[action] then
        actions[action]()
    end
end

local function call_toggleterm_any_mode(action)
    resize_window_any_mode(function()
        call_toggleterm_action(action)
    end)
end

-- Cmd+H/J/K/L jumps to fixed panes.
local function jump_or_toggle_bottom_any_mode()
    cancel_pending_main_normal()
    cancel_pending_toggleterm_exit()
    debug.log("jump bottom")
    save_current_pane_mode()
    if current_toggleterm_direction() == "horizontal" then
        call_toggleterm_any_mode("toggle_bottom")
    else
        call_toggleterm_any_mode("jump_bottom")
    end
end

local function jump_or_toggle_main_any_mode()
    cancel_pending_main_normal()
    cancel_pending_toggleterm_exit()
    debug.log("jump main")
    save_current_pane_mode()
    local buf = vim.api.nvim_get_current_buf()
    local buftype = vim.bo[buf].buftype
    local ft = vim.bo[buf].filetype
    local in_main = buftype == "" and ft ~= "NvimTree" and ft ~= "toggleterm"

    if in_main then
        call_toggleterm_any_mode("toggle_main_only")
    else
        call_toggleterm_any_mode("jump_main")
    end
end

local function jump_or_toggle_right_any_mode()
    cancel_pending_main_normal()
    cancel_pending_toggleterm_exit()
    debug.log("jump right")
    save_current_pane_mode()
    if current_toggleterm_direction() == "vertical" then
        call_toggleterm_any_mode("toggle_right")
    else
        call_toggleterm_any_mode("jump_right")
    end
end

vim.keymap.set(all_modes, "<D-h>", jump_or_toggle_filetree_any_mode, { desc = "Jump/toggle filetree (Cmd+H)" })
vim.keymap.set(all_modes, "<D-j>", jump_or_toggle_bottom_any_mode, { desc = "Jump/toggle bottom terminal (Cmd+J)" })
vim.keymap.set(all_modes, "<D-k>", jump_or_toggle_main_any_mode, { desc = "Jump/toggle file-only (Cmd+K)" })
vim.keymap.set(all_modes, "<D-l>", jump_or_toggle_right_any_mode, { desc = "Jump/toggle right terminal (Cmd+L)" })

vim.keymap.set(all_modes, "<F55>", jump_or_toggle_filetree_any_mode, { desc = "Jump/toggle filetree (Cmd+H ghostty)" })
vim.keymap.set(all_modes, "<F56>", jump_or_toggle_bottom_any_mode, { desc = "Jump/toggle bottom terminal (Cmd+J ghostty)" })
vim.keymap.set(all_modes, "<F57>", jump_or_toggle_main_any_mode, { desc = "Jump/toggle file-only (Cmd+K ghostty)" })
vim.keymap.set(all_modes, "<F58>", jump_or_toggle_right_any_mode, { desc = "Jump/toggle right terminal (Cmd+L ghostty)" })

-- Raw ESC-prefixed sequences (mostly for terminal emulators) make a plain `Esc`
-- ambiguous, which can add a noticeable delay when exiting Insert/Visual mode.
-- Neovide sends proper `<D-…>` keycodes, so skip these there to keep `Esc`
-- instant.
if not vim.g.neovide then
    vim.keymap.set(all_modes, esc .. "[18;3~", jump_or_toggle_filetree_any_mode, { desc = "Jump/toggle filetree (Cmd+H raw)" })
    vim.keymap.set(all_modes, esc .. "[19;3~", jump_or_toggle_bottom_any_mode, { desc = "Jump/toggle bottom terminal (Cmd+J raw)" })
    vim.keymap.set(all_modes, esc .. "[20;3~", jump_or_toggle_main_any_mode, { desc = "Jump/toggle file-only (Cmd+K raw)" })
    vim.keymap.set(all_modes, esc .. "[21;3~", jump_or_toggle_right_any_mode, { desc = "Jump/toggle right terminal (Cmd+L raw)" })
    vim.keymap.set(all_modes, esc .. "[18;9~", jump_or_toggle_filetree_any_mode, { desc = "Jump/toggle filetree (Cmd+H fallback)" })
    vim.keymap.set(all_modes, esc .. "[19;9~", jump_or_toggle_bottom_any_mode, { desc = "Jump/toggle bottom terminal (Cmd+J fallback)" })
    vim.keymap.set(all_modes, esc .. "[20;9~", jump_or_toggle_main_any_mode, { desc = "Jump/toggle file-only (Cmd+K fallback)" })
    vim.keymap.set(all_modes, esc .. "[21;9~", jump_or_toggle_right_any_mode, { desc = "Jump/toggle right terminal (Cmd+L fallback)" })
end

-- Cmd+Shift+H/J/K/L toggles panes.
vim.keymap.set(all_modes, "<D-S-h>", function()
    save_current_pane_mode()
    toggle_nvim_tree_visibility_any_mode()
end, { desc = "Toggle filetree (Cmd+Shift+H)" })
vim.keymap.set(all_modes, "<D-S-j>", function()
    save_current_pane_mode()
    call_toggleterm_any_mode("toggle_bottom")
end, { desc = "Toggle bottom terminal (Cmd+Shift+J)" })
vim.keymap.set(all_modes, "<D-S-k>", function()
    save_current_pane_mode()
    call_toggleterm_any_mode("toggle_main_only")
end, { desc = "Toggle file-only mode (Cmd+Shift+K)" })
vim.keymap.set(all_modes, "<D-S-l>", function()
    save_current_pane_mode()
    call_toggleterm_any_mode("toggle_right")
end, { desc = "Toggle right terminal (Cmd+Shift+L)" })

vim.keymap.set(all_modes, "<F19>", function()
    save_current_pane_mode()
    toggle_nvim_tree_visibility_any_mode()
end, { desc = "Toggle filetree (Cmd+Shift+H ghostty)" })
vim.keymap.set(all_modes, "<F20>", function()
    save_current_pane_mode()
    call_toggleterm_any_mode("toggle_bottom")
end, { desc = "Toggle bottom terminal (Cmd+Shift+J ghostty)" })
vim.keymap.set(all_modes, "<F21>", function()
    save_current_pane_mode()
    call_toggleterm_any_mode("toggle_main_only")
end, { desc = "Toggle file-only mode (Cmd+Shift+K ghostty)" })
vim.keymap.set(all_modes, "<F22>", function()
    save_current_pane_mode()
    call_toggleterm_any_mode("toggle_right")
end, { desc = "Toggle right terminal (Cmd+Shift+L ghostty)" })

vim.keymap.set(all_modes, "<S-F9>", function()
    save_current_pane_mode()
    toggle_nvim_tree_visibility_any_mode()
end, { desc = "Toggle filetree (Cmd+Shift+H fallback)" })
vim.keymap.set(all_modes, "<S-F10>", function()
    save_current_pane_mode()
    call_toggleterm_any_mode("toggle_bottom")
end, { desc = "Toggle bottom terminal (Cmd+Shift+J fallback)" })
vim.keymap.set(all_modes, "<F11>", function()
    save_current_pane_mode()
    call_toggleterm_any_mode("toggle_main_only")
end, { desc = "Toggle file-only mode (Cmd+Shift+K fallback)" })
vim.keymap.set(all_modes, "<F12>", function()
    save_current_pane_mode()
    call_toggleterm_any_mode("toggle_right")
end, { desc = "Toggle right terminal (Cmd+Shift+L fallback)" })

if not vim.g.neovide then
    vim.keymap.set(all_modes, esc .. "[33~", function()
        save_current_pane_mode()
        toggle_nvim_tree_visibility_any_mode()
    end, { desc = "Toggle filetree (Cmd+Shift+H raw)" })
    vim.keymap.set(all_modes, esc .. "[34~", function()
        save_current_pane_mode()
        call_toggleterm_any_mode("toggle_bottom")
    end, { desc = "Toggle bottom terminal (Cmd+Shift+J raw)" })
    vim.keymap.set(all_modes, esc .. "[35~", function()
        save_current_pane_mode()
        call_toggleterm_any_mode("toggle_main_only")
    end, { desc = "Toggle file-only mode (Cmd+Shift+K raw)" })
    vim.keymap.set(all_modes, esc .. "[36~", function()
        save_current_pane_mode()
        call_toggleterm_any_mode("toggle_right")
    end, { desc = "Toggle right terminal (Cmd+Shift+L raw)" })

    vim.keymap.set(all_modes, esc .. "[18;2~", function()
        save_current_pane_mode()
        toggle_nvim_tree_visibility_any_mode()
    end, { desc = "Toggle filetree (Cmd+Shift+H xterm)" })
    vim.keymap.set(all_modes, esc .. "[19;2~", function()
        save_current_pane_mode()
        call_toggleterm_any_mode("toggle_bottom")
    end, { desc = "Toggle bottom terminal (Cmd+Shift+J xterm)" })
    vim.keymap.set(all_modes, esc .. "[20;2~", function()
        save_current_pane_mode()
        call_toggleterm_any_mode("toggle_main_only")
    end, { desc = "Toggle file-only mode (Cmd+Shift+K xterm)" })
    vim.keymap.set(all_modes, esc .. "[21;2~", function()
        save_current_pane_mode()
        call_toggleterm_any_mode("toggle_right")
    end, { desc = "Toggle right terminal (Cmd+Shift+L xterm)" })
end

-- Cmd+Ctrl+H/J/K/L resizes splits.
vim.keymap.set(all_modes, "<D-C-h>", resize_left, { desc = "Resize split left (Cmd+Ctrl+H)" })
vim.keymap.set(all_modes, "<D-C-j>", resize_down, { desc = "Resize split down (Cmd+Ctrl+J)" })
vim.keymap.set(all_modes, "<D-C-k>", resize_up, { desc = "Resize split up (Cmd+Ctrl+K)" })
vim.keymap.set(all_modes, "<D-C-l>", resize_right, { desc = "Resize split right (Cmd+Ctrl+L)" })
vim.keymap.set(all_modes, "<F31>", resize_left, { desc = "Resize split left (Cmd+Ctrl+H ghostty)" })
vim.keymap.set(all_modes, "<F32>", resize_down, { desc = "Resize split down (Cmd+Ctrl+J ghostty)" })
vim.keymap.set(all_modes, "<F33>", resize_up, { desc = "Resize split up (Cmd+Ctrl+K ghostty)" })
vim.keymap.set(all_modes, "<F34>", resize_right, { desc = "Resize split right (Cmd+Ctrl+L ghostty)" })
if not vim.g.neovide then
    vim.keymap.set(all_modes, esc .. "[18;5~", resize_left, { desc = "Resize split left (Cmd+Ctrl+H raw)" })
    vim.keymap.set(all_modes, esc .. "[19;5~", resize_down, { desc = "Resize split down (Cmd+Ctrl+J raw)" })
    vim.keymap.set(all_modes, esc .. "[20;5~", resize_up, { desc = "Resize split up (Cmd+Ctrl+K raw)" })
    vim.keymap.set(all_modes, esc .. "[21;5~", resize_right, { desc = "Resize split right (Cmd+Ctrl+L raw)" })
end

-- Set the width of a hard tabstop
vim.opt.tabstop = 4

-- Set the number of spaces inserted for each indentation
vim.opt.shiftwidth = 4

-- When pressing Tab in Insert mode, insert the number of spaces specified by shiftwidth
vim.opt.softtabstop = 4

-- Convert tabs to spaces
vim.opt.expandtab = true

-- If left here, it means this fix indent on new line being 8 spaces
vim.opt.smartindent = true
