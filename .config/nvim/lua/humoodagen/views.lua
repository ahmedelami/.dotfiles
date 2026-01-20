local group = vim.api.nvim_create_augroup("HumoodagenViews", { clear = true })

-- Persist folds/cursor per file via :mkview/:loadview.
-- Avoid restoring cwd from views (this config manages cwd separately).
vim.opt.viewoptions:append("cursor")
vim.opt.viewoptions:append("folds")
vim.opt.viewoptions:remove("curdir")

local function ensure_viewdir()
    local dir = vim.fn.expand(vim.o.viewdir or "")
    if dir == "" then
        return
    end
    dir = dir:gsub("/+$", "")
    if dir == "" then
        return
    end
    if vim.fn.isdirectory(dir) == 0 then
        pcall(vim.fn.mkdir, dir, "p")
    end
end

local function should_use_view(buf)
    if not (buf and vim.api.nvim_buf_is_valid(buf)) then
        return false
    end
    if vim.bo[buf].buftype ~= "" then
        return false
    end
    if vim.api.nvim_buf_get_name(buf) == "" then
        return false
    end
    return true
end

local function load_view(buf)
    if not should_use_view(buf) then
        return
    end

    if vim.b[buf].humoodagen_view_loaded then
        return
    end
    vim.b[buf].humoodagen_view_loaded = true

    ensure_viewdir()
    pcall(vim.cmd, "silent! loadview")
end

local function save_view(buf)
    if not should_use_view(buf) then
        return
    end

    ensure_viewdir()
    pcall(vim.cmd, "silent! mkview!")
end

vim.api.nvim_create_autocmd("BufWinEnter", {
    group = group,
    callback = function(ev)
        local win = vim.api.nvim_get_current_win()
        vim.schedule(function()
            if not (win and vim.api.nvim_win_is_valid(win)) then
                return
            end
            vim.api.nvim_win_call(win, function()
                if vim.api.nvim_get_current_buf() ~= ev.buf then
                    return
                end
                load_view(ev.buf)
            end)
        end)
    end,
})

vim.api.nvim_create_autocmd("BufWinLeave", {
    group = group,
    callback = function(ev)
        save_view(ev.buf)
    end,
})
