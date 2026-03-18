local M = {}

local commands = require("humoodagen.commands")
local git_review = require("humoodagen.git_review")

local picker_patched = false

local function termcodes(str)
    return vim.api.nvim_replace_termcodes(str, true, false, true)
end

local function normalize_search(text)
    if type(text) ~= "string" then
        return nil
    end

    local normalized = text
        :gsub("\r\n", "\n")
        :gsub("\r", "\n")
        :gsub("\n", " ")
        :gsub("%s+", " ")
    normalized = vim.trim(normalized)
    if normalized == "" then
        return nil
    end

    return normalized
end

local function get_visual_selection()
    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")
    if start_pos[2] == 0 or end_pos[2] == 0 then
        return nil
    end

    local ok, region = pcall(vim.fn.getregion, start_pos, end_pos, { type = vim.fn.visualmode() })
    if ok and type(region) == "table" then
        return normalize_search(table.concat(region, "\n"))
    end

    local start_row, start_col = start_pos[2], start_pos[3]
    local end_row, end_col = end_pos[2], end_pos[3]
    if end_row < start_row or (end_row == start_row and end_col < start_col) then
        start_row, end_row = end_row, start_row
        start_col, end_col = end_col, start_col
    end

    local lines = vim.api.nvim_buf_get_lines(0, start_row - 1, end_row, false)
    if vim.tbl_isempty(lines) then
        return nil
    end

    lines[1] = lines[1]:sub(start_col)
    lines[#lines] = lines[#lines]:sub(1, end_col)
    return normalize_search(table.concat(lines, "\n"))
end

local function capture_origin()
    local origin_win = vim.api.nvim_get_current_win()
    local origin_buf = nil
    if origin_win and vim.api.nvim_win_is_valid(origin_win) then
        origin_buf = vim.api.nvim_win_get_buf(origin_win)
    end

    return {
        origin_win = origin_win,
        origin_buf = origin_buf,
        origin_mode = vim.api.nvim_get_mode().mode,
    }
end

local function restore_origin_term_mode(target_win, origin_mode)
    if not (target_win and vim.api.nvim_win_is_valid(target_win)) then
        return
    end

    local buf = vim.api.nvim_win_get_buf(target_win)
    if not (buf and vim.api.nvim_buf_is_valid(buf)) then
        return
    end
    if vim.bo[buf].filetype ~= "toggleterm" then
        return
    end

    local desired = vim.b[buf].humoodagen_term_mode
    if type(desired) ~= "string" or desired == "" then
        desired = origin_mode or "t"
    end
    if desired:sub(1, 1) ~= "t" then
        return
    end

    vim.defer_fn(function()
        if not vim.api.nvim_win_is_valid(target_win) then
            return
        end
        if vim.api.nvim_get_current_win() ~= target_win then
            return
        end

        local cur_buf = vim.api.nvim_win_get_buf(target_win)
        if vim.bo[cur_buf].filetype ~= "toggleterm" then
            return
        end
        if vim.api.nvim_get_mode().mode ~= "t" then
            vim.cmd("startinsert")
        end
    end, 10)
end

local function jump_back_to_origin(origin)
    if type(origin) ~= "table" then
        return
    end

    local target_win = nil
    local origin_win = origin.origin_win
    local origin_buf = origin.origin_buf
    if origin_win and vim.api.nvim_win_is_valid(origin_win) then
        target_win = origin_win
    elseif origin_buf and vim.api.nvim_buf_is_valid(origin_buf) then
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            if vim.api.nvim_win_get_buf(win) == origin_buf then
                target_win = win
                break
            end
        end
    end

    if not target_win then
        return
    end

    vim.api.nvim_set_current_win(target_win)
    restore_origin_term_mode(target_win, origin.origin_mode)
end

local function set_picker_query(query)
    local picker_ui = require("fff.picker_ui")
    local state = picker_ui.state
    if not (state and state.active and state.input_buf and vim.api.nvim_buf_is_valid(state.input_buf)) then
        return
    end

    local prompt = state.config and state.config.prompt or ""
    vim.api.nvim_set_option_value("modifiable", true, { buf = state.input_buf })
    vim.api.nvim_buf_set_lines(state.input_buf, 0, -1, false, { prompt .. query })
    if state.input_win and vim.api.nvim_win_is_valid(state.input_win) then
        vim.api.nvim_win_set_cursor(state.input_win, { 1, #prompt + #query })
    end
end

function M.complete_file_query_to_next_path_segment()
    local picker_ui = require("fff.picker_ui")
    local state = picker_ui.state
    if not (state and state.active) then
        return
    end
    if state.mode == "grep" or state.suggestion_source then
        return
    end

    local items = state.filtered_items or {}
    local item = items[state.cursor]
    if not item then
        return
    end

    local selected = item.relative_path or item.path
    if type(selected) ~= "string" or selected == "" then
        return
    end

    local query = state.query or ""
    local next_query = query
    if query == "" then
        local slash = selected:find("/", 1, true)
        next_query = slash and selected:sub(1, slash) or selected
    elseif not vim.startswith(selected, query) then
        return
    else
        local rest = selected:sub(#query + 1)
        local slash = rest:find("/", 1, true)
        next_query = slash and selected:sub(1, #query + slash) or selected
    end

    if next_query ~= query then
        set_picker_query(next_query)
    end
end

local function install_file_picker_keymaps()
    local picker_ui = require("fff.picker_ui")
    local state = picker_ui.state
    if not (state and state.active and state.mode ~= "grep") then
        return
    end
    if not (state.input_buf and vim.api.nvim_buf_is_valid(state.input_buf)) then
        return
    end

    vim.keymap.set({ "i", "n" }, "<Right>", M.complete_file_query_to_next_path_segment, {
        buffer = state.input_buf,
        noremap = true,
        silent = true,
    })
end

local function ensure_picker_patched()
    if picker_patched then
        return
    end

    local picker_ui = require("fff.picker_ui")

    local original_close = picker_ui.close
    picker_ui.close = function(...)
        local state = picker_ui.state
        local humoodagen = state and state.config and state.config.humoodagen or nil
        local should_restore = humoodagen and humoodagen.restore_origin_on_close and not state.humoodagen_skip_restore
        local origin = should_restore and {
            origin_win = humoodagen.origin_win,
            origin_buf = humoodagen.origin_buf,
            origin_mode = humoodagen.origin_mode,
        } or nil

        local result = original_close(...)
        picker_ui.state.humoodagen_skip_restore = nil

        if origin then
            vim.schedule(function()
                jump_back_to_origin(origin)
            end)
        end

        return result
    end

    local original_select = picker_ui.select
    picker_ui.select = function(action)
        local state = picker_ui.state
        if not (state and state.active) then
            return original_select(action)
        end

        state.humoodagen_skip_restore = true

        if state.mode ~= "grep" and state.suggestion_source == nil then
            local items = state.filtered_items or {}
            if #items == 0 or state.cursor > #items then
                local query = normalize_search(state.query)
                if not query then
                    state.humoodagen_skip_restore = nil
                    return
                end

                vim.cmd("stopinsert")
                picker_ui.close()
                commands.create_path(query)
                return
            end
        end

        return original_select(action)
    end

    local original_update_results_sync = picker_ui.update_results_sync
    picker_ui.update_results_sync = function(...)
        local result = original_update_results_sync(...)

        local state = picker_ui.state
        local humoodagen = state and state.config and state.config.humoodagen or nil
        if not (state and state.active and humoodagen and humoodagen.disable_file_suggestions) then
            return result
        end
        if state.mode == "grep" or state.suggestion_source ~= "grep" then
            return result
        end

        state.suggestion_items = nil
        state.suggestion_source = nil
        state.filtered_items = state.items or {}
        state.cursor = 1
        picker_ui.render_list()
        picker_ui.update_preview()
        picker_ui.update_status()

        return result
    end

    picker_patched = true
end

local function open_file_picker(opts)
    ensure_picker_patched()
    require("fff").find_files(opts)
    vim.schedule(install_file_picker_keymaps)
end

local function build_picker_opts(origin, extra)
    return vim.tbl_deep_extend("force", {
        cwd = vim.fn.getcwd(),
        keymaps = {
            close = { "<Esc>", "<C-k>" },
            select = { "<CR>", "<Tab>" },
            toggle_select = "<F3>",
        },
        humoodagen = {
            origin_win = origin.origin_win,
            origin_buf = origin.origin_buf,
            origin_mode = origin.origin_mode,
            restore_origin_on_close = true,
            disable_file_suggestions = true,
        },
    }, extra or {})
end

local function normalize_path(pathname)
    if type(pathname) ~= "string" or pathname == "" then
        return nil
    end

    local abs = vim.fn.fnamemodify(pathname, ":p")
    if abs == "" then
        return nil
    end

    return abs
end

local function get_git_root(pathname)
    local abs = normalize_path(pathname or vim.fn.getcwd())
    if not abs then
        return nil
    end

    local dir = abs
    if vim.fn.isdirectory(dir) == 0 then
        dir = vim.fn.fnamemodify(dir, ":h")
    end

    local out = vim.fn.systemlist({ "git", "-C", dir, "rev-parse", "--show-toplevel" })
    if vim.v.shell_error ~= 0 then
        return nil
    end

    return out[1]
end

function M.find_files_cwd()
    local origin = capture_origin()
    open_file_picker(build_picker_opts(origin))
end

function M.find_files_visual_cwd()
    local selection = get_visual_selection()
    if not selection then
        return
    end

    local origin = capture_origin()
    vim.api.nvim_feedkeys(termcodes("<Esc>"), "nx", false)
    vim.schedule(function()
        open_file_picker(build_picker_opts(origin, { query = selection }))
    end)
end

function M.git_files_or_files_cwd()
    local origin = capture_origin()
    local cwd = vim.fn.getcwd()
    local root = get_git_root(cwd)
    open_file_picker(build_picker_opts(origin, { cwd = root or cwd }))
end

function M.live_grep_cwd(search)
    ensure_picker_patched()

    local origin = capture_origin()
    local opts = {
        cwd = vim.fn.getcwd(),
        keymaps = {
            close = { "<Esc>", "<C-j>" },
        },
        humoodagen = {
            origin_win = origin.origin_win,
            origin_buf = origin.origin_buf,
            origin_mode = origin.origin_mode,
            restore_origin_on_close = true,
        },
    }
    if search then
        opts.query = search
    end

    require("fff").live_grep(opts)
end

function M.live_grep_visual_cwd()
    local search = get_visual_selection()
    if not search then
        return
    end

    vim.api.nvim_feedkeys(termcodes("<Esc>"), "nx", false)
    vim.schedule(function()
        M.live_grep_cwd(search)
    end)
end

local function find_main_edit_win()
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

local function get_context_path(buf)
    if not (buf and vim.api.nvim_buf_is_valid(buf)) then
        return nil
    end

    local name = vim.api.nvim_buf_get_name(buf)
    if vim.bo[buf].buftype == "" and name ~= "" then
        return name
    end

    local ft = vim.bo[buf].filetype
    if ft == "NvimTree" then
        local ok_api, api = pcall(require, "nvim-tree.api")
        if ok_api then
            local ok_node, node = pcall(api.tree.get_node_under_cursor)
            if ok_node and node then
                return node.link_to or node.absolute_path
            end
        end
    end

    return vim.fn.getcwd()
end

local function git_status_items(root)
    local out = vim.fn.systemlist({
        "git",
        "-C",
        root,
        "-c",
        "core.quotePath=false",
        "status",
        "--porcelain=v1",
    })
    if vim.v.shell_error ~= 0 then
        return nil
    end

    local items = {}
    local seen = {}
    for _, line in ipairs(out) do
        if type(line) == "string" and line ~= "" then
            local status = line:sub(1, 2)
            local pathname = vim.trim(line:sub(4))
            local display_path = pathname

            if status:find("R", 1, true) or status:find("C", 1, true) then
                local parts = vim.split(pathname, " -> ", { plain = true })
                if #parts >= 2 then
                    pathname = parts[#parts]
                end
            end

            if pathname ~= "" and not seen[status .. "\n" .. pathname] then
                seen[status .. "\n" .. pathname] = true
                table.insert(items, {
                    text = status .. " " .. display_path,
                    path = root .. "/" .. pathname,
                    relpath = pathname,
                    display_path = display_path,
                    status = status,
                })
            end
        end
    end

    return items
end

local function open_git_diff_scratch(win, root, relpath, display, opts)
    if not (win and vim.api.nvim_win_is_valid(win)) then
        return false
    end
    if type(root) ~= "string" or root == "" then
        return false
    end
    if type(relpath) ~= "string" or relpath == "" then
        return false
    end

    local args = { "diff", "--no-color" }
    if opts and opts.cached then
        table.insert(args, "--cached")
    end
    table.insert(args, "--")
    table.insert(args, relpath)

    local cmd = { "git", "-C", root, "-c", "core.quotePath=false" }
    vim.list_extend(cmd, args)
    local lines = vim.fn.systemlist(cmd)
    if vim.v.shell_error ~= 0 then
        vim.notify("git diff failed for " .. relpath, vim.log.levels.ERROR)
        return false
    end
    if vim.tbl_isempty(lines) then
        vim.notify("No diff output for " .. relpath, vim.log.levels.INFO)
        return false
    end

    local title = "[git diff] " .. (display or relpath)
    vim.api.nvim_win_call(win, function()
        vim.cmd("enew")
        local buf = vim.api.nvim_get_current_buf()
        vim.api.nvim_buf_set_name(buf, title)
        vim.bo[buf].buftype = "nofile"
        vim.bo[buf].bufhidden = "wipe"
        vim.bo[buf].swapfile = false
        vim.bo[buf].modifiable = true
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        vim.bo[buf].modifiable = false
        vim.bo[buf].readonly = true
        vim.bo[buf].filetype = "diff"
    end)
    return true
end

local function open_git_change(item, target_win, root)
    if not item then
        return
    end

    local win = target_win
    if not (win and vim.api.nvim_win_is_valid(win)) then
        win = vim.api.nvim_get_current_win()
    end

    local should_focus = false
    vim.api.nvim_win_call(win, function()
        local pathname = item.path
        if type(pathname) ~= "string" or pathname == "" then
            vim.notify("Invalid path.", vim.log.levels.ERROR)
            return
        end

        if vim.fn.filereadable(pathname) == 0 then
            local status = item.status or ""
            local relpath = item.relpath or nil
            local display = item.display_path or nil
            local index_status = type(status) == "string" and status:sub(1, 1) or ""
            local worktree_status = type(status) == "string" and status:sub(2, 2) or ""

            if index_status == "D" or worktree_status == "D" then
                should_focus = open_git_diff_scratch(win, root, relpath or pathname, display, {
                    cached = index_status == "D",
                })
                return
            end

            vim.notify("File not readable: " .. pathname, vim.log.levels.WARN)
            return
        end

        vim.cmd("edit " .. vim.fn.fnameescape(pathname))
        should_focus = true
        pcall(git_review.open, { win = win })
    end)

    if should_focus then
        vim.schedule(function()
            if vim.api.nvim_win_is_valid(win) then
                vim.api.nvim_set_current_win(win)
            end
        end)
    end
end

local function open_git_changes_picker(target_win, context_path)
    local root = get_git_root(context_path)
    if not root or root == "" then
        vim.notify("Not inside a Git repository.", vim.log.levels.WARN)
        return
    end

    local items = git_status_items(root) or {}
    if vim.tbl_isempty(items) then
        vim.notify("No Git changes found.", vim.log.levels.INFO)
        return
    end

    vim.ui.select(items, {
        prompt = "Git Changes",
        format_item = function(item)
            return item.text
        end,
    }, function(item)
        open_git_change(item, target_win, root)
    end)
end

local function ctrl_g()
    local initial_buf = vim.api.nvim_get_current_buf()
    local initial_context_path = get_context_path(initial_buf)
    local initial_name = vim.api.nvim_buf_get_name(initial_buf)
    local initial_ft = vim.bo[initial_buf].filetype
    local initial_buftype = vim.bo[initial_buf].buftype

    local target_win = find_main_edit_win()
    if not (target_win and vim.api.nvim_win_is_valid(target_win)) then
        target_win = vim.api.nvim_get_current_win()
    end

    local is_file_buf = initial_buftype == ""
        and initial_name ~= ""
        and initial_ft ~= "NvimTree"
        and initial_ft ~= "toggleterm"
    if is_file_buf then
        local has_changes = vim.bo[initial_buf].modified
        if not has_changes then
            local root = get_git_root(initial_name)
            if root and root ~= "" then
                local out = vim.fn.systemlist({
                    "git",
                    "-C",
                    root,
                    "-c",
                    "core.quotePath=false",
                    "status",
                    "--porcelain=v1",
                    "--",
                    initial_name,
                })
                if vim.v.shell_error == 0 then
                    for _, line in ipairs(out) do
                        if type(line) == "string" and line ~= "" then
                            has_changes = true
                            break
                        end
                    end
                end
            end
        end

        if has_changes then
            pcall(git_review.toggle, { win = target_win })
            return
        end

        open_git_changes_picker(target_win, initial_context_path)
        return
    end

    open_git_changes_picker(target_win, initial_context_path)
end

function M.ctrl_g()
    ctrl_g()
end

function M.ctrl_g_from_terminal()
    vim.api.nvim_feedkeys(termcodes("<C-\\><C-n>"), "n", false)
    vim.schedule(ctrl_g)
end

function M.ctrl_g_from_insert()
    vim.cmd("stopinsert")
    vim.schedule(ctrl_g)
end

return M
