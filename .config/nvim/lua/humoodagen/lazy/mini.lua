return {
    {
        'echasnovski/mini.nvim',
        version = false,
        config = function()
            local icons = require('mini.icons')
            icons.setup({ style = 'glyph' })
            icons.mock_nvim_web_devicons()
            icons.tweak_lsp_kind()

            local mini_pick = require('mini.pick')
            mini_pick.setup({
                mappings = { delete_left = '<C-u>', delete_word = '<C-w>' },
                window = {
                    config = function()
                        local height = math.floor(0.45 * vim.o.lines)
                        local width = math.floor(0.6 * vim.o.columns)
                        return {
                            anchor = 'NW',
                            height = height,
                            width = width,
                            row = math.floor((vim.o.lines - height) / 2) + math.floor(vim.o.lines / 6),
                            col = math.floor((vim.o.columns - width) / 2),
                            border = 'rounded',
                        }
                    end,
                },
            })

            require('mini.extra').setup()

            require('mini.diff').setup({
                -- Avoid clobbering gitsigns' hunk mappings like [h and ]h.
                mappings = {
                    apply = '',
                    reset = '',
                    textobject = '',
                    goto_first = '',
                    goto_prev = '',
                    goto_next = '',
                    goto_last = '',
                },
            })

            local pick = mini_pick.builtin
            vim.keymap.set('n', '<leader>pf', pick.files, { desc = 'Find Files' })
            vim.keymap.set('n', '<C-p>', function() pick.files({ tool = 'git' }) end, { desc = 'Git Files' })
            vim.keymap.set('n', '<leader>ps', pick.grep_live, { desc = 'Grep Project' })

            -- Unified-ish overlay diff in the current buffer.
            vim.keymap.set('n', '<C-g>', function()
                local function find_main_edit_win()
                    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
                        local cfg = vim.api.nvim_win_get_config(win)
                        if cfg.relative == "" then
                            local buf = vim.api.nvim_win_get_buf(win)
                            if vim.bo[buf].buftype == "" then
                                local ft = vim.bo[buf].filetype
                                if ft ~= "NvimTree" and ft ~= "toggleterm" then
                                    return win
                                end
                            end
                        end
                    end
                    return nil
                end

                local function get_git_root()
                    local out = vim.fn.systemlist({ "git", "rev-parse", "--show-toplevel" })
                    if vim.v.shell_error ~= 0 then
                        return nil
                    end
                    return out[1]
                end

                local function git_status_items(root)
                    local out = vim.fn.system({ "git", "-C", root, "status", "--porcelain=v1", "-z" })
                    if vim.v.shell_error ~= 0 then
                        return nil
                    end

                    local parts = vim.split(out, "\0", { plain = true })
                    local items = {}
                    local seen = {}

                    local i = 1
                    while i <= #parts do
                        local entry = parts[i]
                        if entry == "" then
                            i = i + 1
                        else
                            local status = entry:sub(1, 2)
                            local path = entry:sub(4)
                            local display_path = path

                            if status:find("R", 1, true) or status:find("C", 1, true) then
                                local new_path = parts[i + 1]
                                if new_path and new_path ~= "" then
                                    display_path = path .. " -> " .. new_path
                                    path = new_path
                                    i = i + 1
                                end
                            end

                            if path ~= "" and not seen[status .. "\0" .. path] then
                                seen[status .. "\0" .. path] = true
                                table.insert(items, {
                                    text = status .. " " .. display_path,
                                    path = root .. "/" .. path,
                                    status = status,
                                })
                            end

                            i = i + 1
                        end
                    end

                    return items
                end

                local function open_git_changes_picker(target_win)
                    local root = get_git_root()
                    if not root or root == "" then
                        vim.notify("Not inside a Git repository.", vim.log.levels.WARN)
                        return
                    end

                    local items = git_status_items(root) or {}
                    if vim.tbl_isempty(items) then
                        vim.notify("No Git changes found.", vim.log.levels.INFO)
                        return
                    end

                    mini_pick.start({
                        source = {
                            name = "Git Changes",
                            items = items,
                            choose = function(item)
                                local win = target_win
                                if not win or not vim.api.nvim_win_is_valid(win) then
                                    win = mini_pick.get_picker_state().windows.target
                                end

                                if not win or not vim.api.nvim_win_is_valid(win) then
                                    vim.notify("No valid target window to open file.", vim.log.levels.ERROR)
                                    return
                                end

                                vim.api.nvim_win_call(win, function()
                                    local path = item.path or item
                                    if type(path) ~= "string" or path == "" then
                                        vim.notify("Invalid path.", vim.log.levels.ERROR)
                                        return
                                    end

                                    if vim.fn.filereadable(path) == 0 then
                                        vim.notify("File not readable: " .. path, vim.log.levels.WARN)
                                        return
                                    end

                                    vim.cmd("edit " .. vim.fn.fnameescape(path))
                                    local buf = vim.api.nvim_get_current_buf()

                                    if MiniDiff.get_buf_data(buf) == nil then
                                        local ok_enable, err = pcall(MiniDiff.enable, buf)
                                        if not ok_enable then
                                            vim.notify("MiniDiff enable failed: " .. tostring(err), vim.log.levels.ERROR)
                                            return
                                        end
                                    end

                                    local ok_overlay, err = pcall(MiniDiff.toggle_overlay, buf)
                                    if not ok_overlay then
                                        vim.notify("MiniDiff overlay failed: " .. tostring(err), vim.log.levels.ERROR)
                                    end
                                end)
                            end,
                        },
                    })
                end

                local buf = vim.api.nvim_get_current_buf()
                if vim.bo[buf].buftype ~= "" or vim.bo[buf].filetype == "NvimTree" or vim.bo[buf].filetype == "toggleterm" then
                    local main_win = find_main_edit_win()
                    if main_win and vim.api.nvim_win_is_valid(main_win) then
                        vim.api.nvim_set_current_win(main_win)
                        buf = vim.api.nvim_get_current_buf()
                    end
                end

                if vim.bo[buf].buftype ~= "" or vim.api.nvim_buf_get_name(buf) == "" then
                    local target_win = find_main_edit_win() or vim.api.nvim_get_current_win()
                    open_git_changes_picker(target_win)
                    return
                end

                if MiniDiff.get_buf_data(buf) == nil then
                    local ok_enable, err = pcall(MiniDiff.enable, buf)
                    if not ok_enable then
                        vim.notify("MiniDiff enable failed: " .. tostring(err), vim.log.levels.ERROR)
                        return
                    end
                end

                local ok_overlay, err = pcall(MiniDiff.toggle_overlay, buf)
                if not ok_overlay then
                    vim.notify("MiniDiff overlay failed: " .. tostring(err), vim.log.levels.ERROR)
                end
            end, { desc = 'Toggle Diff Overlay' })
        end,
    },
}
