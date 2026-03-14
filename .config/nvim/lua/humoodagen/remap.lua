vim.g.mapleader = " "

vim.keymap.set({ "n", "v" }, "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })
vim.keymap.set({ "n", "v" }, "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })

vim.keymap.set("n", "<C-c>", "<cmd>qa<CR>")

-- highlight and move
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")

local immediate_scroll_opts = { nowait = true, silent = true }

vim.keymap.set("n", "<C-d>", "<C-d>zz", immediate_scroll_opts)
vim.keymap.set("n", "<C-u>", "<C-u>zz", immediate_scroll_opts)
vim.keymap.set("n", "n", "nzzzv")
vim.keymap.set("n", "N", "Nzzzv")

local function quarter_page_scroll(motion)
    local step = math.max(1, math.floor(vim.api.nvim_win_get_height(0) / 4))
    vim.cmd(("normal! %d%szz"):format(step, motion))
end

vim.keymap.set("n", "<C-w>", function()
    quarter_page_scroll("gk")
end, { desc = "Scroll quarter page up", nowait = true, silent = true })

vim.keymap.set("n", "<C-s>", function()
    quarter_page_scroll("gj")
end, { desc = "Scroll quarter page down", nowait = true, silent = true })

-- next greatest remap ever : asbjornHaland
vim.keymap.set({"n", "v"}, "<leader>y", [["+y]])
vim.keymap.set("n", "<leader>Y", [["+Y]])

-- apparently dont go to Q ever? so disable it
vim.keymap.set("n", "Q", "<nop>")

vim.keymap.set("n", "<C-f>", "<cmd>silent !tmux neww tmux-sessionizer<CR>")
vim.keymap.set("n", "<leader>f", vim.lsp.buf.format)

-- make executable
vim.keymap.set("n", "<leader>x", "<cmd>!chmod +x %<CR>", { silent = true })

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

local function open_tree()
    local ok_api, api = pcall(require, "nvim-tree.api")
    if not ok_api then
        pcall(vim.cmd, "Lazy load nvim-tree.lua")
        ok_api, api = pcall(require, "nvim-tree.api")
    end

    if ok_api then
        api.tree.open({ current_window = true })
    else
        pcall(vim.cmd, "NvimTreeOpen")
        pcall(vim.cmd, "NvimTreeFocus")
    end
end

vim.keymap.set("n", "<C-t>", function()
    vim.cmd("tabnew")
    open_tree()
end, { desc = "New tab + tree" })

local function file_tree_in_place()
    local ok_api, api = pcall(require, "nvim-tree.api")
    if not ok_api then
        pcall(vim.cmd, "Lazy load nvim-tree.lua")
        ok_api, api = pcall(require, "nvim-tree.api")
    end

    if ok_api then
        api.tree.open({ current_window = true, find_file = true })
    else
        pcall(vim.cmd, "NvimTreeOpen")
        pcall(vim.cmd, "NvimTreeFocus")
    end
end

-- Ghostty is configured to send Cmd+E as `^[[19;3~`, and Neovim often translates it to `<F56>`.
for _, lhs in ipairs({ "<F56>", "<Esc>[19;3~" }) do
    vim.keymap.set("n", lhs, file_tree_in_place, { desc = "File tree (in place)" })
end

for i = 1, 9 do
    vim.keymap.set("n", ("<C-%d>"):format(i), function()
        if i > #vim.api.nvim_list_tabpages() then
            return
        end
        vim.cmd(("tabnext %d"):format(i))
    end, { desc = ("Go to tab %d"):format(i) })
end
