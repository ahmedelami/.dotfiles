local M = {}

local function is_main_buf(buf)
    if not (buf and vim.api.nvim_buf_is_valid(buf)) then
        return false
    end
    if vim.bo[buf].buftype ~= "" then
        return false
    end
    local ft = vim.bo[buf].filetype
    return ft ~= "NvimTree" and ft ~= "toggleterm"
end

function M.find_main_win(tabpage)
    tabpage = tabpage or 0
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
        if vim.api.nvim_win_is_valid(win) then
            local cfg = vim.api.nvim_win_get_config(win)
            if cfg.relative == "" then
                local buf = vim.api.nvim_win_get_buf(win)
                if is_main_buf(buf) then
                    return win
                end
            end
        end
    end
    return nil
end

function M.ensure_main_win(tabpage)
    tabpage = tabpage or 0

    local win = M.find_main_win(tabpage)
    if win and vim.api.nvim_win_is_valid(win) then
        return win
    end

    local wins = vim.api.nvim_tabpage_list_wins(tabpage)
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

function M.focus_main()
    local win = M.ensure_main_win(0)
    if win and vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_set_current_win(win)
    end
    return win
end

return M

