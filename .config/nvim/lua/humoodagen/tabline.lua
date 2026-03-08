local M = {}

local tabline_group = vim.api.nvim_create_augroup("HumoodagenTabline", { clear = true })

local function is_real_file_buf(bufnr)
    if not (bufnr and vim.api.nvim_buf_is_valid(bufnr)) then
        return false
    end

    if vim.bo[bufnr].buftype ~= "" then
        return false
    end

    if vim.bo[bufnr].filetype == "NvimTree" or vim.bo[bufnr].filetype == "toggleterm" then
        return false
    end

    local name = vim.api.nvim_buf_get_name(bufnr)
    return type(name) == "string" and name ~= ""
end

local function is_directory_path(path)
    return type(path) == "string" and path ~= "" and vim.fn.isdirectory(path) == 1
end

local function set_tab_last_file(tabpage, path)
    if type(path) ~= "string" or path == "" then
        return
    end
    if is_directory_path(path) then
        return
    end
    pcall(vim.api.nvim_tabpage_set_var, tabpage, "humoodagen_last_file", path)
end

local function get_tab_last_file(tabpage)
    local ok, value = pcall(vim.api.nvim_tabpage_get_var, tabpage, "humoodagen_last_file")
    if ok and type(value) == "string" and value ~= "" then
        if is_directory_path(value) then
            return nil
        end
        return value
    end
    return nil
end

local function escape_statusline(text)
    return (text or ""):gsub("%%", "%%%%")
end

local function truncate_right(text, max_width)
    if max_width <= 0 then
        return ""
    end

    if vim.fn.strdisplaywidth(text) <= max_width then
        return text
    end

    if max_width == 1 then
        return "…"
    end

    local keep = math.max(0, max_width - 1)
    return vim.fn.strcharpart(text, 0, keep) .. "…"
end

local function pad_right(text, width)
    local w = vim.fn.strdisplaywidth(text)
    if w >= width then
        return text
    end
    return text .. string.rep(" ", width - w)
end

local function tab_label_from_path(path, width)
    if width <= 0 then
        return ""
    end

    local filename = vim.fn.fnamemodify(path, ":t")
    if filename == "" then
        filename = "[No Name]"
    end

    return truncate_right(filename, width)
end

function M.label_for_win(win, width, opts)
    opts = opts or {}
    if width <= 0 then
        return ""
    end

    if not (win and win ~= 0 and vim.api.nvim_win_is_valid(win)) then
        if opts.fallback_no_name then
            return truncate_right("[No Name]", width)
        end
        return ""
    end

    local buf = vim.api.nvim_win_get_buf(win)
    if is_real_file_buf(buf) then
        return tab_label_from_path(vim.api.nvim_buf_get_name(buf), width)
    end

    local tabpage = opts.tabpage
    if not tabpage then
        local ok_tabpage, resolved = pcall(vim.api.nvim_win_get_tabpage, win)
        if ok_tabpage then
            tabpage = resolved
        end
    end

    if opts.allow_last_file ~= false then
        local path = get_tab_last_file(tabpage)
        if type(path) == "string" and path ~= "" then
            return tab_label_from_path(path, width)
        end
    end

    if opts.fallback_no_name then
        return truncate_right("[No Name]", width)
    end

    return ""
end

local function tab_visible_text(tabpage, width, is_current)
    if width <= 0 then
        return ""
    end

    if width == 1 then
        return "…"
    end

    local label_width = math.max(0, width - 2)
    if label_width == 0 then
        return " " .. " "
    end

    local win = vim.api.nvim_tabpage_get_win(tabpage)
    local label = M.label_for_win(win, label_width, {
        tabpage = tabpage,
        allow_last_file = not is_current,
        fallback_no_name = not is_current,
    })

    label = escape_statusline(label)
    label = pad_right(label, label_width)
    return " " .. label .. " "
end

function M.render()
    local tabpages = vim.api.nvim_list_tabpages()
    local tab_count = #tabpages
    if tab_count == 0 then
        return ""
    end

    local columns = vim.o.columns
    local base = math.floor(columns / tab_count)
    local remainder = columns - (base * tab_count)

    local current = vim.api.nvim_get_current_tabpage()
    local out = {}

    for i, tabpage in ipairs(tabpages) do
        local width = base + ((i <= remainder) and 1 or 0)
        local tabnr = vim.api.nvim_tabpage_get_number(tabpage)
        local hl = (tabpage == current) and "%#TabLineSel#" or "%#TabLine#"
        local text = tab_visible_text(tabpage, width, tabpage == current)
        table.insert(out, ("%%%dT%s%s%%T"):format(tabnr, hl, text))
    end

    table.insert(out, "%#TabLineFill#")
    return table.concat(out)
end

function M.setup()
    _G.HumoodagenTabline = function()
        return M.render()
    end

    vim.o.showtabline = 2
    vim.o.tabline = "%!v:lua.HumoodagenTabline()"

    vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
        group = tabline_group,
        callback = function()
            local buf = vim.api.nvim_get_current_buf()
            if not is_real_file_buf(buf) then
                return
            end

            local tabpage = vim.api.nvim_get_current_tabpage()
            set_tab_last_file(tabpage, vim.api.nvim_buf_get_name(buf))
        end,
    })
end

return M
