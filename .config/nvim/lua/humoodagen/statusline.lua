local M = {}

local group = vim.api.nvim_create_augroup("HumoodagenStatusline", { clear = true })

local RIGHT_FORMAT = "%l,%c%V %P"

local function escape_statusline(text)
    return (text or ""):gsub("%%", "%%%%")
end

local function is_fzf_ft(ft)
    return ft == "fzf" or ft == "fzflua_backdrop"
end

local function is_real_file_buf(buf)
    if not (buf and vim.api.nvim_buf_is_valid(buf)) then
        return false
    end

    local ft = vim.bo[buf].filetype
    if ft == "NvimTree" or ft == "toggleterm" or is_fzf_ft(ft) then
        return false
    end

    if vim.bo[buf].buftype ~= "" then
        return false
    end

    local name = vim.api.nvim_buf_get_name(buf)
    return type(name) == "string" and name ~= ""
end

local function is_directory_path(path)
    return type(path) == "string" and path ~= "" and vim.fn.isdirectory(path) == 1
end

local function get_last_file_path(tabpage)
    if not (tabpage and vim.api.nvim_tabpage_is_valid(tabpage)) then
        return nil
    end

    local ok, path = pcall(vim.api.nvim_tabpage_get_var, tabpage, "humoodagen_last_file")
    if ok and type(path) == "string" and path ~= "" then
        if is_directory_path(path) then
            return nil
        end
        return path
    end

    return nil
end

local function tree_root_path_for_win(win)
    if not (win and win ~= 0 and vim.api.nvim_win_is_valid(win)) then
        return nil
    end

    local ok, cwd = pcall(vim.api.nvim_win_call, win, function()
        return vim.fn.getcwd()
    end)
    if ok and type(cwd) == "string" and cwd ~= "" then
        return cwd
    end

    local fallback = vim.loop.cwd()
    if type(fallback) == "string" and fallback ~= "" then
        return fallback
    end

    return nil
end

local function get_statusline_path(statusline_win)
    if not (statusline_win and statusline_win ~= 0 and vim.api.nvim_win_is_valid(statusline_win)) then
        statusline_win = vim.api.nvim_get_current_win()
    end

    local buf = vim.api.nvim_win_get_buf(statusline_win)
    if is_real_file_buf(buf) then
        return vim.api.nvim_buf_get_name(buf)
    end

    if buf and vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == "NvimTree" then
        local tree_root = tree_root_path_for_win(statusline_win)
        if type(tree_root) == "string" and tree_root ~= "" then
            return tree_root
        end
    end

    local ok_tabpage, tabpage = pcall(vim.api.nvim_win_get_tabpage, statusline_win)
    if ok_tabpage then
        local path = get_last_file_path(tabpage)
        if type(path) == "string" and path ~= "" then
            return path
        end
    end

    return ""
end

function M.setup()
    _G.HumoodagenStatusline = function()
        local statusline_win = vim.g.statusline_winid
        if not (statusline_win and statusline_win ~= 0 and vim.api.nvim_win_is_valid(statusline_win)) then
            statusline_win = vim.api.nvim_get_current_win()
        end

        local left = escape_statusline(get_statusline_path(statusline_win))
        local ok, out = pcall(vim.api.nvim_eval_statusline, RIGHT_FORMAT, {
            winid = statusline_win,
            maxwidth = vim.o.columns,
        })
        local right = ""
        if ok and type(out) == "table" and type(out.str) == "string" then
            right = escape_statusline(out.str)
        end

        if left == "" then
            return "%=" .. right
        end

        return "%<" .. left .. "%=" .. right
    end

    vim.opt.statusline = "%!v:lua.HumoodagenStatusline()"

    vim.api.nvim_create_autocmd("FileType", {
        group = group,
        pattern = { "fzf", "fzflua_backdrop" },
        callback = function(ev)
            local buf = ev.buf
            local function apply()
                for _, win in ipairs(vim.fn.win_findbuf(buf)) do
                    if win and win ~= 0 and vim.api.nvim_win_is_valid(win) then
                        vim.wo[win].statusline = "%!v:lua.HumoodagenStatusline()"
                    end
                end
            end

            apply()
            vim.schedule(apply)
            vim.defer_fn(apply, 20)
            vim.defer_fn(apply, 100)
        end,
        desc = "Use the main statusline in fzf windows",
    })
end

return M
