local M = {}

local ns = vim.api.nvim_create_namespace("HumoodagenDebug")
local group = vim.api.nvim_create_augroup("HumoodagenDebug", { clear = true })

local function log_path()
    return vim.fn.stdpath("state") .. "/humoodagen-debug.log"
end

local function now()
    return os.date("%Y-%m-%d %H:%M:%S")
end

local function shorten(path)
    if type(path) ~= "string" or path == "" then
        return ""
    end
    return vim.fn.fnamemodify(path, ":~")
end

local function ctx()
    local win = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_get_current_buf()
    local mode = vim.api.nvim_get_mode().mode
    return string.format(
        "mode=%s win=%s buf=%s ft=%s bt=%s name=%s",
        mode,
        tostring(win),
        tostring(buf),
        tostring(vim.bo[buf].filetype),
        tostring(vim.bo[buf].buftype),
        shorten(vim.api.nvim_buf_get_name(buf))
    )
end

local function write(line)
    pcall(vim.fn.writefile, { line }, log_path(), "a")
end

function M.enabled()
    return vim.g.humoodagen_debug_enabled == true
end

function M.log(message)
    if not M.enabled() then
        return
    end
    write(string.format("%s %s | %s", now(), tostring(message), ctx()))
end

function M.clear()
    pcall(vim.fn.writefile, {}, log_path(), "b")
    M.log("cleared")
end

local function should_log_key(key)
    local kt = vim.fn.keytrans(key)
    if kt == "<Esc>" or kt == "<C-[>" then
        return true
    end
    if kt:find("^<D%-") then
        return true
    end
    if kt:find("^<F%d+") or kt:find("^<S%-F%d+") then
        return true
    end
    if kt:find("<C%-\\\\>") then
        return true
    end
    return false
end

function M.enable()
    if M.enabled() then
        return
    end
    vim.g.humoodagen_debug_enabled = true
    write(string.format("%s === Humoodagen debug enabled ===", now()))

    vim.on_key(function(key)
        if not M.enabled() then
            return
        end
        if should_log_key(key) then
            M.log("key " .. vim.fn.keytrans(key))
        end
    end, ns)
end

function M.disable()
    if not M.enabled() then
        return
    end
    vim.g.humoodagen_debug_enabled = false
    vim.on_key(nil, ns)
    write(string.format("%s === Humoodagen debug disabled ===", now()))
end

function M.toggle()
    if M.enabled() then
        M.disable()
    else
        M.enable()
    end
end

function M.open()
    vim.cmd("tabnew " .. vim.fn.fnameescape(log_path()))
end

function M.status()
    local t = vim.g.humoodagen_pane_mode
    local main = type(t) == "table" and t.main or nil
    local tree = type(t) == "table" and t.tree or nil
    local bottom = type(t) == "table" and t.bottom or nil
    local right = type(t) == "table" and t.right or nil
    vim.notify(string.format("debug=%s pane_mode={main=%s tree=%s bottom=%s right=%s}", tostring(M.enabled()), tostring(main), tostring(tree), tostring(bottom), tostring(right)))
end

vim.api.nvim_create_user_command("HumoodagenDebugToggle", function()
    M.toggle()
    M.status()
end, {})

vim.api.nvim_create_user_command("HumoodagenDebugOpen", function()
    M.open()
end, {})

vim.api.nvim_create_user_command("HumoodagenDebugClear", function()
    M.clear()
end, {})

vim.api.nvim_create_user_command("HumoodagenDebugStatus", function()
    M.status()
end, {})

vim.api.nvim_create_autocmd("ModeChanged", {
    group = group,
    callback = function()
        if not M.enabled() then
            return
        end
        local ev = vim.v.event or {}
        M.log(string.format("ModeChanged old=%s new=%s", tostring(ev.old_mode), tostring(ev.new_mode)))
    end,
})

vim.api.nvim_create_autocmd({ "WinEnter", "WinLeave" }, {
    group = group,
    callback = function(ev)
        if not M.enabled() then
            return
        end
        M.log(ev.event)
    end,
})

return M
