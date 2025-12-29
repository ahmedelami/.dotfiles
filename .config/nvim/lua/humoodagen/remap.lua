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

local function current_toggleterm_direction()
    local buf = vim.api.nvim_get_current_buf()
    local term_id = vim.b[buf].toggle_number
    if not term_id then
        return nil
    end

    local ok, term_module = pcall(require, "toggleterm.terminal")
    if not ok then
        return nil
    end

    local term = term_module.get(term_id, true)
    return term and term.direction or nil
end

local function resize_for_axis(axis, cmd)
    local term_direction = current_toggleterm_direction()
    if term_direction == "vertical" and axis == "horizontal" then
        return
    end
    if term_direction == "horizontal" and axis == "vertical" then
        return
    end

    resize_window_any_mode(cmd)
end

local function resize_left()
    resize_for_axis("vertical", "vertical resize -5")
end

local function resize_right()
    resize_for_axis("vertical", "vertical resize +5")
end

local function resize_down()
    resize_for_axis("horizontal", "resize +2")
end

local function resize_up()
    resize_for_axis("horizontal", "resize -2")
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
vim.keymap.set(all_modes, "<F19>", function()
    resize_left()
end, { desc = "Resize split left (Cmd+Shift+H)" })
vim.keymap.set(all_modes, "<F20>", function()
    resize_down()
end, { desc = "Resize split down (Cmd+Shift+J)" })
vim.keymap.set(all_modes, "<F21>", function()
    resize_up()
end, { desc = "Resize split up (Cmd+Shift+K)" })
vim.keymap.set(all_modes, "<F22>", function()
    resize_right()
end, { desc = "Resize split right (Cmd+Shift+L)" })
vim.keymap.set(all_modes, "<F23>", function()
    resize_up()
end, { desc = "Resize split up (Cmd+Shift+Up)" })
vim.keymap.set(all_modes, "<F24>", function()
    resize_down()
end, { desc = "Resize split down (Cmd+Shift+Down)" })
vim.keymap.set(all_modes, "<S-F9>", function()
    resize_left()
end, { desc = "Resize split left (Cmd+Shift+H ghostty)" })
vim.keymap.set(all_modes, "<S-F10>", function()
    resize_down()
end, { desc = "Resize split down (Cmd+Shift+J ghostty)" })
vim.keymap.set(all_modes, "<F11>", function()
    resize_up()
end, { desc = "Resize split up (Cmd+Shift+K ghostty)" })
vim.keymap.set(all_modes, "<F12>", function()
    resize_right()
end, { desc = "Resize split right (Cmd+Shift+L ghostty)" })

local esc = "\x1b"

local function call_toggleterm_nav(action)
    local nav = _G.ToggletermNav
    if not nav then
        local ok_lazy, lazy = pcall(require, "lazy")
        if ok_lazy then
            lazy.load({ plugins = { "toggleterm.nvim" } })
        end
        nav = _G.ToggletermNav
    end
    if nav and nav[action] then
        nav[action]()
    end
end

local nav_modes = { "n", "i", "v", "x", "s", "o", "c" }
local nav_terminal_mode = { "t" }

local function map_nav(lhs, action, desc)
    vim.keymap.set(nav_modes, lhs, function()
        call_toggleterm_nav(action)
    end, { desc = desc })

    vim.keymap.set(nav_terminal_mode, lhs, function()
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true), "n", false)
        vim.schedule(function()
            call_toggleterm_nav(action)
        end)
    end, { desc = desc })
end

map_nav("<D-h>", "focus_left", "Focus left (Cmd+H)")
map_nav("<D-j>", "focus_down", "Focus down (Cmd+J)")
map_nav("<D-k>", "focus_up", "Focus up (Cmd+K)")
map_nav("<D-l>", "focus_right", "Focus right (Cmd+L)")
map_nav("<F55>", "focus_left", "Focus left (Cmd+H ghostty)")
map_nav("<F56>", "focus_down", "Focus down (Cmd+J ghostty)")
map_nav("<F57>", "focus_up", "Focus up (Cmd+K ghostty)")
map_nav("<F58>", "focus_right", "Focus right (Cmd+L ghostty)")
map_nav(esc .. "[18;3~", "focus_left", "Focus left (Cmd+H ghostty raw)")
map_nav(esc .. "[19;3~", "focus_down", "Focus down (Cmd+J ghostty raw)")
map_nav(esc .. "[20;3~", "focus_up", "Focus up (Cmd+K ghostty raw)")
map_nav(esc .. "[21;3~", "focus_right", "Focus right (Cmd+L ghostty raw)")
map_nav(esc .. "[18;9~", "focus_left", "Focus left (Cmd+H ghostty fallback)")
map_nav(esc .. "[19;9~", "focus_down", "Focus down (Cmd+J ghostty fallback)")
map_nav(esc .. "[20;9~", "focus_up", "Focus up (Cmd+K ghostty fallback)")
map_nav(esc .. "[21;9~", "focus_right", "Focus right (Cmd+L ghostty fallback)")

vim.keymap.set(all_modes, esc .. "[33~", resize_left, { desc = "Resize split left (Cmd+Shift+H raw)" })
vim.keymap.set(all_modes, esc .. "[34~", resize_down, { desc = "Resize split down (Cmd+Shift+J raw)" })
vim.keymap.set(all_modes, esc .. "[35~", resize_up, { desc = "Resize split up (Cmd+Shift+K raw)" })
vim.keymap.set(all_modes, esc .. "[36~", resize_right, { desc = "Resize split right (Cmd+Shift+L raw)" })
vim.keymap.set(all_modes, esc .. "[37~", resize_up, { desc = "Resize split up (Cmd+Shift+Up raw)" })
vim.keymap.set(all_modes, esc .. "[38~", resize_down, { desc = "Resize split down (Cmd+Shift+Down raw)" })
vim.keymap.set(all_modes, "<S-Left>", resize_left, { desc = "Resize split left (Cmd+Shift+H)" })
vim.keymap.set(all_modes, "<S-Down>", resize_down, { desc = "Resize split down (Cmd+Shift+J)" })
vim.keymap.set(all_modes, "<S-Up>", resize_up, { desc = "Resize split up (Cmd+Shift+K)" })
vim.keymap.set(all_modes, "<S-Right>", resize_right, { desc = "Resize split right (Cmd+Shift+L)" })
vim.keymap.set(all_modes, esc .. "[18;2~", resize_left, { desc = "Resize split left (Cmd+Shift+H xterm)" })
vim.keymap.set(all_modes, esc .. "[19;2~", resize_down, { desc = "Resize split down (Cmd+Shift+J xterm)" })
vim.keymap.set(all_modes, esc .. "[20;2~", resize_left, { desc = "Resize split left (Cmd+Shift+H xterm)" })
vim.keymap.set(all_modes, esc .. "[21;2~", resize_down, { desc = "Resize split down (Cmd+Shift+J xterm)" })
vim.keymap.set(all_modes, esc .. "[23;2~", resize_up, { desc = "Resize split up (Cmd+Shift+Up xterm)" })
vim.keymap.set(all_modes, esc .. "[24;2~", resize_down, { desc = "Resize split down (Cmd+Shift+Down xterm)" })

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
