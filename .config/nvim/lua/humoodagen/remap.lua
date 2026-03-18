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

local function toggle_git_review()
    local ok, git_review = pcall(require, "humoodagen.git_review")
    if not ok then
        vim.notify("Git review module unavailable.", vim.log.levels.ERROR)
        return
    end

    git_review.toggle()
end

local function open_repo_diffview()
    local ok = pcall(vim.cmd, "DiffviewOpen")
    if not ok then
        vim.notify("Diffview unavailable.", vim.log.levels.ERROR)
        return
    end

    vim.defer_fn(function()
        pcall(vim.cmd, "redraw!")
    end, 350)
end

local function current_buf()
    return vim.api.nvim_get_current_buf()
end

local function current_buf_name()
    return vim.api.nvim_buf_get_name(current_buf())
end

local function is_git_review_buf(buf)
    if not (buf and vim.api.nvim_buf_is_valid(buf)) then
        return false
    end

    local name = vim.api.nvim_buf_get_name(buf)
    return vim.bo[buf].buftype == "nofile"
        and vim.bo[buf].filetype == "diff"
        and name:find("%[git diff#", 1, false) ~= nil
end

local function in_git_review_sidecar()
    return is_git_review_buf(current_buf())
end

local function is_main_edit_win(win)
    if not (win and vim.api.nvim_win_is_valid(win)) then
        return false
    end

    local buf = vim.api.nvim_win_get_buf(win)
    local buftype = vim.bo[buf].buftype
    local filetype = vim.bo[buf].filetype
    if filetype == "NvimTree" or filetype == "toggleterm" then
        return false
    end
    if buftype == "terminal" or buftype == "nofile" or buftype == "help" then
        return false
    end
    local cfg = vim.api.nvim_win_get_config(win)
    if cfg.relative ~= "" then
        return false
    end
    return vim.api.nvim_buf_get_name(buf) ~= ""
end

local function find_main_edit_win(exclude_win)
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if win ~= exclude_win and is_main_edit_win(win) then
            return win
        end
    end
    return nil
end

local function find_git_review_win()
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        local buf = vim.api.nvim_win_get_buf(win)
        if is_git_review_buf(buf) then
            return win
        end
    end
    return nil
end

local function current_path_in_win(win)
    if not is_main_edit_win(win) then
        return nil
    end
    local path = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win))
    if path == "" then
        return nil
    end
    return vim.fn.fnamemodify(path, ":p")
end

local function prefer_repo_git_ui()
    local buf = current_buf()
    local buftype = vim.bo[buf].buftype
    local filetype = vim.bo[buf].filetype

    if buftype == "terminal" then
        return true
    end

    return filetype == "NvimTree" or filetype == "toggleterm"
end

local function same_path(a, b)
    if type(a) ~= "string" or a == "" or type(b) ~= "string" or b == "" then
        return false
    end
    if a == b then
        return true
    end

    local ra = vim.uv.fs_realpath(a)
    local rb = vim.uv.fs_realpath(b)
    return ra and rb and ra == rb
end

local function tree_selected_file_path()
    local ok, api = pcall(require, "nvim-tree.api")
    if not ok then
        return nil, "NvimTree API unavailable."
    end

    local node = api.tree.get_node_under_cursor()
    if not node then
        return nil, "No NvimTree node selected."
    end

    local path = type(node.absolute_path) == "string" and node.absolute_path or nil
    if node.type == "file" and path and path ~= "" then
        return path
    end

    return nil, "Select a file in NvimTree to review."
end

local function ensure_review_file_win_from_tree()
    local ok_view, view = pcall(require, "nvim-tree.view")
    local tree_win = ok_view and view.get_winnr() or nil
    if not (tree_win and vim.api.nvim_win_is_valid(tree_win)) then
        tree_win = vim.api.nvim_get_current_win()
    end

    local file_win = find_main_edit_win(tree_win)
    if file_win then
        return file_win
    end

    local created_win = nil
    local ok_split = pcall(vim.api.nvim_win_call, tree_win, function()
        vim.cmd("vsplit")
        created_win = vim.api.nvim_get_current_win()
        vim.cmd("enew")
    end)
    if not ok_split or not (created_win and vim.api.nvim_win_is_valid(created_win)) then
        return nil
    end

    local ok_api, api = pcall(require, "nvim-tree.api")
    if ok_api then
        pcall(api.tree.resize)
    end

    return created_win
end

local function edit_path_in_win(win, path)
    local escaped = vim.fn.fnameescape(path)
    local ok, err = pcall(vim.api.nvim_win_call, win, function()
        vim.cmd("edit " .. escaped)
    end)
    if not ok then
        return nil, tostring(err)
    end
    return true
end

local function handle_tree_cmd_r()
    local path = tree_selected_file_path()
    if not path then
        open_repo_diffview()
        return
    end

    local file_win = ensure_review_file_win_from_tree()
    if not file_win then
        vim.notify("Git review: couldn't create a file window from NvimTree.", vim.log.levels.ERROR)
        return
    end

    local review_open = find_git_review_win() ~= nil
    local current_path = current_path_in_win(file_win)

    if review_open and same_path(current_path, path) then
        vim.api.nvim_set_current_win(file_win)
        toggle_git_review()
        return
    end

    local ok_edit, err = edit_path_in_win(file_win, path)
    if not ok_edit then
        vim.notify("Git review: couldn't open " .. path .. ": " .. err, vim.log.levels.ERROR)
        return
    end

    vim.api.nvim_set_current_win(file_win)
    if not review_open then
        toggle_git_review()
    end
end

local function cmd_r_action()
    if in_git_review_sidecar() then
        toggle_git_review()
        return
    end

    if vim.bo[current_buf()].filetype == "NvimTree" then
        handle_tree_cmd_r()
        return
    end

    if prefer_repo_git_ui() then
        open_repo_diffview()
        return
    end

    toggle_git_review()
end

vim.api.nvim_create_user_command("HumoodagenCmdRGitAction", cmd_r_action, {
    desc = "Context-aware Cmd+R Git action",
})

local function map_git_review_toggle(lhs)
    local desc = "Git UI: file diff or Diffview"

    vim.keymap.set("n", lhs, cmd_r_action, { desc = desc, silent = true })
    vim.keymap.set("x", lhs, "<Esc><Cmd>HumoodagenCmdRGitAction<CR>", { desc = desc, silent = true })
    vim.keymap.set("i", lhs, "<Esc><Cmd>HumoodagenCmdRGitAction<CR>", { desc = desc, silent = true })
    vim.keymap.set("t", lhs, "<C-\\><C-n><Cmd>HumoodagenCmdRGitAction<CR>", { desc = desc, silent = true })
end

-- Ghostty sends Cmd+R as `^[[28~`, which Neovim often translates to `<F15>`.
-- GUI clients like Neovide send the direct `<D-r>` key instead.
for _, lhs in ipairs({ "<F15>", "<Esc>[28~", "<D-r>", "<D-R>" }) do
    map_git_review_toggle(lhs)
end

for i = 1, 9 do
    vim.keymap.set("n", ("<C-%d>"):format(i), function()
        if i > #vim.api.nvim_list_tabpages() then
            return
        end
        vim.cmd(("tabnext %d"):format(i))
    end, { desc = ("Go to tab %d"):format(i) })
end
