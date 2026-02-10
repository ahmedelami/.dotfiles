local group = vim.api.nvim_create_augroup("HumoodagenSession", { clear = true })

local started_empty = vim.fn.argc() == 0

local function is_disabled()
    return vim.env.HUMOODAGEN_NO_SESSION == "1" or vim.g.humoodagen_no_session == true
end

local function ensure_dir(path)
    local dir = vim.fn.fnamemodify(path, ":h")
    if dir == "" then
        return
    end
    if vim.fn.isdirectory(dir) == 0 then
        pcall(vim.fn.mkdir, dir, "p")
    end
end

local function normalize_path(path)
    if type(path) ~= "string" or path == "" then
        return ""
    end
    path = path:gsub("[/\\]+$", "")
    return path
end

local function session_root()
    local cwd = normalize_path(vim.loop.cwd() or vim.fn.getcwd())
    if cwd == "" then
        return ""
    end

    if vim.fs and type(vim.fs.find) == "function" and type(vim.fs.dirname) == "function" then
        local git = vim.fs.find(".git", { path = cwd, upward = true })[1]
        if type(git) == "string" and git ~= "" then
            local root = normalize_path(vim.fs.dirname(git))
            if root ~= "" then
                return root
            end
        end
    end

    return cwd
end

local function session_key(root)
    root = normalize_path(root)
    if root == "" then
        return nil
    end
    local ok, hash = pcall(vim.fn.sha256, root)
    if ok and type(hash) == "string" and hash ~= "" then
        return hash
    end
    return root:gsub("[^%w]+", "_")
end

local function session_paths()
    local root = session_root()
    local key = session_key(root)
    if not key then
        return nil, nil, nil
    end

    local dir = vim.fn.stdpath("state") .. "/humoodagen/sessions"
    return dir .. "/" .. key .. ".vim", dir .. "/" .. key .. ".json", root
end

local function current_tree_state()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_is_valid(win) then
            local buf = vim.api.nvim_win_get_buf(win)
            if vim.bo[buf].filetype == "NvimTree" then
                return {
                    open = true,
                    width = vim.api.nvim_win_get_width(win),
                }
            end
        end
    end
    return { open = false }
end

local function save_state(path, root, tree)
    ensure_dir(path)
    local payload = {
        root = root,
        cwd = normalize_path(vim.fn.getcwd()),
        saved_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        nvim_tree = tree,
    }
    local ok_json, json = pcall(vim.json.encode, payload)
    if not ok_json then
        return
    end
    pcall(vim.fn.writefile, { json }, path, "b")
end

local function load_state(path)
    local ok_lines, lines = pcall(vim.fn.readfile, path)
    if not ok_lines or type(lines) ~= "table" or #lines == 0 then
        return nil
    end
    local ok_json, decoded = pcall(vim.json.decode, table.concat(lines, "\n"))
    if not ok_json or type(decoded) ~= "table" then
        return nil
    end
    return decoded
end

local function has_real_buffers()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == "" then
            local name = vim.api.nvim_buf_get_name(buf)
            if type(name) == "string" and name ~= "" then
                return true
            end
        end
    end
    return false
end

local function has_terminal_panes()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_is_valid(win) then
            local buf = vim.api.nvim_win_get_buf(win)
            if vim.bo[buf].buftype == "terminal" or vim.bo[buf].filetype == "toggleterm" then
                return true
            end
        end
    end
    return false
end

local function has_meaningful_state()
    if has_real_buffers() then
        return true
    end
    if has_terminal_panes() then
        return true
    end
    return #vim.api.nvim_list_wins() > 1
end

local function should_autoload()
    if is_disabled() then
        return false
    end
    if not started_empty then
        return false
    end
    if vim.v.this_session ~= "" then
        return false
    end
    return true
end

local function close_tree_before_session()
    local tree = current_tree_state()
    if tree.open then
        pcall(vim.cmd, "silent! NvimTreeClose")
    end
    return tree
end

local function restore_tree_after_session(state)
    if type(state) ~= "table" then
        return
    end
    local tree = state.nvim_tree
    if type(tree) ~= "table" or tree.open ~= true then
        return
    end

    pcall(vim.cmd, "silent! NvimTreeOpen")

    if type(tree.width) ~= "number" or tree.width <= 0 then
        return
    end

    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.bo[buf].filetype == "NvimTree" then
            pcall(vim.api.nvim_win_set_width, win, tree.width)
            break
        end
    end
end

local function save_session(opts)
    opts = opts or {}
    if is_disabled() then
        return
    end
    if not started_empty then
        return
    end
    if not has_meaningful_state() then
        return
    end

    local session_path, state_path, root = session_paths()
    if not session_path or not state_path or not root then
        return
    end

    local tree = close_tree_before_session()
    save_state(state_path, root, tree)

    ensure_dir(session_path)
    pcall(vim.cmd, "silent! mksession! " .. vim.fn.fnameescape(session_path))

    if opts.reopen_tree and tree.open then
        restore_tree_after_session({ nvim_tree = tree })
    end
end

local function load_session()
    local session_path, state_path = session_paths()
    if not session_path or vim.fn.filereadable(session_path) == 0 then
        return
    end

    pcall(vim.cmd, "silent! source " .. vim.fn.fnameescape(session_path))
    local state = state_path and vim.fn.filereadable(state_path) == 1 and load_state(state_path) or nil
    restore_tree_after_session(state)
end

-- Session options focused on window layout + terminals.
vim.opt.sessionoptions = {
    "buffers",
    "curdir",
    "tabpages",
    "winsize",
    "resize",
    "winpos",
    "terminal",
}

vim.api.nvim_create_user_command("SessionSave", function()
    save_session({ reopen_tree = true })
    vim.notify("Session saved", vim.log.levels.INFO)
end, {})

vim.api.nvim_create_user_command("SessionLoad", function()
    load_session()
end, {})

vim.api.nvim_create_user_command("SessionDelete", function()
    local session_path, state_path = session_paths()
    if session_path then
        pcall(vim.fn.delete, session_path)
    end
    if state_path then
        pcall(vim.fn.delete, state_path)
    end
    vim.notify("Session deleted", vim.log.levels.INFO)
end, {})

vim.api.nvim_create_autocmd("VimEnter", {
    group = group,
    callback = function()
        if not should_autoload() then
            return
        end
        vim.schedule(load_session)
    end,
})

vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
        save_session()
    end,
})
