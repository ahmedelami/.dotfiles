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

        local Terminal = require("toggleterm.terminal").Terminal
        local bottom_term = Terminal:new({ direction = "horizontal", hidden = true })
        local right_term = Terminal:new({ direction = "vertical", hidden = true })

        local function toggle_terminal(term)
            local mode = vim.api.nvim_get_mode().mode
            local mode_prefix = mode:sub(1, 1)
            if mode_prefix == "t" then
                vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true), "n", false)
            elseif mode_prefix == "c" then
                vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-c>", true, false, true), "n", false)
            end

            vim.schedule(function()
                term:toggle()
            end)
        end

        local all_modes = { "n", "i", "v", "x", "s", "o", "t", "c" }
        vim.keymap.set(all_modes, "<F14>", function()
            toggle_terminal(bottom_term)
        end, { desc = "Toggle bottom terminal" })
        vim.keymap.set(all_modes, "<F13>", function()
            toggle_terminal(right_term)
        end, { desc = "Toggle right terminal" })
        vim.keymap.set(all_modes, "<F16>", function()
            toggle_terminal(bottom_term)
        end, { desc = "Toggle bottom terminal (Cmd+X)" })
        vim.keymap.set(all_modes, "<F15>", function()
            toggle_terminal(right_term)
        end, { desc = "Toggle right terminal (Cmd+S)" })
        vim.keymap.set(all_modes, "<S-F7>", function()
            toggle_terminal(bottom_term)
        end, { desc = "Toggle bottom terminal (Cmd+X fallback)" })
        vim.keymap.set(all_modes, "<S-F5>", function()
            toggle_terminal(right_term)
        end, { desc = "Toggle right terminal (Cmd+S fallback)" })
        vim.keymap.set(all_modes, "<F18>", function()
            toggle_terminal(bottom_term)
        end, { desc = "Toggle bottom terminal (Cmd+X fallback)" })
        vim.keymap.set(all_modes, "<F17>", function()
            toggle_terminal(right_term)
        end, { desc = "Toggle right terminal (Cmd+S fallback)" })
        vim.keymap.set(all_modes, "<S-F4>", function()
            toggle_terminal(bottom_term)
        end, { desc = "Toggle bottom terminal (Cmd+X)" })
        vim.keymap.set(all_modes, "<S-F3>", function()
            toggle_terminal(right_term)
        end, { desc = "Toggle right terminal (Cmd+S)" })
    end,
}
