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

                local buf = vim.api.nvim_get_current_buf()
                if vim.bo[buf].buftype ~= "" or vim.bo[buf].filetype == "NvimTree" or vim.bo[buf].filetype == "toggleterm" then
                    local main_win = find_main_edit_win()
                    if main_win and vim.api.nvim_win_is_valid(main_win) then
                        vim.api.nvim_set_current_win(main_win)
                        buf = vim.api.nvim_get_current_buf()
                    end
                end

                if vim.bo[buf].buftype ~= "" or vim.api.nvim_buf_get_name(buf) == "" then
                    vim.notify("MiniDiff overlay works in a file buffer (save/open a file first).", vim.log.levels.INFO)
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
