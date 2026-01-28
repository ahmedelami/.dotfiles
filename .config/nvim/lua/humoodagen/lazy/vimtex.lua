return {
    "lervag/vimtex",
    ft = { "tex", "plaintex" },
    init = function()
        vim.g.vimtex_view_method = "general"
        vim.g.vimtex_compiler_method = "latexmk"
        -- Don't auto-open the quickfix window on compile warnings/errors; keep
        -- the pane layout stable and rely on notifications / manual `\\le`.
        vim.g.vimtex_quickfix_mode = 0
        vim.g.vimtex_quickfix_open_on_warning = 0
    end,
    config = function()
        local uv = vim.uv or vim.loop
        local group = vim.api.nvim_create_augroup("HumoodagenVimtexCompileNotify", { clear = true })
        local state = {}

        local function notify(msg, level, opts)
            opts = opts or {}

            if vim.g.neovide then
                local ok_fidget, fidget = pcall(require, "fidget")
                if not ok_fidget then
                    local ok_lazy, lazy = pcall(require, "lazy")
                    if ok_lazy then
                        pcall(lazy.load, { plugins = { "fidget.nvim" } })
                        ok_fidget, fidget = pcall(require, "fidget")
                    end
                end

                if ok_fidget and type(fidget.notify) == "function" then
                    local key = opts.replace
                    if key == nil then
                        key = ("vimtex:%d"):format(uv.hrtime())
                    end

                    local ttl = nil
                    if opts.timeout == false then
                        ttl = math.huge
                    elseif type(opts.timeout) == "number" then
                        ttl = opts.timeout / 1000
                    end

                    fidget.notify(msg, level, {
                        key = key,
                        annote = opts.title or "VimTeX",
                        ttl = ttl,
                    })
                    return key
                end
            end

            local ok, n = pcall(require, "notify")
            if not ok then
                local ok_lazy, lazy = pcall(require, "lazy")
                if ok_lazy then
                    pcall(lazy.load, { plugins = { "nvim-notify" } })
                    ok, n = pcall(require, "notify")
                end
            end

            if ok then
                return n(msg, level, opts)
            end

            return vim.notify(msg, level, opts)
        end

        local function tex_main()
            local tex = (vim.b.vimtex and vim.b.vimtex.tex) or vim.fn.expand("%:p")
            if type(tex) ~= "string" or tex == "" then
                return nil
            end
            return tex
        end

        local function tex_tail(tex)
            if type(tex) ~= "string" or tex == "" then
                return vim.fn.expand("%:t")
            end
            return vim.fn.fnamemodify(tex, ":t")
        end

        local function fmt_duration(start_ns)
            if not start_ns then
                return nil
            end
            local sec = (uv.hrtime() - start_ns) / 1e9
            if sec < 0 then
                return nil
            end
            if sec < 10 then
                return string.format("%.1fs", sec)
            end
            return string.format("%ds", math.floor(sec + 0.5))
        end

        local function entry_for(main)
            if not state[main] then
                state[main] = {}
            end
            return state[main]
        end

        local function set_status(main, status)
            if type(main) ~= "string" or main == "" then
                return
            end
            local entry = entry_for(main)
            entry.status = status
            entry.status_at = uv.hrtime()
            vim.schedule(function()
                pcall(vim.cmd, "redrawstatus")
            end)
        end

        _G.HumoodagenVimtexCompileBadge = function()
            local main = tex_main()
            if not main then
                return ""
            end
            local entry = state[main]
            if not entry or not entry.status then
                return ""
            end

            local label = entry.status
            if label == "running" then
                label = "running"
            elseif label == "compiling" then
                label = "compiling"
            elseif label == "compiled" then
                label = "compiled"
            elseif label == "failed" then
                label = "failed"
            elseif label == "stopped" then
                label = "stopped"
            end

            if entry.last_duration then
                return ("  [TeX: %s %s]"):format(label, entry.last_duration)
            end
            return ("  [TeX: %s]"):format(label)
        end

        local winbar_group = vim.api.nvim_create_augroup("HumoodagenVimtexWinbar", { clear = true })
        vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter", "WinEnter", "FileType" }, {
            group = winbar_group,
            callback = function()
                local buf = vim.api.nvim_get_current_buf()
                if vim.bo[buf].buftype ~= "" then
                    return
                end
                local ft = vim.bo[buf].filetype
                if ft ~= "tex" and ft ~= "plaintex" then
                    return
                end
                vim.wo.winbar = " %<%t%{%v:lua.HumoodagenVimtexCompileBadge()%}"
            end,
        })

        vim.api.nvim_create_autocmd("User", {
            group = group,
            pattern = "VimtexEventCompileStarted",
            callback = function()
                local main = tex_main()
                if not main then
                    return
                end
                local entry = entry_for(main)
                entry.start_ns = uv.hrtime()
                entry.last_duration = nil
                set_status(main, "running")
                entry.notification = notify(("LaTeX: compiling %s"):format(tex_tail(main)), vim.log.levels.INFO, {
                    title = "VimTeX",
                    timeout = false,
                    replace = entry.notification,
                })
            end,
        })

        vim.api.nvim_create_autocmd("User", {
            group = group,
            pattern = "VimtexEventCompiling",
            callback = function()
                local main = tex_main()
                if not main then
                    return
                end
                local entry = entry_for(main)
                entry.start_ns = entry.start_ns or uv.hrtime()
                entry.last_duration = nil
                set_status(main, "compiling")
            end,
        })

        vim.api.nvim_create_autocmd("User", {
            group = group,
            pattern = "VimtexEventCompileSuccess",
            callback = function()
                local main = tex_main()
                if not main then
                    return
                end
                local entry = entry_for(main)
                local duration = fmt_duration(entry.start_ns)
                entry.start_ns = nil
                entry.last_duration = duration
                set_status(main, "compiled")
                local msg = ("LaTeX: compiled %s"):format(tex_tail(main))
                if duration then
                    msg = ("%s (%s)"):format(msg, duration)
                end
                entry.notification = notify(msg, vim.log.levels.INFO, {
                    title = "VimTeX",
                    timeout = 2000,
                    replace = entry.notification,
                })
            end,
        })

        vim.api.nvim_create_autocmd("User", {
            group = group,
            pattern = "VimtexEventCompileFailed",
            callback = function()
                local main = tex_main()
                if not main then
                    return
                end
                local entry = entry_for(main)
                local duration = fmt_duration(entry.start_ns)
                entry.start_ns = nil
                entry.last_duration = duration
                set_status(main, "failed")
                local msg = ("LaTeX: failed %s (\\lo)"):format(tex_tail(main))
                if duration then
                    msg = ("%s (%s)"):format(msg, duration)
                end
                entry.notification = notify(msg, vim.log.levels.ERROR, {
                    title = "VimTeX",
                    timeout = 4000,
                    replace = entry.notification,
                })
            end,
        })

        vim.api.nvim_create_autocmd("User", {
            group = group,
            pattern = "VimtexEventCompileStopped",
            callback = function()
                local main = tex_main()
                if not main then
                    return
                end
                local entry = entry_for(main)
                entry.start_ns = nil
                set_status(main, "stopped")
                entry.notification = notify(("LaTeX: stopped %s"):format(tex_tail(main)), vim.log.levels.WARN, {
                    title = "VimTeX",
                    timeout = 2000,
                    replace = entry.notification,
                })
            end,
        })
    end,
}
