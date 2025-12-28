vim.g.mapleader = " "
-- vim.keymap.set('n', '<leader>pv', vim.cmd.Ex)

vim.keymap.set({ "n", "v" }, "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })
vim.keymap.set({ "n", "v" }, "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })

vim.keymap.set("n", "<C-c>", "<cmd>q<CR>")

-- highlight and move
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")

vim.keymap.set("n", "<C-d>", "<C-d>zz")
vim.keymap.set("n", "<C-u>", "<C-u>zz")
vim.keymap.set("n", "n", "nzzzv")
vim.keymap.set("n", "N", "Nzzzv")

-- next greatest remap ever : asbjornHaland
vim.keymap.set({"n", "v"}, "<leader>y", [["+y]])
vim.keymap.set("n", "<leader>Y", [["+Y]])

-- apparently dont go to Q ever? so disable it
vim.keymap.set("n", "Q", "<nop>")

vim.keymap.set("n", "<leader>f", vim.lsp.buf.format)

-- make executable
vim.keymap.set("n", "<leader>x", "<cmd>!chmod +x %<CR>", { silent = true })

local function toggle_nvim_tree_any_mode()
    local mode = vim.api.nvim_get_mode().mode
    local mode_prefix = mode:sub(1, 1)
    if mode_prefix == "t" then
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true), "n", false)
    elseif mode_prefix == "c" then
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-c>", true, false, true), "n", false)
    end

    vim.schedule(function()
        require("nvim-tree.api").tree.toggle()
    end)
end

local function resize_window_any_mode(cmd)
    local mode = vim.api.nvim_get_mode().mode
    local mode_prefix = mode:sub(1, 1)
    if mode_prefix == "t" then
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true), "n", false)
    elseif mode_prefix == "c" then
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-c>", true, false, true), "n", false)
    end

    vim.schedule(function()
        vim.cmd(cmd)
    end)
end

local all_modes = { "n", "i", "v", "x", "s", "o", "t", "c" }
vim.keymap.set(all_modes, "<C-f>", "<C-e>", { desc = "Ctrl-E default" })
vim.keymap.set(all_modes, "<C-e>", toggle_nvim_tree_any_mode, { desc = "Toggle NvimTree" })
vim.keymap.set(all_modes, "<C-S-h>", function()
    resize_window_any_mode("vertical resize -5")
end, { desc = "Resize split left" })
vim.keymap.set(all_modes, "<C-S-l>", function()
    resize_window_any_mode("vertical resize +5")
end, { desc = "Resize split right" })
vim.keymap.set(all_modes, "<C-S-j>", function()
    resize_window_any_mode("resize +2")
end, { desc = "Resize split down" })
vim.keymap.set(all_modes, "<C-S-k>", function()
    resize_window_any_mode("resize -2")
end, { desc = "Resize split up" })

-- Set the width of a hard tabstop
vim.opt.tabstop = 4

-- Set the number of spaces inserted for each indentation
vim.opt.shiftwidth = 4

-- When pressing Tab in Insert mode, insert the number of spaces specified by shiftwidth
vim.opt.softtabstop = 4

-- Convert tabs to spaces
vim.opt.expandtab = true

-- If left here, it means this fix indent on new line being 8 spaces
vim.opt.smartindent = true
