local M = {}

local ns = vim.api.nvim_create_namespace("HumoodagenModeCursor")
local state = {
    buf = nil,
    id = nil,
}

local place

local redraw_scheduled = false
local function schedule_redraw()
    if redraw_scheduled then
        return
    end
    redraw_scheduled = true
    vim.schedule(function()
        redraw_scheduled = false
        pcall(vim.cmd, "redraw")
    end)
end

local place_scheduled = false
local scheduled_any = false
local scheduled_bufs = {}
local function schedule_place(buf)
    if buf == nil then
        scheduled_any = true
    else
        scheduled_bufs[buf] = true
    end
    if place_scheduled then
        return
    end
    place_scheduled = true
    vim.schedule(function()
        place_scheduled = false
        local any = scheduled_any
        scheduled_any = false
        local bufs = scheduled_bufs
        scheduled_bufs = {}
        if not any and not bufs[vim.api.nvim_get_current_buf()] then
            return
        end
        place()
        schedule_redraw()
    end)
end

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

place = function(mode_override)
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

    if mode == "nt" and vim.bo[buf].filetype == "toggleterm" then
        local desired = vim.b[buf].humoodagen_term_mode
        if vim.b[buf].humoodagen_term_restore_active or (type(desired) == "string" and desired:sub(1, 1) == "t") then
            mode = "t"
        end
    end

    if type(mode) == "string" and mode:sub(1, 1) == "i" then
        vim.g.humoodagen_main_restore_cursor_override = nil
    elseif type(mode) == "string"
        and mode:sub(1, 1) == "n"
        and vim.g.humoodagen_main_restore_cursor_override ~= nil
        and vim.bo[buf].buftype == ""
        and vim.bo[buf].filetype ~= "toggleterm"
        and vim.bo[buf].filetype ~= "NvimTree"
    then
        local pane = vim.g.humoodagen_pane_mode
        local desired_main = type(pane) == "table" and pane.main or nil
        if type(desired_main) == "string" and desired_main:sub(1, 1) == "i" then
            mode = "i"
        end
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
        local byte = line:byte(col + 1)
        if byte == 9 then
            -- Highlighting a tab spans its full visual width, which can look like
            -- a huge cursor. Draw a 1-cell overlay at the cursor's on-screen
            -- column (Neovim places the cursor at the end of the tab).
            local win_col = vim.fn.virtcol(".") - 1
            local view = vim.fn.winsaveview()
            local leftcol = type(view) == "table" and type(view.leftcol) == "number" and view.leftcol or 0
            win_col = math.max(0, win_col - leftcol)
            opts = {
                virt_text = { { " ", hl } },
                virt_text_pos = "overlay",
                virt_text_win_col = win_col,
                priority = 5000,
            }
        else
            opts = { end_col = col + 1, hl_group = hl, hl_mode = "replace", priority = 5000 }
        end
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
            schedule_redraw()
        end,
        desc = "Update per-mode cursor block immediately",
    })

    -- Terminal output can rewrite the current prompt/line without firing cursor
    -- movement events. Attach to terminal buffers so we can keep the fake cursor
    -- highlight in sync and avoid "ghost blocks" left behind.
    vim.api.nvim_create_autocmd("TermOpen", {
        group = group,
        callback = function(ev)
            local buf = ev.buf
            if not (buf and vim.api.nvim_buf_is_valid(buf)) then
                return
            end
            if vim.b[buf].humoodagen_mode_cursor_attached then
                return
            end

            vim.b[buf].humoodagen_mode_cursor_attached = true
            pcall(vim.api.nvim_buf_attach, buf, false, {
                on_lines = function(_, changed_buf)
                    schedule_place(changed_buf)
                end,
                on_detach = function(_, detached_buf)
                    if detached_buf and vim.api.nvim_buf_is_valid(detached_buf) then
                        vim.b[detached_buf].humoodagen_mode_cursor_attached = nil
                    end
                end,
            })
        end,
        desc = "Track terminal redraws for cursor block highlight",
    })

    vim.api.nvim_create_autocmd({
        "CursorMoved",
        "CursorMovedI",
        "WinEnter",
        "BufEnter",
        "CmdlineLeave",
        "ColorScheme",
    }, {
        group = group,
        callback = function()
            schedule_place()
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
