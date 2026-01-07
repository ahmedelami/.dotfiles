local M = {}

local ns = vim.api.nvim_create_namespace("HumoodagenModeCursor")
local state = {
    buf = nil,
    id = nil,
}

local function mode_to_hl(mode)
    if type(mode) ~= "string" or mode == "" then
        return "HumoodagenModeCursorNormal"
    end

    local first = mode:sub(1, 1)
    if first == "i" or first == "t" then
        return "HumoodagenModeCursorInsert"
    end
    if first == "R" then
        return "HumoodagenModeCursorReplace"
    end
    if first == "v" or mode == "V" or mode == "\022" then
        return "HumoodagenModeCursorVisual"
    end

    return "HumoodagenModeCursorNormal"
end

local function should_show(buf)
    if not (buf and vim.api.nvim_buf_is_valid(buf)) then
        return false
    end

    local bt = vim.bo[buf].buftype
    if bt ~= "" and bt ~= "terminal" then
        return false
    end

    local ft = vim.bo[buf].filetype
    if ft == "NvimTree" or ft == "TelescopePrompt" or ft == "lazy" then
        return false
    end

    return true
end

local function clear()
    if state.buf and state.id and vim.api.nvim_buf_is_valid(state.buf) then
        pcall(vim.api.nvim_buf_del_extmark, state.buf, ns, state.id)
    end
    state.buf = nil
    state.id = nil
end

local function place(mode_override)
    if #vim.api.nvim_list_uis() == 0 then
        return
    end

    local mode = mode_override or vim.api.nvim_get_mode().mode
    if type(mode) == "string" and mode:sub(1, 1) == "c" then
        clear()
        return
    end

    local win = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_win_get_buf(win)
    if not should_show(buf) then
        clear()
        return
    end

    local cursor = vim.api.nvim_win_get_cursor(win)
    local row = cursor[1] - 1
    local col = cursor[2]

    local hl = mode_to_hl(mode)

    if state.buf and state.buf ~= buf then
        clear()
    elseif state.buf == buf and state.id then
        pcall(vim.api.nvim_buf_del_extmark, buf, ns, state.id)
        state.id = nil
    end

    local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, true)[1] or ""
    local opts
    if col < #line then
        opts = { end_col = col + 1, hl_group = hl, hl_mode = "replace", priority = 5000 }
    else
        opts = {
            virt_text = { { " ", hl } },
            virt_text_pos = "overlay",
            priority = 5000,
        }
    end

    state.id = vim.api.nvim_buf_set_extmark(buf, ns, row, col, opts)
    state.buf = buf
end

function M.setup()
    local group = vim.api.nvim_create_augroup("HumoodagenModeCursor", { clear = true })

    vim.api.nvim_create_autocmd("ModeChanged", {
        group = group,
        callback = function()
            place(vim.v.event and vim.v.event.new_mode or nil)
            pcall(vim.cmd, "redraw")
        end,
        desc = "Update per-mode cursor block immediately",
    })

    vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "WinEnter", "BufEnter", "CmdlineLeave", "ColorScheme" }, {
        group = group,
        callback = function()
            place()
        end,
        desc = "Draw a per-mode cursor block using buffer highlights (instant)",
    })

    vim.api.nvim_create_autocmd({ "WinLeave", "BufLeave", "CmdlineEnter" }, {
        group = group,
        callback = clear,
        desc = "Clear the per-mode cursor block",
    })

    place()
end

return M
