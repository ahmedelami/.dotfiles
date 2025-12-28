local fwatch = require("fwatch")

local watchers = {}

local function unwatch_path(path)
    local entry = watchers[path]
    if not entry then
        return
    end

    entry.count = entry.count - 1
    if entry.count <= 0 then
        fwatch.unwatch(entry.handle)
        watchers[path] = nil
    end
end

local function restart_watch(path)
    local entry = watchers[path]
    if not entry then
        return
    end

    fwatch.unwatch(entry.handle)
    entry.handle = fwatch.watch(path, entry.opts)
end

local function watch_path(path)
    local entry = watchers[path]
    if entry then
        entry.count = entry.count + 1
        return
    end

    local opts = {
        on_event = function(_, events)
            vim.schedule(function()
                pcall(vim.cmd, "checktime " .. vim.fn.fnameescape(path))
            end)

            if events and events.rename then
                restart_watch(path)
            end
        end,
        on_error = function(err, unwatch)
            unwatch()
            watchers[path] = nil
            vim.schedule(function()
                vim.notify("fwatch error for " .. path .. ": " .. tostring(err), vim.log.levels.WARN)
            end)
        end,
    }

    local handle = fwatch.watch(path, opts)
    watchers[path] = { handle = handle, count = 1, opts = opts }
end

local function should_watch(buf)
    if not vim.api.nvim_buf_is_valid(buf) then
        return false
    end

    if vim.api.nvim_buf_get_option(buf, "buftype") ~= "" then
        return false
    end

    local name = vim.api.nvim_buf_get_name(buf)
    if name == "" then
        return false
    end

    if vim.fn.filereadable(name) ~= 1 or vim.fn.isdirectory(name) == 1 then
        return false
    end

    return true
end

local function ensure_watch(buf)
    if not should_watch(buf) then
        return
    end

    local name = vim.api.nvim_buf_get_name(buf)
    local previous = vim.b[buf].codex_fwatch_path
    if previous == name then
        return
    end

    if previous and previous ~= "" then
        unwatch_path(previous)
    end

    watch_path(name)
    vim.b[buf].codex_fwatch_path = name
end

local function clear_watch(buf)
    local previous = vim.b[buf].codex_fwatch_path
    if previous and previous ~= "" then
        unwatch_path(previous)
    end
    vim.b[buf].codex_fwatch_path = nil
end

local group = vim.api.nvim_create_augroup("CodexFwatch", { clear = true })

vim.api.nvim_create_autocmd({ "BufReadPost", "BufFilePost", "BufWritePost" }, {
    group = group,
    callback = function(args)
        ensure_watch(args.buf)
    end,
})

vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
    group = group,
    callback = function(args)
        clear_watch(args.buf)
    end,
})

for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    ensure_watch(buf)
end
