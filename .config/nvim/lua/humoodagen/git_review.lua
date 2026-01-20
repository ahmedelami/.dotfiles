local M = {}

local diff_hl_ns = vim.api.nvim_create_namespace("HumoodagenGitReviewDiffHL")
local state_by_tab = {}

local hl_groups = {
    add = "HumoodagenGitReviewDiffAdd",
    delete = "HumoodagenGitReviewDiffDelete",
    hunk = "HumoodagenGitReviewDiffHunk",
    meta = "HumoodagenGitReviewDiffMeta",
}

local gitsigns_numhl_groups = {
    "GitSignsAddNr",
    "GitSignsChangeNr",
    "GitSignsDeleteNr",
    "GitSignsTopdeleteNr",
    "GitSignsChangedeleteNr",
    "GitSignsUntrackedNr",
}

local function is_valid_win(win)
    return type(win) == "number" and vim.api.nvim_win_is_valid(win)
end

local function is_valid_buf(buf)
    return type(buf) == "number" and vim.api.nvim_buf_is_valid(buf)
end

local function parse_winhl(value)
    local map = {}
    local order = {}
    if type(value) ~= "string" or value == "" then
        return map, order
    end

    for entry in value:gmatch("[^,]+") do
        local from, to = entry:match("^%s*([^:]+):(.+)%s*$")
        if from and to then
            from = vim.trim(from)
            to = vim.trim(to)
            if from ~= "" and to ~= "" then
                if map[from] == nil then
                    table.insert(order, from)
                end
                map[from] = to
            end
        end
    end

    return map, order
end

local function extend_winhl(value, groups, replacement)
    local map, order = parse_winhl(value)
    local changed = false
    replacement = replacement or "LineNr"

    for _, from in ipairs(groups or {}) do
        if map[from] == nil then
            table.insert(order, from)
        end
        if map[from] ~= replacement then
            map[from] = replacement
            changed = true
        end
    end

    local parts = {}
    for _, from in ipairs(order) do
        local to = map[from]
        if to and to ~= "" then
            table.insert(parts, from .. ":" .. to)
        end
    end

    return table.concat(parts, ","), changed
end

local function clamp_win_topline(win, topline)
    if not is_valid_win(win) then
        return 1
    end
    local buf = vim.api.nvim_win_get_buf(win)
    if not is_valid_buf(buf) then
        return 1
    end
    local line_count = vim.api.nvim_buf_line_count(buf)
    local height = vim.api.nvim_win_get_height(win)
    local max_top = math.max(1, line_count - height + 1)
    topline = tonumber(topline) or 1
    return math.max(1, math.min(topline, max_top))
end

local function win_topline(win)
    if not is_valid_win(win) then
        return 1
    end
    local ok, view = pcall(vim.api.nvim_win_call, win, function()
        return vim.fn.winsaveview()
    end)
    if ok and type(view) == "table" and type(view.topline) == "number" then
        return view.topline
    end
    return 1
end

local function win_cursor_info(win)
    if not is_valid_win(win) then
        return nil
    end
    local ok, info = pcall(vim.api.nvim_win_call, win, function()
        local cur = vim.api.nvim_win_get_cursor(0)
        return {
            lnum = cur[1],
            row = vim.fn.winline(),
        }
    end)
    if ok and type(info) == "table" and type(info.lnum) == "number" then
        return info
    end
    return nil
end

local function get_hl(name)
    local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
    if not ok or type(hl) ~= "table" then
        return {}
    end
    return hl
end

local function rgb_parts(color)
    if type(color) ~= "number" then
        return nil, nil, nil
    end
    local r = math.floor(color / 65536) % 256
    local g = math.floor(color / 256) % 256
    local b = color % 256
    return r, g, b
end

local function rgb_join(r, g, b)
    r = math.max(0, math.min(255, math.floor(r + 0.5)))
    g = math.max(0, math.min(255, math.floor(g + 0.5)))
    b = math.max(0, math.min(255, math.floor(b + 0.5)))
    return r * 65536 + g * 256 + b
end

local function blend(fg, bg, alpha)
    local fr, fg_g, fb = rgb_parts(fg)
    local br, bg_g, bb = rgb_parts(bg)
    if not (fr and fg_g and fb and br and bg_g and bb) then
        return nil
    end
    local r = fr * alpha + br * (1 - alpha)
    local g = fg_g * alpha + bg_g * (1 - alpha)
    local b = fb * alpha + bb * (1 - alpha)
    return rgb_join(r, g, b)
end

local function base_bg()
    local normal = get_hl("Normal")
    if type(normal.bg) == "number" then
        return normal.bg
    end
    local float = get_hl("NormalFloat")
    if type(float.bg) == "number" then
        return float.bg
    end
    if vim.o.background == "light" then
        return 0xffffff
    end
    return 0x000000
end

local function setup_diff_highlights()
    local bg = base_bg()
    local alpha = vim.o.background == "light" and 0.16 or 0.12

    local diff_add = get_hl("DiffAdd")
    local diff_delete = get_hl("DiffDelete")
    local diff_text = get_hl("DiffText")
    local diff_change = get_hl("DiffChange")

    local add_fg = diff_add.fg or get_hl("GitSignsAdd").fg
    local delete_fg = diff_delete.fg or get_hl("GitSignsDelete").fg
    local hunk_fg = diff_text.fg or diff_change.fg

    local add_bg = diff_add.bg or blend(add_fg or 0x2ecc71, bg, alpha) or bg
    local delete_bg = diff_delete.bg or blend(delete_fg or 0xe74c3c, bg, alpha) or bg
    local hunk_bg = diff_text.bg or diff_change.bg or blend(hunk_fg or 0x3498db, bg, alpha) or bg

    vim.api.nvim_set_hl(0, hl_groups.add, { fg = add_fg, bg = add_bg })
    vim.api.nvim_set_hl(0, hl_groups.delete, { fg = delete_fg, bg = delete_bg })
    vim.api.nvim_set_hl(0, hl_groups.hunk, { fg = hunk_fg, bg = hunk_bg, bold = true })
    vim.api.nvim_set_hl(0, hl_groups.meta, { bg = blend(hunk_fg or 0x3498db, bg, alpha * 0.6) or hunk_bg })
end

local function apply_diff_highlights(buf, lines)
    if not (is_valid_buf(buf) and type(lines) == "table") then
        return
    end

    setup_diff_highlights()
    vim.api.nvim_buf_clear_namespace(buf, diff_hl_ns, 0, -1)

    for i, line in ipairs(lines) do
        if type(line) == "string" and line ~= "" then
            local group = nil
            if line:match("^@@") then
                group = hl_groups.hunk
            elseif line:match("^%+%+%+[%s]") or line:match("^%-%-%-[%s]") or line:match("^diff%s") or line:match("^index%s") then
                group = hl_groups.meta
            elseif line:sub(1, 1) == "+" then
                group = hl_groups.add
            elseif line:sub(1, 1) == "-" then
                group = hl_groups.delete
            end

            if group then
                pcall(vim.api.nvim_buf_set_extmark, buf, diff_hl_ns, i - 1, 0, {
                    end_row = i,
                    end_col = 0,
                    hl_group = group,
                    hl_eol = true,
                    priority = 200,
                })
            end
        end
    end
end

local function diff_display_lines(lines)
    if type(lines) ~= "table" then
        return lines
    end

    local out = {}
    for _, line in ipairs(lines) do
        if type(line) ~= "string" then
            line = tostring(line or "")
        end
        if line == "" then
            table.insert(out, line)
        elseif line:match("^@@") or line:match("^%+%+%+[%s]") or line:match("^%-%-%-[%s]") or line:match("^diff%s") or line:match("^index%s") then
            table.insert(out, line)
        elseif line:sub(1, 1) == "+" or line:sub(1, 1) == "-" or line:sub(1, 1) == " " then
            table.insert(out, line:sub(2))
        else
            table.insert(out, line)
        end
    end
    return out
end

local function detach_gitsigns(state, buf)
    if not (state and is_valid_buf(buf)) then
        return
    end
    if vim.bo[buf].buftype ~= "" then
        return
    end

    if type(state.gitsigns_detached_bufs) ~= "table" then
        state.gitsigns_detached_bufs = {}
    end
    if state.gitsigns_detached_bufs[buf] then
        return
    end

    local ok, gs = pcall(require, "gitsigns")
    if not ok or type(gs) ~= "table" then
        return
    end

    local detached = pcall(gs.detach, buf)
    if detached then
        state.gitsigns_detached_bufs[buf] = true
    end
end

local function is_main_edit_buf(buf)
    if not is_valid_buf(buf) then
        return false
    end
    if vim.bo[buf].buftype ~= "" then
        return false
    end
    local ft = vim.bo[buf].filetype
    if ft == "NvimTree" or ft == "toggleterm" then
        return false
    end
    local name = vim.api.nvim_buf_get_name(buf)
    return type(name) == "string" and name ~= ""
end

local function find_main_edit_win()
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        local cfg = vim.api.nvim_win_get_config(win)
        if cfg.relative == "" then
            local buf = vim.api.nvim_win_get_buf(win)
            if is_main_edit_buf(buf) then
                return win
            end
        end
    end
    return nil
end

local function normalize_path(path)
    if type(path) ~= "string" or path == "" then
        return nil
    end
    local abs = vim.fn.fnamemodify(path, ":p")
    if abs == "" then
        return nil
    end
    return abs
end

local function realpath(path)
    if type(path) ~= "string" or path == "" then
        return nil
    end
    return vim.loop.fs_realpath(path) or path
end

local function get_git_root(context_path)
    local path = normalize_path(context_path) or normalize_path(vim.fn.getcwd())
    if not path then
        return nil
    end

    local dir = path
    if vim.fn.isdirectory(dir) == 0 then
        dir = vim.fn.fnamemodify(dir, ":h")
    end

    local out = vim.fn.systemlist({ "git", "-C", dir, "rev-parse", "--show-toplevel" })
    if vim.v.shell_error ~= 0 then
        return nil
    end
    return out[1]
end

local function relpath_from_root(root, abs_path)
    local rr = realpath(root)
    local rp = realpath(abs_path)
    if not (rr and rp) then
        return nil
    end

    rr = rr:gsub("[/\\]+$", "")
    if rp:sub(1, #rr) ~= rr then
        return nil
    end

    local rel = rp:sub(#rr + 2)
    if rel == "" then
        return nil
    end
    return rel
end

local function git_status_line(root, relpath)
    if type(root) ~= "string" or root == "" or type(relpath) ~= "string" or relpath == "" then
        return ""
    end
    local out = vim.fn.systemlist({
        "git",
        "-C",
        root,
        "-c",
        "core.quotePath=false",
        "status",
        "--porcelain=v1",
        "--",
        relpath,
    })
    if vim.v.shell_error ~= 0 then
        return ""
    end
    return out[1] or ""
end

local function git_diff_lines(root, relpath, abs_path)
    local status = git_status_line(root, relpath)
    if vim.startswith(status, "??") then
        local cmd = {
            "git",
            "-c",
            "core.quotePath=false",
            "diff",
            "--no-color",
            "--unified=999999",
            "--no-index",
            "--",
            "/dev/null",
            abs_path,
        }
        local lines = vim.fn.systemlist(cmd)
        local code = vim.v.shell_error
        if code ~= 0 and code ~= 1 then
            return nil, "git diff --no-index failed (exit " .. tostring(code) .. ")"
        end
        return lines, nil
    end

    local cmd = {
        "git",
        "-C",
        root,
        "-c",
        "core.quotePath=false",
        "diff",
        "--no-color",
        "--unified=999999",
        "--",
        relpath,
    }
    local lines = vim.fn.systemlist(cmd)
    if vim.v.shell_error ~= 0 then
        return nil, "git diff failed (exit " .. tostring(vim.v.shell_error) .. ")"
    end
    return lines, nil
end

local function build_line_maps(lines, file_line_count)
    local diff_to_new = {}
    local new_to_diff = {}
    local new_line = nil
    local mapped = 0

    for i, line in ipairs(lines) do
        if type(line) == "string" then
            local _, _, new_start = line:match("^@@%s%-(%d+),?(%d*)%s%+(%d+),?(%d*)%s@@")
            if new_start then
                new_line = tonumber(new_start)
            elseif new_line then
                local prefix = line:sub(1, 1)
                if prefix == " " or prefix == "+" then
                    diff_to_new[i] = new_line
                    if new_to_diff[new_line] == nil then
                        new_to_diff[new_line] = i
                    end
                    new_line = new_line + 1
                    mapped = mapped + 1
                end
            end
        end
    end

    if mapped == 0 then
        return {
            has_mapping = false,
            diff_to_new_prev = nil,
            new_to_diff_clamped = nil,
            diff_to_new = diff_to_new,
            new_to_diff = new_to_diff,
        }
    end

    local diff_to_new_prev = {}
    local last = nil
    for i = 1, #lines do
        local v = diff_to_new[i]
        if v ~= nil then
            last = v
        end
        diff_to_new_prev[i] = last
    end

    local first_file_line = nil
    for i = 1, #diff_to_new_prev do
        if diff_to_new_prev[i] ~= nil then
            first_file_line = diff_to_new_prev[i]
            break
        end
    end
    first_file_line = first_file_line or 1
    for i = 1, #diff_to_new_prev do
        if diff_to_new_prev[i] == nil then
            diff_to_new_prev[i] = first_file_line
        end
    end

    local new_to_diff_clamped = nil
    if type(file_line_count) == "number" and file_line_count > 0 then
        new_to_diff_clamped = {}
        local last_diff = nil
        for l = 1, file_line_count do
            local d = new_to_diff[l]
            if d ~= nil then
                last_diff = d
            end
            new_to_diff_clamped[l] = last_diff
        end

        local first_diff = nil
        for l = 1, file_line_count do
            if new_to_diff_clamped[l] ~= nil then
                first_diff = new_to_diff_clamped[l]
                break
            end
        end
        first_diff = first_diff or 1
        for l = 1, file_line_count do
            if new_to_diff_clamped[l] == nil then
                new_to_diff_clamped[l] = first_diff
            end
        end
    end

    return {
        has_mapping = true,
        diff_to_new_prev = diff_to_new_prev,
        new_to_diff_clamped = new_to_diff_clamped,
        diff_to_new = diff_to_new,
        new_to_diff = new_to_diff,
    }
end

local function get_state(tabpage)
    tabpage = tabpage or vim.api.nvim_get_current_tabpage()
    local state = state_by_tab[tabpage]
    if type(state) ~= "table" then
        return nil
    end
    return state
end

local function suppress_next_scroll(state, win)
    if not (state and is_valid_win(win)) then
        return
    end
    if type(state.suppress_winscrolled) ~= "table" then
        state.suppress_winscrolled = {}
    end
    state.suppress_winscrolled[win] = (state.suppress_winscrolled[win] or 0) + 1
end

local function consume_suppressed_scroll(state, win)
    if not (state and type(state.suppress_winscrolled) == "table" and is_valid_win(win)) then
        return false
    end
    local n = state.suppress_winscrolled[win]
    if type(n) ~= "number" or n <= 0 then
        return false
    end
    n = n - 1
    if n <= 0 then
        state.suppress_winscrolled[win] = nil
    else
        state.suppress_winscrolled[win] = n
    end
    return true
end

local function set_win_topline(state, win, topline)
    if not (state and is_valid_win(win)) then
        return
    end

    topline = clamp_win_topline(win, topline)
    local current = win_topline(win)
    if topline == current then
        return
    end

    suppress_next_scroll(state, win)
    pcall(vim.api.nvim_win_call, win, function()
        vim.fn.winrestview({ topline = topline })
    end)
end

local function clear_state(tabpage)
    local state = get_state(tabpage)
    if not state then
        return
    end

    local file_win = state.file_win
    if is_valid_win(file_win) and type(state.file_win_opts) == "table" then
        for opt, value in pairs(state.file_win_opts) do
            pcall(function()
                vim.wo[file_win][opt] = value
            end)
        end
    end

    if type(state.gitsigns_detached_bufs) == "table" then
        local ok, gs = pcall(require, "gitsigns")
        if ok and type(gs) == "table" then
            for buf in pairs(state.gitsigns_detached_bufs) do
                if is_valid_buf(buf) and vim.bo[buf].buftype == "" then
                    pcall(gs.attach, buf)
                end
            end
        end
    end

    if state.augroup then
        pcall(vim.api.nvim_del_augroup_by_id, state.augroup)
    end

    local diff_win = state.diff_win
    if is_valid_win(diff_win) then
        pcall(vim.api.nvim_win_close, diff_win, true)
    end

    state_by_tab[state.tabpage] = nil
end

local function ensure_diff_window(file_win)
    if not is_valid_win(file_win) then
        return nil
    end

    local state = get_state()
    if state and is_valid_win(state.diff_win) then
        return state.diff_win
    end

    local diff_win = nil
    vim.api.nvim_win_call(file_win, function()
        local ok = pcall(vim.cmd, "rightbelow vsplit")
        if not ok then
            ok = pcall(vim.cmd, "belowright split")
        end
        if not ok then
            return
        end

        diff_win = vim.api.nvim_get_current_win()
    end)

    if not is_valid_win(diff_win) then
        return nil
    end

    return diff_win
end

local function ensure_diff_buf(diff_win)
    if not is_valid_win(diff_win) then
        return nil
    end

    local state = get_state()
    if state and is_valid_buf(state.diff_buf) then
        return state.diff_buf
    end

    local buf = vim.api.nvim_create_buf(false, true)
    if not is_valid_buf(buf) then
        return nil
    end

    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].swapfile = false
    vim.bo[buf].modifiable = false
    vim.bo[buf].readonly = true
    vim.bo[buf].filetype = "diff"

    pcall(vim.api.nvim_win_set_buf, diff_win, buf)
    return buf
end

local function render_diff(state, render_lines, hl_lines, title)
    if not (state and is_valid_win(state.diff_win) and is_valid_buf(state.diff_buf)) then
        return
    end

    local buf = state.diff_buf
    local unique_title = "[git diff#" .. tostring(state.tabpage) .. "] " .. title
    pcall(vim.api.nvim_buf_set_name, buf, unique_title)
    vim.bo[buf].modifiable = true
    vim.bo[buf].readonly = false

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, render_lines)

    vim.bo[buf].modifiable = false
    vim.bo[buf].readonly = true
    vim.bo[buf].filetype = "diff"

    apply_diff_highlights(buf, hl_lines or render_lines)
end

local function refresh_for_current_buffer(state)
    if not state then
        return
    end

    if not (is_valid_win(state.file_win) and is_valid_win(state.diff_win) and is_valid_buf(state.diff_buf)) then
        clear_state()
        return
    end

    local file_buf = vim.api.nvim_win_get_buf(state.file_win)
    if not is_main_edit_buf(file_buf) then
        return
    end

    detach_gitsigns(state, file_buf)

    local path = normalize_path(vim.api.nvim_buf_get_name(file_buf))
    if not path then
        return
    end

    state.file_buf = file_buf
    state.file_path = path
    state.file_line_count = vim.api.nvim_buf_line_count(file_buf)

    local root = get_git_root(path)
    if not root then
        local lines = {
            "[git diff] Not inside a Git repository.",
        }
        state.lines = lines
        state.has_mapping = false
        state.diff_to_new_prev = nil
        state.new_to_diff_clamped = nil
        state.diff_to_new = nil
        state.new_to_diff = nil
        state.lines_raw = lines
        state.lines = lines
        render_diff(state, lines, lines, "(no repo)")
        return
    end

    local relpath = relpath_from_root(root, path)
    if not relpath then
        local lines = {
            "[git diff] Unable to determine repo-relative path.",
            path,
        }
        state.lines = lines
        state.has_mapping = false
        state.diff_to_new_prev = nil
        state.new_to_diff_clamped = nil
        state.diff_to_new = nil
        state.new_to_diff = nil
        state.lines_raw = lines
        state.lines = lines
        render_diff(state, lines, lines, "(path error)")
        return
    end

    state.git_root = root
    state.relpath = relpath

    local raw_lines, err = git_diff_lines(root, relpath, path)
    if err then
        raw_lines = {
            "[git diff] " .. err,
        }
    elseif vim.tbl_isempty(raw_lines) then
        raw_lines = {
            "[git diff] No changes for " .. relpath,
        }
    end

    state.lines_raw = raw_lines
    local render_lines = diff_display_lines(raw_lines)
    state.lines = render_lines
    local maps = build_line_maps(raw_lines, state.file_line_count)
    state.has_mapping = maps.has_mapping
    state.diff_to_new_prev = maps.diff_to_new_prev
    state.new_to_diff_clamped = maps.new_to_diff_clamped
    state.diff_to_new = maps.diff_to_new
    state.new_to_diff = maps.new_to_diff

    render_diff(state, render_lines, raw_lines, relpath)
end

local function sync_scroll(state, source_win)
    if not state then
        return
    end
    if not (is_valid_win(state.file_win) and is_valid_win(state.diff_win) and is_valid_buf(state.diff_buf)) then
        clear_state()
        return
    end

    if vim.api.nvim_get_current_tabpage() ~= state.tabpage then
        return
    end

    if not is_valid_win(source_win) then
        source_win = vim.api.nvim_get_current_win()
    end

    if source_win == state.file_win then
        local buf = vim.api.nvim_win_get_buf(state.file_win)
        if not is_main_edit_buf(buf) then
            return
        end

        if buf ~= state.file_buf then
            refresh_for_current_buffer(state)
        end

        if not state.has_mapping then
            return
        end

        local file_top = win_topline(state.file_win)
        local map = state.new_to_diff_clamped
        local diff_top = (type(map) == "table" and map[file_top]) or 1
        set_win_topline(state, state.diff_win, diff_top)
        return
    end

    if source_win == state.diff_win then
        if not state.has_mapping then
            return
        end

        local diff_top = win_topline(state.diff_win)
        local map = state.diff_to_new_prev
        local file_top = (type(map) == "table" and map[diff_top]) or 1
        set_win_topline(state, state.file_win, file_top)
    end
end

function M.open(opts)
    opts = opts or {}
    local file_win = opts.win
    if not is_valid_win(file_win) then
        file_win = find_main_edit_win() or vim.api.nvim_get_current_win()
    end

    local file_buf = vim.api.nvim_win_get_buf(file_win)
    if not is_main_edit_buf(file_buf) then
        vim.notify("Git review: no main file window found.", vim.log.levels.WARN)
        return
    end

    local diff_win = ensure_diff_window(file_win)
    if not diff_win then
        vim.notify("Git review: couldn't open diff window.", vim.log.levels.ERROR)
        return
    end

    local diff_buf = ensure_diff_buf(diff_win)
    if not diff_buf then
        vim.notify("Git review: couldn't create diff buffer.", vim.log.levels.ERROR)
        return
    end

    local tabpage = vim.api.nvim_get_current_tabpage()
    local group = vim.api.nvim_create_augroup("HumoodagenGitReview_" .. tostring(tabpage), { clear = true })

    local file_win_opts = {
        signcolumn = vim.wo[file_win].signcolumn,
        winhl = vim.wo[file_win].winhl,
    }

    local state = {
        tabpage = tabpage,
        file_win = file_win,
        file_buf = file_buf,
        diff_win = diff_win,
        diff_buf = diff_buf,
        augroup = group,
        lines = {},
        lines_raw = {},
        file_line_count = vim.api.nvim_buf_line_count(file_buf),
        has_mapping = false,
        diff_to_new_prev = nil,
        new_to_diff_clamped = nil,
        diff_to_new = nil,
        new_to_diff = nil,
        suppress_winscrolled = {},
        file_win_opts = file_win_opts,
    }
    state_by_tab[tabpage] = state

    local winhl, changed = extend_winhl(file_win_opts.winhl, gitsigns_numhl_groups, "LineNr")
    if changed then
        vim.wo[file_win].winhl = winhl
    end

    vim.wo[diff_win].number = vim.wo[file_win].number
    vim.wo[diff_win].relativenumber = vim.wo[file_win].relativenumber
    vim.wo[diff_win].numberwidth = vim.wo[file_win].numberwidth
    vim.wo[diff_win].signcolumn = vim.wo[file_win].signcolumn
    vim.wo[diff_win].foldcolumn = vim.wo[file_win].foldcolumn

    vim.api.nvim_create_autocmd({ "BufEnter" }, {
        group = group,
        callback = function()
            local state = get_state(tabpage)
            if state then
                sync_scroll(state, vim.api.nvim_get_current_win())
            end
        end,
        desc = "Git review: sync sidecar on enter",
    })

    vim.api.nvim_create_autocmd({ "WinScrolled" }, {
        group = group,
        callback = function(ev)
            local state = get_state(tabpage)
            if not state then
                return
            end
            if vim.api.nvim_get_current_tabpage() ~= state.tabpage then
                return
            end

            local win = tonumber((vim.v.event or {}).winid) or tonumber(ev.match) or tonumber(ev.file)
            if is_valid_win(win) and consume_suppressed_scroll(state, win) then
                return
            end
            sync_scroll(state, win)
        end,
        desc = "Git review: coupled scrolling",
    })

    vim.api.nvim_create_autocmd({ "CursorMoved" }, {
        group = group,
        callback = function()
            local state = get_state(tabpage)
            if not state then
                return
            end
            if vim.api.nvim_get_current_tabpage() ~= state.tabpage then
                return
            end

            local source_win = vim.api.nvim_get_current_win()
            if source_win ~= state.file_win then
                return
            end

            local buf = vim.api.nvim_win_get_buf(state.file_win)
            if not is_main_edit_buf(buf) then
                return
            end

            if buf ~= state.file_buf then
                refresh_for_current_buffer(state)
            end

            if not state.has_mapping then
                return
            end

            local info = win_cursor_info(state.file_win)
            if not info then
                return
            end

            local map = state.new_to_diff_clamped
            local diff_line = (type(map) == "table" and map[info.lnum]) or nil
            if type(diff_line) ~= "number" then
                return
            end

            local row = type(info.row) == "number" and info.row or 1
            local height = vim.api.nvim_win_get_height(state.diff_win)
            if type(height) == "number" and height > 0 then
                row = math.max(1, math.min(row, height))
            else
                row = math.max(1, row)
            end

            set_win_topline(state, state.diff_win, diff_line - (row - 1))
        end,
        desc = "Git review: keep diff aligned to cursor",
    })

    vim.api.nvim_create_autocmd({ "BufWritePost" }, {
        group = group,
        callback = function(ev)
            local state = get_state(tabpage)
            if not state then
                return
            end
            if vim.api.nvim_get_current_tabpage() ~= state.tabpage then
                return
            end
            if ev.buf == state.file_buf then
                refresh_for_current_buffer(state)
                sync_scroll(state, state.file_win)
            end
        end,
        desc = "Git review: refresh diff on save",
    })

    vim.api.nvim_create_autocmd({ "BufWipeout" }, {
        group = group,
        buffer = diff_buf,
        callback = function()
            clear_state(tabpage)
        end,
        desc = "Git review: cleanup on diff close",
    })

    vim.api.nvim_create_autocmd("ColorScheme", {
        group = group,
        callback = function()
            local state = get_state(tabpage)
            if not state then
                return
            end
            apply_diff_highlights(state.diff_buf, state.lines_raw or state.lines or {})
        end,
        desc = "Git review: refresh diff highlights on colorscheme",
    })

    refresh_for_current_buffer(state)
    sync_scroll(state, state.file_win)
end

function M.close(opts)
    opts = opts or {}
    clear_state(opts.tabpage)
end

function M.toggle(opts)
    opts = opts or {}
    local state = get_state(opts.tabpage)
    if state and is_valid_win(state.diff_win) then
        M.close(opts)
        return
    end
    M.open(opts)
end

return M
