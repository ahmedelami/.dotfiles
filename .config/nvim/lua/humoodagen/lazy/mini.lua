return {
    {
        'echasnovski/mini.nvim',
        version = false,
        event = "VeryLazy",
        config = function()
            local icons = require('mini.icons')
            icons.setup({ style = 'glyph' })
            icons.tweak_lsp_kind()

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

            local git_review = require("humoodagen.git_review")
            vim.keymap.set('n', '<leader>gr', function() git_review.toggle() end, { desc = 'Git review (code + unified diff)' })
        end,
    },
}
