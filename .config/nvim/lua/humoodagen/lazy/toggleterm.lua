return {
    "akinsho/toggleterm.nvim",
    version = "*",
    config = function()
        require("toggleterm").setup({
            start_in_insert = true,
            persist_size = true,
            shade_terminals = false,
            direction = "horizontal",
            -- Toggleterm shells are not "real" outer terminals; prevent our zshrc
            -- from auto-attaching to tmux inside them (which feels like it
            -- "inherits" an external terminal).
            env = { DISABLE_TMUX_AUTO = "1" },
            size = function(term)
                if term.direction == "horizontal" then
                    return 15
                end
                if term.direction == "vertical" then
                    return math.floor(vim.o.columns * 0.3)
                end
                return 15
            end,
        })

        local term_module = require("toggleterm.terminal")
        local ui = require("toggleterm.ui")
        local Terminal = term_module.Terminal
        local debug = require("humoodagen.debug")
        local term_sets = {
            horizontal = { terms = {}, current = 1 },
            vertical = { terms = {}, current = 1 },
        }
        local base_laststatus = vim.o.laststatus
        local base_statusline = vim.go.statusline

        local pending_term_exit = {}

        local function cancel_pending_term_exit(buf)
            if not (buf and pending_term_exit[buf]) then
                return
            end
            pending_term_exit[buf] = nil
            if vim.api.nvim_buf_is_valid(buf) then
                vim.b[buf].humoodagen_term_exit_pending = nil
            end
            debug.log("term_exit_pending canceled buf=" .. tostring(buf))
        end

        local function schedule_term_mode_nt(buf)
            if not (buf and vim.api.nvim_buf_is_valid(buf)) then
                return
            end
            cancel_pending_term_exit(buf)
            local token = tostring(vim.loop.hrtime())
            pending_term_exit[buf] = token
            vim.b[buf].humoodagen_term_exit_pending = token
            debug.log("term_mode schedule <- nt source=term_exit buf=" .. tostring(buf))
            vim.defer_fn(function()
                if not vim.api.nvim_buf_is_valid(buf) then
                    return
                end
                if pending_term_exit[buf] ~= token then
                    return
                end
                pending_term_exit[buf] = nil
                vim.b[buf].humoodagen_term_exit_pending = nil
                vim.b[buf].humoodagen_term_mode = "nt"
                debug.log("term_mode <- nt source=term_exit_deferred buf=" .. tostring(buf))
            end, 50)
        end

        _G.HumoodagenCancelToggletermPendingExit = function()
            cancel_pending_term_exit(vim.api.nvim_get_current_buf())
        end

        local function restore_term_mode(term)
            local buf = vim.api.nvim_get_current_buf()
            if vim.bo[buf].filetype ~= "toggleterm" then
                return
            end

            local desired = vim.b[buf].humoodagen_term_mode
            if type(desired) ~= "string" or desired == "" then
                desired = "t"
            end

            local want_job = desired:sub(1, 1) == "t"
            if want_job then
                local win = vim.api.nvim_get_current_win()
                local token = tostring(vim.loop.hrtime())
                local deadline = vim.loop.hrtime() + 500 * 1e6
                vim.b[buf].humoodagen_term_restore_token = token
                vim.b[buf].humoodagen_term_restore_active = true

                local function stop(reason)
                    if not vim.api.nvim_buf_is_valid(buf) then
                        return
                    end
                    if vim.b[buf].humoodagen_term_restore_token ~= token then
                        return
                    end
                    vim.b[buf].humoodagen_term_restore_token = nil
                    vim.b[buf].humoodagen_term_restore_active = nil
                    if reason then
                        debug.log("term_restore done reason=" .. reason .. " desired=" .. desired)
                    end
                end

                local function attempt(tag)
                    if not vim.api.nvim_win_is_valid(win) then
                        stop("invalid_win")
                        return
                    end
                    if vim.api.nvim_get_current_win() ~= win then
                        stop("win_changed")
                        return
                    end
                    if vim.api.nvim_get_current_buf() ~= buf then
                        stop("buf_changed")
                        return
                    end
                    if vim.bo[buf].filetype ~= "toggleterm" then
                        stop("not_toggleterm")
                        return
                    end
                    if vim.b[buf].humoodagen_term_restore_token ~= token then
                        return
                    end

                    local mode = vim.api.nvim_get_mode().mode
                    if mode:sub(1, 1) == "t" then
                        stop("already_t")
                        return
                    end

                    local desired_now = vim.b[buf].humoodagen_term_mode
                    if type(desired_now) ~= "string" or desired_now == "" then
                        desired_now = "t"
                    end
                    if desired_now:sub(1, 1) ~= "t" then
                        stop("desired=" .. desired_now)
                        return
                    end

                    if vim.b[buf].humoodagen_term_exit_pending ~= nil then
                        stop("exit_pending")
                        return
                    end

                    if vim.loop.hrtime() > deadline then
                        stop("timeout")
                        return
                    end

                    if mode:sub(1, 1) == "n" then
                        debug.log("term_restore startinsert(" .. tag .. ") desired=" .. desired)
                        pcall(vim.cmd, "startinsert")
                    end

                    vim.defer_fn(function()
                        attempt("defer10")
                    end, 10)
                end

                vim.schedule(function()
                    attempt("schedule")
                end)
                return
            end

            local mode = vim.api.nvim_get_mode().mode
            if mode == "t" then
                debug.log("term_restore to_normal desired=" .. desired)
                vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true), "n", false)
            end
        end

        local function set_toggleterm_status_hl()
            vim.api.nvim_set_hl(0, "HumoodagenToggletermTabActive", { fg = "#ffffff", bg = "#005eff", bold = true })
            vim.api.nvim_set_hl(0, "HumoodagenToggletermTabInactive", { fg = "#000000", bg = "#d6d6d6", bold = true })
        end

        local function fix_toggleterm_inactive_statusline(buf)
            if not (buf and vim.api.nvim_buf_is_valid(buf)) then
                return
            end
            if vim.bo[buf].filetype ~= "toggleterm" then
                return
            end

            local num = vim.b[buf].toggle_number
            if not num then
                return
            end

            vim.api.nvim_set_hl(0, ("ToggleTerm%sStatusLineNC"):format(num), { bg = "NONE" })
        end

        local function fix_all_toggleterm_inactive_statuslines()
            for _, buf in ipairs(vim.api.nvim_list_bufs()) do
                if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == "toggleterm" then
                    fix_toggleterm_inactive_statusline(buf)
                end
            end
        end

        set_toggleterm_status_hl()
        fix_all_toggleterm_inactive_statuslines()
        vim.api.nvim_create_autocmd("ColorScheme", {
            callback = function()
                set_toggleterm_status_hl()
                fix_all_toggleterm_inactive_statuslines()
            end,
        })

        local function is_toggleterm_buf(buf)
            if not (buf and vim.api.nvim_buf_is_valid(buf)) then
                return false
            end
            if vim.bo[buf].filetype == "toggleterm" then
                return true
            end
            if vim.bo[buf].buftype == "terminal" and vim.b[buf].toggle_number ~= nil then
                return true
            end
            return false
        end

        local border_char = (vim.opt.fillchars:get() or {}).horiz or "─"
        local border_cache = {}

        _G.HumoodagenPaneBorderStatusline = function()
            local win = vim.g.statusline_winid
            if not (win and win ~= 0 and vim.api.nvim_win_is_valid(win)) then
                return ""
            end

            local buf = vim.api.nvim_win_get_buf(win)
            if vim.bo[buf].buftype ~= "" then
                return ""
            end

            local ft = vim.bo[buf].filetype
            if ft == "toggleterm" or ft == "NvimTree" then
                return ""
            end

            local width = vim.api.nvim_win_get_width(win)
            if width < 1 then
                return ""
            end

            if border_cache[width] == nil then
                border_cache[width] = "%#WinSeparator#" .. string.rep(border_char, width) .. "%#Normal#"
            end

            return border_cache[width]
        end

        local function any_toggleterm_window()
            for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
                for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
                    local buf = vim.api.nvim_win_get_buf(win)
                    if is_toggleterm_buf(buf) then
                        return true
                    end
                end
            end
            return false
        end

        local function ensure_toggleterm_statuslines()
            for _, win in ipairs(vim.api.nvim_list_wins()) do
                if vim.api.nvim_win_is_valid(win) then
                    local buf = vim.api.nvim_win_get_buf(win)
                    if is_toggleterm_buf(buf) then
                        vim.wo[win].statusline = "%!v:lua.HumoodagenToggletermStatusline()"
                        vim.wo[win].winbar = ""
                    elseif vim.bo[buf].buftype == "" and vim.bo[buf].filetype ~= "NvimTree" then
                        -- Use a border-like statusline in normal buffers so the
                        -- split above the bottom terminal stays visible.
                        vim.wo[win].statusline = "%!v:lua.HumoodagenPaneBorderStatusline()"
                        vim.wo[win].winbar = ""
                    end
                end
            end
        end

        local function update_laststatus()
            if any_toggleterm_window() then
                -- Use per-window statuslines so each ToggleTerm pane can render its
                -- own tab bar (horizontal and vertical terminals).
                vim.o.laststatus = 2
                vim.go.statusline = " "
                ensure_toggleterm_statuslines()
            else
                vim.o.laststatus = base_laststatus
                vim.go.statusline = base_statusline
            end
        end

        local function ensure_term_set(direction)
            local set = term_sets[direction]
            if not set then
                set = { terms = {}, current = 1 }
                term_sets[direction] = set
            end
            return set
        end

        local function remove_term_from_set(term)
            if not term or not term.direction then
                return
            end

            local set = term_sets[term.direction]
            if not set then
                return
            end

            for idx, t in ipairs(set.terms) do
                if t == term or (t.id and term.id and t.id == term.id) then
                    table.remove(set.terms, idx)
                    if set.current > idx then
                        set.current = set.current - 1
                    elseif set.current == idx then
                        if #set.terms == 0 then
                            set.current = 1
                        elseif idx > #set.terms then
                            set.current = #set.terms
                        else
                            set.current = idx
                        end
                    end
                    return
                end
            end
        end

        local open_or_focus_term = nil

        local function attach_tab_lifecycle(term)
            if not term or term.__humoodagen_tab_lifecycle then
                return term
            end

            term.__humoodagen_tab_lifecycle = true
            local prev_on_exit = term.on_exit

            term.on_exit = function(t, job, exit_code, name)
                local was_current = t.bufnr and vim.api.nvim_get_current_buf() == t.bufnr
                local direction = t.direction

                if prev_on_exit then
                    pcall(prev_on_exit, t, job, exit_code, name)
                end

                vim.schedule(function()
                    remove_term_from_set(t)
                    local set = direction and term_sets[direction] or nil
                    if was_current and set and #set.terms > 0 and open_or_focus_term then
                        local next_term = set.terms[set.current] or set.terms[1]
                        if next_term then
                            open_or_focus_term(next_term)
                        end
                    end
                    sync_toggleterm_inactive_highlight()
                    vim.cmd("redrawstatus")
                    update_laststatus()
                end)
            end

            return term
        end

        local function create_term(direction)
            return attach_tab_lifecycle(Terminal:new({ direction = direction, hidden = true }))
        end

        local float_term = nil

        local function ensure_float_term()
            if float_term then
                return float_term
            end

            float_term = attach_tab_lifecycle(Terminal:new({
                direction = "float",
                hidden = true,
                float_opts = {
                    border = "rounded",
                    width = math.floor(vim.o.columns * 0.85),
                    height = math.floor(vim.o.lines * 0.75),
                    winblend = 0,
                },
                on_open = function(term)
                    if term and term.bufnr and vim.api.nvim_buf_is_valid(term.bufnr) then
                        vim.b[term.bufnr].humoodagen_term_cwd_sync = true
                    end
                    if term and term.job_id then
                        -- Ensure Zsh emits OSC 7 when cwd changes so Neovim can
                        -- follow `cd`/`z` and keep NvimTree in sync.
                        term:send([[
if [ -n "$ZSH_VERSION" ] && [ -z "$HUMOODAGEN_OSC7_READY" ]; then export HUMOODAGEN_OSC7_READY=1; autoload -Uz add-zsh-hook; __humoodagen_osc7(){ printf '\033]7;file://%s%s\033\\' "${HOST:-localhost}" "$PWD"; }; add-zsh-hook chpwd __humoodagen_osc7; add-zsh-hook precmd __humoodagen_osc7; __humoodagen_osc7; fi
]])
                    end
                end,
            }))

            return float_term
        end

        local function ensure_first_term(direction)
            local set = ensure_term_set(direction)
            if #set.terms == 0 then
                table.insert(set.terms, create_term(direction))
                set.current = 1
            end
            return set
        end

        local function current_term(direction)
            local set = ensure_first_term(direction)
            local index = set.current or 1
            if index < 1 then
                index = 1
            end
            if index > #set.terms then
                index = #set.terms
            end
            set.current = index
            return set.terms[index]
        end

        local function new_term_tab_for_direction(direction)
            local set = ensure_first_term(direction)
            local term = create_term(direction)
            table.insert(set.terms, term)
            set.current = #set.terms
            return term
        end

        local function term_tab_at(direction, index)
            local set = ensure_first_term(direction)
            if not index or index < 1 or index > #set.terms then
                return nil
            end
            set.current = index
            return set.terms[index]
        end

        local function current_toggleterm()
            local buf = vim.api.nvim_get_current_buf()
            if vim.bo[buf].filetype ~= "toggleterm" then
                return nil
            end
            local term_id = vim.b[buf].toggle_number
            if not term_id then
                return nil
            end
            return term_module.get(term_id, true)
        end

	        local function sync_current_term_from_buf()
	            local term = current_toggleterm()
	            if not term or not term.direction then
	                return
            end

            attach_tab_lifecycle(term)
            local set = ensure_term_set(term.direction)
            for idx, t in ipairs(set.terms) do
                if t == term or (t.id and term.id and t.id == term.id) then
                    set.current = idx
                    return
                end
            end

	            table.insert(set.terms, term)
	            set.current = #set.terms
	        end
	
	        local function with_directional_open_windows(direction, fn)
	            local original = ui.find_open_windows
	            ui.find_open_windows = function(comparator)
	                local has_open, windows = original(comparator)
	                if not has_open then
	                    return false, windows
	                end
	                local filtered = {}
	                for _, win in ipairs(windows) do
	                    local term = term_module.get(win.term_id, true)
	                    if term and term.direction == direction then
	                        table.insert(filtered, win)
	                    end
	                end
	                return #filtered > 0, filtered
	            end
	
	            local ok, err = pcall(fn)
	            ui.find_open_windows = original
	            if not ok then
	                error(err)
	            end
	        end
	
	        local function is_main_win(win)
	            if not win or not vim.api.nvim_win_is_valid(win) then
	                return false
	            end
	            local buf = vim.api.nvim_win_get_buf(win)
	            local buftype = vim.bo[buf].buftype
	            local filetype = vim.bo[buf].filetype
	            if buftype == "terminal" or filetype == "toggleterm" or filetype == "NvimTree" then
	                return false
	            end
	            local cfg = vim.api.nvim_win_get_config(win)
	            if cfg.relative ~= "" then
	                return false
	            end
	            return true
	        end
	
	        local last_main_win = nil
	
	        local function parse_winhighlight(value)
	            local map = {}
	            if type(value) ~= "string" or value == "" then
	                return map
	            end
	            for entry in value:gmatch("[^,]+") do
	                local from, to = entry:match("^([^:]+):(.+)$")
	                if from and to then
	                    map[from] = to
	                end
	            end
	            return map
	        end
	
	        local function build_winhighlight(map)
	            local parts = {}
	            for from, to in pairs(map) do
	                table.insert(parts, from .. ":" .. to)
	            end
	            table.sort(parts)
	            return table.concat(parts, ",")
	        end
	
	        local function normalize_toggleterm_winhighlight(value)
	            local map = parse_winhighlight(value)
	            local normal = map.Normal or "Normal"
	            map.NormalNC = normal
	            map.TermNormal = normal
	            map.TermNormalNC = normal
	            map.CursorLine = "Normal"
	            map.CursorLineNr = "LineNr"
	            map.StatusLine = "Normal"
	            map.StatusLineNC = "Normal"
	            return build_winhighlight(map)
	        end
	
	        local function sync_toggleterm_inactive_highlight()
	            for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
	                local buf = vim.api.nvim_win_get_buf(win)
	                if is_toggleterm_buf(buf) then
	                    vim.wo[win].cursorline = false
	                    local current_wh = vim.wo[win].winhighlight or ""
	                    local normalized = normalize_toggleterm_winhighlight(current_wh)
	                    if normalized ~= current_wh then
	                        vim.wo[win].winhighlight = normalized
	                    end
	                end
	            end
	        end
	
	        local nav_group = vim.api.nvim_create_augroup("ToggleTermNav", { clear = true })
	        vim.api.nvim_create_autocmd({ "WinEnter", "BufEnter" }, {
	            group = nav_group,
	            callback = function()
	                local win = vim.api.nvim_get_current_win()
	                if is_main_win(win) then
	                    last_main_win = win
	                end
	                sync_toggleterm_inactive_highlight()
	                vim.schedule(update_laststatus)
	            end,
	        })
	
	        vim.api.nvim_create_autocmd("ModeChanged", {
	            group = nav_group,
	            callback = function()
	                sync_toggleterm_inactive_highlight()
	            end,
	        })

	        vim.api.nvim_create_autocmd("TermOpen", {
	            group = nav_group,
	            callback = function(ev)
	                local buf = ev.buf
	                if not is_toggleterm_buf(buf) then
	                    return
	                end

	                sync_toggleterm_inactive_highlight()
	                vim.schedule(update_laststatus)
	            end,
	        })
	
	        vim.api.nvim_create_autocmd({ "WinEnter", "BufEnter" }, {
	            group = nav_group,
	            callback = function()
	                local buf = vim.api.nvim_get_current_buf()
	                if is_toggleterm_buf(buf) then
	                    sync_current_term_from_buf()
	                    vim.opt_local.statusline = "%!v:lua.HumoodagenToggletermStatusline()"
	                    vim.opt_local.winbar = ""
	                    vim.wo.cursorline = false
	                    fix_toggleterm_inactive_statusline(buf)
	                    local stored = vim.b[buf].humoodagen_term_mode
	                    if type(stored) ~= "string" or stored == "" then
	                        vim.b[buf].humoodagen_term_mode = "t"
	                    end
	                    local term = current_toggleterm()
	                    restore_term_mode(term)
	                    vim.schedule(sync_toggleterm_inactive_highlight)
	
	                    local desired = vim.b[buf].humoodagen_term_mode
	                    if type(desired) == "string" and desired:sub(1, 1) == "n" then
	                        local cursor = vim.b[buf].humoodagen_term_nt_cursor
	                        if type(cursor) == "table" and #cursor == 2 then
	                            local win = vim.api.nvim_get_current_win()
	                            local function restore_cursor(tag)
	                                if not vim.api.nvim_win_is_valid(win) then
	                                    return
	                                end
	                                if vim.api.nvim_get_current_win() ~= win then
	                                    return
	                                end
	                                if vim.api.nvim_get_current_buf() ~= buf then
	                                    return
	                                end
	                                if vim.bo[buf].filetype ~= "toggleterm" then
	                                    return
	                                end
	                                if vim.api.nvim_get_mode().mode:sub(1, 1) ~= "n" then
	                                    return
	                                end
	
	                                local line_count = vim.api.nvim_buf_line_count(buf)
	                                local row = math.min(math.max(1, cursor[1]), line_count)
	                                local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, true)[1] or ""
	                                local max_col = #line > 0 and (#line - 1) or 0
	                                local col = math.min(math.max(0, cursor[2]), max_col)
	                                debug.log(string.format("term_nt_cursor restore(%s) row=%d col=%d", tag, row, col))
	                                pcall(vim.api.nvim_win_set_cursor, win, { row, col })
	                            end
	
	                            vim.schedule(function()
	                                restore_cursor("schedule")
	                            end)
	                            vim.defer_fn(function()
	                                restore_cursor("defer10")
	                            end, 10)
	                            vim.defer_fn(function()
	                                restore_cursor("defer50")
	                            end, 50)
	                        end
	                    end
	                end
	            end,
	        })

        vim.api.nvim_create_autocmd("WinLeave", {
            group = nav_group,
            callback = function()
                local buf = vim.api.nvim_get_current_buf()
                if vim.bo[buf].filetype == "toggleterm" then
                    vim.wo.cursorline = false
                    local mode = vim.api.nvim_get_mode().mode
                    if mode:sub(1, 1) == "n" then
                        local ok, cursor = pcall(vim.api.nvim_win_get_cursor, 0)
                        if ok and type(cursor) == "table" and #cursor == 2 then
                            vim.b[buf].humoodagen_term_nt_cursor = cursor
                            debug.log(string.format("term_nt_cursor save row=%d col=%d", cursor[1], cursor[2]))
                        end
                    end
                end
            end,
        })

        local function find_main_win()
            for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
                if is_main_win(win) then
                    return win
                end
            end
            return nil
        end

        local function find_tree_win()
            for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
                local buf = vim.api.nvim_win_get_buf(win)
                if vim.bo[buf].filetype == "NvimTree" then
                    return win
                end
            end
            return nil
        end

        local function ensure_main_win()
            local existing = find_main_win()
            if existing and vim.api.nvim_win_is_valid(existing) then
                last_main_win = existing
                return existing
            end

            local wins = vim.api.nvim_tabpage_list_wins(0)
            if #wins == 0 then
                return nil
            end

            local anchor = find_tree_win() or wins[1]
            if anchor and vim.api.nvim_win_is_valid(anchor) then
                vim.api.nvim_set_current_win(anchor)
            end

            vim.cmd("vsplit")
            vim.cmd("enew")
            local new_win = vim.api.nvim_get_current_win()
            last_main_win = new_win
            return new_win
        end

        local function safe_close_term(term)
            if not term or not term.is_open or not term:is_open() then
                return
            end

            local origin_tab = vim.api.nvim_get_current_tabpage()
            local origin_win = vim.api.nvim_get_current_win()
            ui.set_origin_window()

            local win = term.window
            if win and vim.api.nvim_win_is_valid(win) then
                local tab = vim.api.nvim_win_get_tabpage(win)
                local wins = vim.api.nvim_tabpage_list_wins(tab)
                if #wins <= 1 then
                    vim.api.nvim_set_current_tabpage(tab)
                    vim.api.nvim_set_current_win(win)
                    vim.cmd("vsplit")
                    vim.cmd("enew")
                    last_main_win = vim.api.nvim_get_current_win()
                    vim.api.nvim_set_current_tabpage(origin_tab)
                    if origin_win and vim.api.nvim_win_is_valid(origin_win) then
                        vim.api.nvim_set_current_win(origin_win)
                    end
                end
            end

            pcall(function()
                term:close()
            end)
        end

        local function open_horizontal_in_main(term)
            local size = ui._resolve_size(ui.get_size(nil, term.direction), term)
            local target_win = find_main_win()
            if not (target_win and vim.api.nvim_win_is_valid(target_win)) then
                target_win = ensure_main_win()
            end
            if target_win and vim.api.nvim_win_is_valid(target_win) then
                vim.api.nvim_set_current_win(target_win)
            end

            ui.set_origin_window()
            vim.cmd("rightbelow split")
            ui.resize_split(term, size)

            local win = vim.api.nvim_get_current_win()
            local valid_buf = term.bufnr and vim.api.nvim_buf_is_valid(term.bufnr)
            local bufnr = valid_buf and term.bufnr or ui.create_buf()
            vim.api.nvim_win_set_buf(win, bufnr)
            term.window, term.bufnr = win, bufnr
            term:__set_options()

            if not valid_buf then
                term:spawn()
            else
                ui.switch_buf(bufnr)
            end

	            ui.hl_term(term)
	            vim.schedule(sync_toggleterm_inactive_highlight)
	            if term.on_open then term:on_open() end
	        end

        local function toggle_bottom_terminal(term)
            if term:is_open() then
                safe_close_term(term)
                return
            end

            local set = term_sets[term.direction]
            if set then
                for _, other in pairs(set.terms) do
                    if other ~= term and other:is_open() then
                        safe_close_term(other)
                    end
                end
            end

            open_horizontal_in_main(term)
        end

        local function toggle_terminal(term, opts)
            local mode = vim.api.nvim_get_mode().mode
            local mode_prefix = mode:sub(1, 1)
            if mode_prefix == "c" then
                vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-c>", true, false, true), "n", false)
            end

            local should_open = not term:is_open()

            vim.schedule(function()
                if opts and opts.prefer_main then
                    local target = last_main_win
                    if not (target and vim.api.nvim_win_is_valid(target) and is_main_win(target)) then
                        target = find_main_win()
                    end
                    if not (target and vim.api.nvim_win_is_valid(target)) then
                        target = ensure_main_win()
                    end
                    if target and vim.api.nvim_win_is_valid(target) then
                        vim.api.nvim_set_current_win(target)
                    end
                end
                local direction = term.direction
                if should_open then
                    local set = term_sets[direction]
                    if set then
                        for _, other in pairs(set.terms) do
                            if other ~= term and other:is_open() then
                                safe_close_term(other)
                            end
                        end
                    end
                end
                if direction then
                    with_directional_open_windows(direction, function()
                        term:toggle()
                    end)
                else
                    term:toggle()
                end
            end)
        end

        local function run_in_normal(fn)
            local mode = vim.api.nvim_get_mode().mode
            local mode_prefix = mode:sub(1, 1)
            local was_term_job = mode_prefix == "t"
            if mode_prefix == "t" then
                local buf = vim.api.nvim_get_current_buf()
                if vim.bo[buf].filetype == "toggleterm" then
                    vim.b[buf].humoodagen_term_mode = "t"
                    cancel_pending_term_exit(buf)
                end
            elseif mode_prefix == "c" then
                vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-c>", true, false, true), "n", false)
            end
            vim.schedule(function()
                local ok, err = pcall(fn)
                if was_term_job then
                    local buf = vim.api.nvim_get_current_buf()
                    if vim.bo[buf].filetype == "toggleterm" then
                        vim.cmd("startinsert")
                    end
                end
                if not ok then
                    error(err)
                end
            end)
        end

        local function focus_main_win()
            local target = last_main_win
            if target and vim.api.nvim_win_is_valid(target) and is_main_win(target) then
                vim.api.nvim_set_current_win(target)
                return true
            end

            target = find_main_win()
            if target and vim.api.nvim_win_is_valid(target) then
                vim.api.nvim_set_current_win(target)
                return true
            end

            target = ensure_main_win()
            if target and vim.api.nvim_win_is_valid(target) then
                vim.api.nvim_set_current_win(target)
                return true
            end

            return false
        end

        local function focus_term_window(term)
            if term.window and vim.api.nvim_win_is_valid(term.window) then
                vim.api.nvim_set_current_win(term.window)
                restore_term_mode(term)
                return true
            end

            if term.bufnr and vim.api.nvim_buf_is_valid(term.bufnr) then
                for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
                    if vim.api.nvim_win_get_buf(win) == term.bufnr then
                        vim.api.nvim_set_current_win(win)
                        restore_term_mode(term)
                        return true
                    end
                end
            end

            return false
        end

        open_or_focus_term = function(term)
            if focus_term_window(term) then
                vim.cmd("redrawstatus")
                return
            end

            local set = term_sets[term.direction]
            if set then
                for _, other in pairs(set.terms) do
                    if other ~= term and other:is_open() then
                        safe_close_term(other)
                    end
                end
            end

            if term.direction == "horizontal" then
                open_horizontal_in_main(term)
            elseif term.direction == "vertical" then
                focus_main_win()

                with_directional_open_windows("vertical", function()
                    term:open()
                end)
	            else
	                term:open()
	            end
	
	            vim.schedule(sync_toggleterm_inactive_highlight)
	            restore_term_mode(term)
	            vim.cmd("redrawstatus")
	        end

        local function open_or_focus_bottom()
            run_in_normal(function()
                open_or_focus_term(current_term("horizontal"))
            end)
        end

        local function open_or_focus_right()
            run_in_normal(function()
                open_or_focus_term(current_term("vertical"))
            end)
        end

        local function new_term_tab()
            run_in_normal(function()
                local term = current_toggleterm()
                if not term or not term.direction then
                    return
                end
                local new_term = new_term_tab_for_direction(term.direction)
                open_or_focus_term(new_term)
                vim.cmd("redrawstatus")
            end)
        end

        local function switch_term_tab(index)
            run_in_normal(function()
                local term = current_toggleterm()
                if not term or not term.direction then
                    return
                end
                local target = term_tab_at(term.direction, index)
                if not target then
                    return
                end
                open_or_focus_term(target)
                vim.cmd("redrawstatus")
            end)
        end

        local main_only_state = nil

        local function any_term_open(direction)
            local set = term_sets[direction]
            if not set then
                return false
            end
            for _, t in ipairs(set.terms) do
                if t and t:is_open() then
                    return true
                end
            end
            return false
        end

        local function close_terms(direction)
            local set = term_sets[direction]
            if not set then
                return
            end
            for _, t in ipairs(set.terms) do
                if t and t:is_open() then
                    safe_close_term(t)
                end
            end
        end

        local function toggle_main_only()
            run_in_normal(function()
                focus_main_win()
                local ok_tree, tree = pcall(require, "nvim-tree.api")
                local tree_visible = ok_tree and tree.tree.is_visible() or false
                local bottom_open = any_term_open("horizontal")
                local right_open = any_term_open("vertical")

                if not main_only_state then
                    main_only_state = {
                        tree = tree_visible,
                        bottom = bottom_open,
                        right = right_open,
                    }

                    if ok_tree and tree_visible then
                        tree.tree.close()
                    end
                    close_terms("horizontal")
                    close_terms("vertical")
                    focus_main_win()
                    vim.cmd("redrawstatus")
                    return
                end

                local state = main_only_state
                main_only_state = nil

                if ok_tree and state.tree then
                    tree.tree.open({ focus = false })
                end
                if state.bottom then
                    toggle_bottom_terminal(current_term("horizontal"))
                end
                if state.right then
                    toggle_terminal(current_term("vertical"), { prefer_main = true })
                end

                focus_main_win()
                vim.cmd("redrawstatus")
            end)
        end

        _G.HumoodagenPanes = {
            jump_bottom = open_or_focus_bottom,
            jump_right = open_or_focus_right,
            jump_main = function()
                run_in_normal(function()
                    focus_main_win()
                    local buf = vim.api.nvim_get_current_buf()
                    if vim.bo[buf].buftype ~= "" then
                        return
                    end
                    if vim.api.nvim_buf_get_name(buf) ~= "" then
                        return
                    end
                    if vim.bo[buf].modified then
                        return
                    end
                    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
                    for _, line in ipairs(lines) do
                        if line ~= "" then
                            return
                        end
                    end
                    vim.cmd("startinsert")
                end)
            end,
            toggle_bottom = function()
                local origin_win = vim.api.nvim_get_current_win()
                local origin_mode = vim.api.nvim_get_mode().mode

                local term = current_term("horizontal")
                local opening = not term:is_open()
                toggle_bottom_terminal(term)

                if opening then
                    if origin_win and vim.api.nvim_win_is_valid(origin_win) then
                        vim.api.nvim_set_current_win(origin_win)
                        if origin_mode:sub(1, 1) == "i" then
                            local buf = vim.api.nvim_win_get_buf(origin_win)
                            if vim.bo[buf].buftype == "" and vim.bo[buf].filetype ~= "NvimTree" and vim.bo[buf].filetype ~= "toggleterm" then
                                vim.cmd("startinsert")
                            end
                        end
                    else
                        focus_main_win()
                    end
                end
            end,
            toggle_right = function()
                local origin_win = vim.api.nvim_get_current_win()
                local origin_mode = vim.api.nvim_get_mode().mode

                local term = current_term("vertical")
                if term:is_open() then
                    local closing_current = term.window and origin_win and term.window == origin_win
                    safe_close_term(term)
                    if closing_current then
                        focus_main_win()
                    end
                    vim.cmd("redrawstatus")
                    return
                end

                local set = term_sets[term.direction]
                if set then
                    for _, other in ipairs(set.terms) do
                        if other ~= term and other:is_open() then
                            safe_close_term(other)
                        end
                    end
                end

                focus_main_win()

                with_directional_open_windows("vertical", function()
                    term:open()
                end)

                if origin_win and vim.api.nvim_win_is_valid(origin_win) then
                    vim.api.nvim_set_current_win(origin_win)
                    if origin_mode:sub(1, 1) == "i" then
                        local buf = vim.api.nvim_win_get_buf(origin_win)
                        if vim.bo[buf].buftype == "" and vim.bo[buf].filetype ~= "NvimTree" and vim.bo[buf].filetype ~= "toggleterm" then
                            vim.cmd("startinsert")
                        end
                    end
                else
                    focus_main_win()
                end

                vim.cmd("redrawstatus")
            end,
            toggle_float = function()
                run_in_normal(function()
                    local term = ensure_float_term()
                    toggle_terminal(term, { prefer_main = true })
                end)
            end,
            toggle_main_only = toggle_main_only,
        }

        local startup_group = vim.api.nvim_create_augroup("HumoodagenToggletermStartup", { clear = true })
        local function open_startup_terminals()
            if #vim.api.nvim_list_uis() == 0 then
                return
            end
            if vim.g.humoodagen_startup_terminals_opened then
                return
            end
            vim.g.humoodagen_startup_terminals_opened = true

            run_in_normal(function()
                local desired_cwd = vim.loop.cwd()
                local repos = vim.fn.expand("~/repos")
                if vim.fn.isdirectory(repos) == 1 then
                    local real_repos = vim.loop.fs_realpath(repos)
                    if real_repos and real_repos == desired_cwd then
                        -- Use the symlink path so shells show `~/repos` in the prompt.
                        desired_cwd = repos
                    end
                end

                local origin_win = vim.api.nvim_get_current_win()
                local origin_mode = vim.api.nvim_get_mode().mode

                local function has_open_direction(direction)
                    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
                        local buf = vim.api.nvim_win_get_buf(win)
                        if vim.bo[buf].filetype == "toggleterm" then
                            local id = vim.b[buf].toggle_number
                            if id then
                                local t = term_module.get(id, true)
                                if t and t.direction == direction and t:is_open() then
                                    return true
                                end
                            end
                        end
                    end
                    return false
                end

                local right = current_term("vertical")
                if right then
                    right.dir = desired_cwd
                end
                if right and not has_open_direction("vertical") and not right:is_open() then
                    local set = term_sets[right.direction]
                    if set then
                        for _, other in ipairs(set.terms) do
                            if other ~= right and other:is_open() then
                                safe_close_term(other)
                            end
                        end
                    end

                    focus_main_win()
                    with_directional_open_windows("vertical", function()
                        right:open()
                    end)
                end

                local bottom = current_term("horizontal")
                if bottom then
                    bottom.dir = desired_cwd
                end
                if bottom and not has_open_direction("horizontal") and not bottom:is_open() then
                    toggle_bottom_terminal(bottom)
                end

                if origin_win and vim.api.nvim_win_is_valid(origin_win) then
                    vim.api.nvim_set_current_win(origin_win)
                    if origin_mode:sub(1, 1) == "i" then
                        local buf = vim.api.nvim_win_get_buf(origin_win)
                        if vim.bo[buf].buftype == "" and vim.bo[buf].filetype ~= "NvimTree" and vim.bo[buf].filetype ~= "toggleterm" then
                            vim.cmd("startinsert")
                        end
                    end
                else
                    local tree_win = find_tree_win()
                    if tree_win and vim.api.nvim_win_is_valid(tree_win) then
                        vim.api.nvim_set_current_win(tree_win)
                    else
                        focus_main_win()
                    end
                end

                -- Opening terminals can leave Neovide in Insert-mode even after we
                -- restore focus back to the tree/main window. Always start the UI
                -- in Normal mode.
                local final_mode = vim.api.nvim_get_mode().mode
                local final_prefix = type(final_mode) == "string" and final_mode:sub(1, 1) or ""
                if final_prefix == "t" then
                    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true), "n", false)
                elseif final_prefix == "i" or final_prefix == "R" then
                    vim.cmd("stopinsert")
                end

                vim.cmd("redrawstatus")
                update_laststatus()
            end)
        end

        vim.api.nvim_create_autocmd("VimEnter", {
            group = startup_group,
            callback = function()
                vim.schedule(open_startup_terminals)
            end,
        })

        local function term_for_win(winid)
            if not winid or winid == 0 then
                winid = vim.api.nvim_get_current_win()
            end
            if not vim.api.nvim_win_is_valid(winid) then
                return nil
            end
            local buf = vim.api.nvim_win_get_buf(winid)
            if vim.bo[buf].filetype ~= "toggleterm" then
                return nil
            end
            local term_id = vim.b[buf].toggle_number
            if not term_id then
                return nil
            end
            return term_module.get(term_id, true)
        end

        _G.HumoodagenToggletermStatusline = function()
            local term = term_for_win(vim.g.statusline_winid)
            if not term or not term.direction then
                return ""
            end

            attach_tab_lifecycle(term)
            local set = ensure_term_set(term.direction)

            local current = nil
            for idx, t in ipairs(set.terms) do
                if t == term or (t.id and term.id and t.id == term.id) then
                    current = idx
                    break
                end
            end
            if not current then
                table.insert(set.terms, term)
                current = #set.terms
            end

            set.current = current
            local total = #set.terms
            if total == 0 then
                return ""
            end

            local inactive_hl = "%#HumoodagenToggletermTabInactive#"
            local active_hl = "%#HumoodagenToggletermTabActive#"

            local parts = { inactive_hl }
            for i = 1, total do
                if i == current then
                    table.insert(parts, active_hl)
                    table.insert(parts, tostring(i))
                    table.insert(parts, inactive_hl)
                else
                    table.insert(parts, tostring(i))
                end

                if i < total then
                    table.insert(parts, "|")
                end
            end

            -- Ensure the unused statusline fill uses Normal so it doesn't inherit
            -- StatusLine/StatusLineNC highlights.
            table.insert(parts, "%#Normal#")
            return table.concat(parts)
        end

        local function set_term_tab_keymaps(buf)
            if vim.b[buf].humoodagen_term_tab_keymaps_set then
                return
            end
            vim.b[buf].humoodagen_term_tab_keymaps_set = true

            local opts = { buffer = buf, silent = true }
            vim.keymap.set("t", "<Esc>", function()
                -- If we have pending input (like the rest of a Cmd sequence), don't set 'nt'.
                -- This prevents Cmd+keys (which send Esc+...) from flipping the mode.
                local has_pending = vim.fn.getchar(1) ~= 0
                if not has_pending and (vim.g.humoodagen_suppress_toggleterm_mode_capture or 0) == 0 then
                    if vim.g.neovide then
                        schedule_term_mode_nt(buf)
                    else
                        vim.b[buf].humoodagen_term_mode = "nt"
                        debug.log("term_mode <- nt source=term_esc buf=" .. tostring(buf))
                    end
                end
                vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true), "n", false)
            end, vim.tbl_extend("force", opts, { desc = "Terminal normal mode (Esc)" }))
            vim.keymap.set("t", "<C-[>", function()
                local has_pending = vim.fn.getchar(1) ~= 0
                if not has_pending and (vim.g.humoodagen_suppress_toggleterm_mode_capture or 0) == 0 then
                    if vim.g.neovide then
                        schedule_term_mode_nt(buf)
                    else
                        vim.b[buf].humoodagen_term_mode = "nt"
                        debug.log("term_mode <- nt source=term_ctrl_[ buf=" .. tostring(buf))
                    end
                end
                vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true), "n", false)
            end, vim.tbl_extend("force", opts, { desc = "Terminal normal mode (Ctrl-[)" }))
            vim.keymap.set("n", "i", function()
                vim.b[buf].humoodagen_term_mode = "t"
                cancel_pending_term_exit(buf)
                debug.log("term_mode <- t source=term_i buf=" .. tostring(buf))
                vim.cmd("startinsert")
            end, vim.tbl_extend("force", opts, { desc = "Terminal insert mode (i)" }))
            vim.keymap.set("n", "a", function()
                vim.b[buf].humoodagen_term_mode = "t"
                cancel_pending_term_exit(buf)
                debug.log("term_mode <- t source=term_a buf=" .. tostring(buf))
                vim.cmd("startinsert")
            end, vim.tbl_extend("force", opts, { desc = "Terminal insert mode (a)" }))
            vim.keymap.set({ "t", "n" }, "<C-b>t", new_term_tab, vim.tbl_extend("force", opts, { desc = "Toggleterm new tab" }))
            vim.keymap.set({ "t", "n" }, "<D-t>", new_term_tab, vim.tbl_extend("force", opts, { desc = "Toggleterm new tab (Cmd+T)" }))
            for i = 1, 9 do
                vim.keymap.set({ "t", "n" }, "<C-b>" .. i, function()
                    switch_term_tab(i)
                end, vim.tbl_extend("force", opts, { desc = "Toggleterm tab " .. i }))
                vim.keymap.set({ "t", "n" }, "<D-" .. i .. ">", function()
                    switch_term_tab(i)
                end, vim.tbl_extend("force", opts, { desc = "Toggleterm tab " .. i .. " (Cmd+" .. i .. ")" }))
            end
        end

        vim.api.nvim_create_autocmd("FileType", {
            pattern = "toggleterm",
            callback = function(args)
                vim.opt_local.statusline = "%!v:lua.HumoodagenToggletermStatusline()"
                vim.opt_local.winbar = ""
                set_term_tab_keymaps(args.buf)
            end,
        })

        -- Fallback for cases where the buffer already has `filetype=toggleterm`
        -- before the `FileType` autocmd runs (or for restored buffers).
        vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
            callback = function(args)
                local buf = args.buf
                if vim.bo[buf].filetype == "toggleterm" then
                    set_term_tab_keymaps(buf)
                end
            end,
        })

        vim.api.nvim_create_autocmd({ "WinClosed", "BufWinEnter", "BufWinLeave", "TabEnter" }, {
            callback = function()
                update_laststatus()
            end,
        })
    end,
}
