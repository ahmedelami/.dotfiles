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
                MiniDiff.toggle_overlay(0)
            end, { desc = 'Toggle Diff Overlay' })
        end,
    },
}
