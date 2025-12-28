return {
    "nvim-telescope/telescope.nvim",

    tag = "0.1.5",

    dependencies = {
        "nvim-lua/plenary.nvim"
    },

    config = function()
        require('telescope').setup({
            defaults = {
                file_ignore_patterns = {
                    "bootstrap%-icons/.*",
                    "node_modules/.*"
                }
            }
        })

        -- local builtin = require('telescope.builtin')
        -- vim.keymap.set('n', '<leader>pf', builtin.find_files, {})
        -- vim.keymap.set('n', '<C-p>', builtin.git_files, {})
        -- vim.keymap.set('n', '<leader>pws', function()
        --     local word = vim.fn.expand("<cword>")
        --     builtin.grep_string({ search = word })
        -- end)
        -- vim.keymap.set('n', '<leader>pWs', function()
        --     local word = vim.fn.expand("<cWORD>")
        --     builtin.grep_string({ search = word })
        -- end)
        -- vim.keymap.set('n', '<leader>ps', function()
        --     builtin.grep_string({ search = vim.fn.input("Grep > ") })
        -- end)
        -- vim.keymap.set('n', '<leader>vh', builtin.help_tags, {})
        
        -- Go to file under cursor with Telescope (better for complex paths)
        -- vim.keymap.set('n', '<leader>gf', function()
        --     local word = vim.fn.expand("<cfile>")
        --     builtin.find_files({ default_text = word })
        -- end, { desc = "Find file under cursor" })
        
        -- Search for visually selected text (simpler approach)
        -- vim.keymap.set('v', '<leader>ps', function()
        --     -- Exit visual mode and get the selected text
        --     vim.cmd('normal! "vy')
        --     local selected_text = vim.fn.getreg('v')
        --     builtin.grep_string({ search = selected_text })
        -- end, { desc = "Search selected text" })
    end
}
