return {
    {
        'echasnovski/mini.nvim',
        version = false,
        config = function()
            require('mini.icons').setup()

            local mini_files = require('mini.files')
            mini_files.setup({
                windows = { preview = true, width_focus = 30, width_preview = 30 },
                options = { use_as_default_explorer = true },
            })

            local mini_pick = require('mini.pick')
            mini_pick.setup({
                mappings = { delete_left = '<C-u>', delete_word = '<C-w>' },
                window = {
                    config = function()
                        local height = math.floor(0.45 * vim.o.lines)
                        local width = math.floor(0.6 * vim.o.columns)
                        return {
                            anchor = 'NW', height = height, width = width,
                            row = math.floor((vim.o.lines - height) / 2) + math.floor(vim.o.lines / 6),
                            col = math.floor((vim.o.columns - width) / 2),
                            border = 'rounded',
                        }
                    end,
                },
            })

            require('mini.extra').setup()

            -- --- KEYBINDINGS ---
            local toggle_mini_files = function()
                if not mini_files.close() then
                    mini_files.open(vim.api.nvim_buf_get_name(0), true)
                end
            end
            vim.keymap.set('n', '<leader>pe', toggle_mini_files, { desc = 'Toggle Mini Files' })
            vim.keymap.set('n', '<leader>pv', function() mini_files.open(vim.fn.getcwd(), true) end, { desc = 'Open Mini Files (CWD)' })

            local pick = mini_pick.builtin
            local extra = require('mini.extra').pickers
            vim.keymap.set('n', '<leader>pf', pick.files, { desc = 'Find Files' })
            vim.keymap.set('n', '<C-p>', function() pick.files({ tool = 'git' }) end, { desc = 'Git Files' })
            vim.keymap.set('n', '<leader>ps', pick.grep_live, { desc = 'Grep Project' })
        end
    }
}
