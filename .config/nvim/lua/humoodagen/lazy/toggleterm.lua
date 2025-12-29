return {
    "akinsho/toggleterm.nvim",
    version = "*",
    config = function()
        require("toggleterm").setup({
            start_in_insert = true,
            persist_size = true,
            direction = "horizontal",
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
        local bottom_term = Terminal:new({ direction = "horizontal", hidden = true })
        local right_term = Terminal:new({ direction = "vertical", hidden = true })

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
            if buftype == "terminal" or filetype == "toggleterm" then
                return false
            end
            local cfg = vim.api.nvim_win_get_config(win)
            if cfg.relative ~= "" then
                return false
            end
            return true
        end

        local last_main_win = nil

        local nav_group = vim.api.nvim_create_augroup("ToggleTermNav", { clear = true })
        vim.api.nvim_create_autocmd({ "WinEnter", "BufEnter" }, {
            group = nav_group,
            callback = function()
                local win = vim.api.nvim_get_current_win()
                if is_main_win(win) then
                    last_main_win = win
                end
            end,
        })

        vim.api.nvim_create_autocmd("BufEnter", {
            group = nav_group,
            callback = function()
                local buf = vim.api.nvim_get_current_buf()
                if vim.bo[buf].filetype == "toggleterm" then
                    vim.cmd("startinsert")
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

        local function open_horizontal_in_main(term)
            local size = ui._resolve_size(ui.get_size(nil, term.direction), term)
            local target_win = find_main_win()
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
            if term.on_open then term:on_open() end
        end

        local function toggle_bottom_terminal(term)
            if term:is_open() then
                term:close()
                return
            end

            open_horizontal_in_main(term)
        end

        local function toggle_terminal(term, opts)
            local mode = vim.api.nvim_get_mode().mode
            local mode_prefix = mode:sub(1, 1)
            if mode_prefix == "t" then
                vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true), "n", false)
            elseif mode_prefix == "c" then
                vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-c>", true, false, true), "n", false)
            end

            local target_win = nil
            if opts and opts.prefer_main then
                target_win = find_main_win()
            end

            vim.schedule(function()
                if target_win and vim.api.nvim_win_is_valid(target_win) then
                    vim.api.nvim_set_current_win(target_win)
                end
                local direction = term.direction
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
            if mode_prefix == "t" then
                vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true), "n", false)
            elseif mode_prefix == "c" then
                vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-c>", true, false, true), "n", false)
            end
            vim.schedule(fn)
        end

        local function focus_main_win()
            local target = last_main_win
            if target and vim.api.nvim_win_is_valid(target) then
                vim.api.nvim_set_current_win(target)
                return true
            end

            target = find_main_win()
            if target and vim.api.nvim_win_is_valid(target) then
                vim.api.nvim_set_current_win(target)
                return true
            end

            return false
        end

        local function focus_term_window(term)
            if term.window and vim.api.nvim_win_is_valid(term.window) then
                vim.api.nvim_set_current_win(term.window)
                vim.cmd("startinsert")
                return true
            end

            if term.bufnr and vim.api.nvim_buf_is_valid(term.bufnr) then
                for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
                    if vim.api.nvim_win_get_buf(win) == term.bufnr then
                        vim.api.nvim_set_current_win(win)
                        vim.cmd("startinsert")
                        return true
                    end
                end
            end

            return false
        end

        local function open_or_focus_bottom()
            run_in_normal(function()
                if focus_term_window(bottom_term) then
                    return
                end

                open_horizontal_in_main(bottom_term)
                vim.cmd("startinsert")
            end)
        end

        local function open_or_focus_right()
            run_in_normal(function()
                if focus_term_window(right_term) then
                    return
                end

                local target = last_main_win
                if not (target and vim.api.nvim_win_is_valid(target)) then
                    target = find_main_win()
                end
                if target and vim.api.nvim_win_is_valid(target) then
                    vim.api.nvim_set_current_win(target)
                end

                with_directional_open_windows("vertical", function()
                    right_term:open()
                end)
                vim.cmd("startinsert")
            end)
        end

        local function focus_left()
            run_in_normal(function()
                local win = vim.api.nvim_get_current_win()
                if is_main_win(win) then
                    vim.cmd("wincmd h")
                else
                    focus_main_win()
                end
            end)
        end

        local function focus_right()
            open_or_focus_right()
        end

        local function focus_down()
            open_or_focus_bottom()
        end

        local function focus_up()
            run_in_normal(function()
                local win = vim.api.nvim_get_current_win()
                if is_main_win(win) then
                    vim.cmd("wincmd k")
                else
                    focus_main_win()
                end
            end)
        end

        local all_modes = { "n", "i", "v", "x", "s", "o", "t", "c" }
        vim.keymap.set(all_modes, "<F14>", function()
            toggle_bottom_terminal(bottom_term)
        end, { desc = "Toggle bottom terminal" })
        vim.keymap.set(all_modes, "<F13>", function()
            toggle_terminal(right_term, { prefer_main = true })
        end, { desc = "Toggle right terminal" })
        vim.keymap.set(all_modes, "<F16>", function()
            toggle_bottom_terminal(bottom_term)
        end, { desc = "Toggle bottom terminal (Cmd+B)" })
        vim.keymap.set(all_modes, "<F15>", function()
            toggle_terminal(right_term, { prefer_main = true })
        end, { desc = "Toggle right terminal (Cmd+R)" })
        vim.keymap.set(all_modes, "<S-F7>", function()
            toggle_bottom_terminal(bottom_term)
        end, { desc = "Toggle bottom terminal (Cmd+B fallback)" })
        vim.keymap.set(all_modes, "<S-F5>", function()
            toggle_terminal(right_term, { prefer_main = true })
        end, { desc = "Toggle right terminal (Cmd+R fallback)" })
        vim.keymap.set(all_modes, "<F18>", function()
            toggle_bottom_terminal(bottom_term)
        end, { desc = "Toggle bottom terminal (Cmd+B fallback)" })
        vim.keymap.set(all_modes, "<F17>", function()
            toggle_terminal(right_term, { prefer_main = true })
        end, { desc = "Toggle right terminal (Cmd+R fallback)" })
        vim.keymap.set(all_modes, "<S-F4>", function()
            toggle_bottom_terminal(bottom_term)
        end, { desc = "Toggle bottom terminal (Cmd+B)" })
        vim.keymap.set(all_modes, "<S-F3>", function()
            toggle_terminal(right_term, { prefer_main = true })
        end, { desc = "Toggle right terminal (Cmd+R)" })

        local esc = "\x1b"
        vim.keymap.set(all_modes, "<D-h>", focus_left, { desc = "Focus left (Cmd+H)" })
        vim.keymap.set(all_modes, "<D-j>", focus_down, { desc = "Focus down (Cmd+J)" })
        vim.keymap.set(all_modes, "<D-k>", focus_up, { desc = "Focus up (Cmd+K)" })
        vim.keymap.set(all_modes, "<D-l>", focus_right, { desc = "Focus right (Cmd+L)" })
        vim.keymap.set(all_modes, "<F55>", focus_left, { desc = "Focus left (Cmd+H ghostty)" })
        vim.keymap.set(all_modes, "<F56>", focus_down, { desc = "Focus down (Cmd+J ghostty)" })
        vim.keymap.set(all_modes, "<F57>", focus_up, { desc = "Focus up (Cmd+K ghostty)" })
        vim.keymap.set(all_modes, "<F58>", focus_right, { desc = "Focus right (Cmd+L ghostty)" })
        vim.keymap.set(all_modes, esc .. "[18;3~", focus_left, { desc = "Focus left (Cmd+H ghostty)" })
        vim.keymap.set(all_modes, esc .. "[19;3~", focus_down, { desc = "Focus down (Cmd+J ghostty)" })
        vim.keymap.set(all_modes, esc .. "[20;3~", focus_up, { desc = "Focus up (Cmd+K ghostty)" })
        vim.keymap.set(all_modes, esc .. "[21;3~", focus_right, { desc = "Focus right (Cmd+L ghostty)" })
        vim.keymap.set(all_modes, esc .. "[18;9~", focus_left, { desc = "Focus left (Cmd+H ghostty fallback)" })
        vim.keymap.set(all_modes, esc .. "[19;9~", focus_down, { desc = "Focus down (Cmd+J ghostty fallback)" })
        vim.keymap.set(all_modes, esc .. "[20;9~", focus_up, { desc = "Focus up (Cmd+K ghostty fallback)" })
        vim.keymap.set(all_modes, esc .. "[21;9~", focus_right, { desc = "Focus right (Cmd+L ghostty fallback)" })

        vim.api.nvim_create_autocmd("FileType", {
            pattern = "toggleterm",
            callback = function()
                vim.opt_local.statusline = " "
                vim.opt_local.winbar = ""
            end,
        })
    end,
}
