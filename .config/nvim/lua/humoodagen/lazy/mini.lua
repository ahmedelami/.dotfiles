return {
    {
        'echasnovski/mini.nvim',
        version = false,
        event = "VeryLazy",
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

            local git_review = require("humoodagen.git_review")

            local pick = mini_pick.builtin
            vim.keymap.set('n', '<leader>pf', pick.files, { desc = 'Find Files' })
            vim.keymap.set('n', '<C-p>', function() pick.files({ tool = 'git' }) end, { desc = 'Git Files' })
            vim.keymap.set('n', '<leader>ps', pick.grep_live, { desc = 'Grep Project' })
            vim.keymap.set('n', '<leader>gr', function() git_review.toggle() end, { desc = 'Git review (code + unified diff)' })

            -- Git review:
            -- - If current file has changes: open/close the sidecar unified diff.
            -- - Otherwise: open the Git Changes picker.
            local function ctrl_g()
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

                local function get_context_path(buf)
                    if not (buf and vim.api.nvim_buf_is_valid(buf)) then
                        return nil
                    end

                    local name = vim.api.nvim_buf_get_name(buf)
                    if vim.bo[buf].buftype == "" and name ~= "" then
                        return name
                    end

                    local ft = vim.bo[buf].filetype
                    if ft == "NvimTree" then
                        local ok_api, api = pcall(require, "nvim-tree.api")
                        if ok_api then
                            local ok_node, node = pcall(api.tree.get_node_under_cursor)
                            if ok_node and node then
                                return node.link_to or node.absolute_path
                            end
                        end
                    end

                    return vim.fn.getcwd()
                end

                local function normalize_path(path)
                    if type(path) ~= "string" or path == "" then
                        return nil
                    end
                    local abs = vim.fn.fnamemodify(path, ":p")
                    if abs == "" then
                        return nil
                    end
                    return abs
                end

                local function get_git_root(context_path)
                    local path = normalize_path(context_path) or normalize_path(vim.fn.getcwd())
                    if not path then
                        return nil
                    end

                    local dir = path
                    if vim.fn.isdirectory(dir) == 0 then
                        dir = vim.fn.fnamemodify(dir, ":h")
                    end

                    local out = vim.fn.systemlist({ "git", "-C", dir, "rev-parse", "--show-toplevel" })
                    if vim.v.shell_error ~= 0 then
                        return nil
                    end
                    return out[1]
                end

                local function git_status_items(root)
                    local out = vim.fn.systemlist({
                        "git",
                        "-C",
                        root,
                        "-c",
                        "core.quotePath=false",
                        "status",
                        "--porcelain=v1",
                    })
                    if vim.v.shell_error ~= 0 then
                        return nil
                    end

                    local items = {}
                    local seen = {}

                    for _, line in ipairs(out) do
                        if type(line) == "string" and line ~= "" then
                            local status = line:sub(1, 2)
                            local path = vim.trim(line:sub(4))
                            local display_path = path

                            if status:find("R", 1, true) or status:find("C", 1, true) then
                                local parts = vim.split(path, " -> ", { plain = true })
                                if #parts >= 2 then
                                    path = parts[#parts]
                                end
                            end

                            if path ~= "" and not seen[status .. "\n" .. path] then
                                seen[status .. "\n" .. path] = true
                                table.insert(items, {
                                    text = status .. " " .. display_path,
                                    path = root .. "/" .. path,
                                    relpath = path,
                                    display_path = display_path,
                                    status = status,
                                })
                            end
                        end
                    end

                    return items
                end

                local function open_git_diff_scratch(win, root, relpath, display, opts)
                    if not (win and vim.api.nvim_win_is_valid(win)) then
                        return false
                    end
                    if type(root) ~= "string" or root == "" then
                        return false
                    end
                    if type(relpath) ~= "string" or relpath == "" then
                        return false
                    end

                    local args = { "diff", "--no-color" }
                    if opts and opts.cached then
                        table.insert(args, "--cached")
                    end
                    table.insert(args, "--")
                    table.insert(args, relpath)

                    local cmd = { "git", "-C", root, "-c", "core.quotePath=false" }
                    vim.list_extend(cmd, args)
                    local lines = vim.fn.systemlist(cmd)
                    if vim.v.shell_error ~= 0 then
                        vim.notify("git diff failed for " .. relpath, vim.log.levels.ERROR)
                        return false
                    end
                    if vim.tbl_isempty(lines) then
                        vim.notify("No diff output for " .. relpath, vim.log.levels.INFO)
                        return false
                    end

                    local title = "[git diff] " .. (display or relpath)
                    vim.api.nvim_win_call(win, function()
                        vim.cmd("enew")
                        local buf = vim.api.nvim_get_current_buf()
                        vim.api.nvim_buf_set_name(buf, title)
                        vim.bo[buf].buftype = "nofile"
                        vim.bo[buf].bufhidden = "wipe"
                        vim.bo[buf].swapfile = false
                        vim.bo[buf].modifiable = true
                        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
                        vim.bo[buf].modifiable = false
                        vim.bo[buf].readonly = true
                        vim.bo[buf].filetype = "diff"
                    end)
                    return true
                end

                local function open_git_changes_picker(target_win, context_path)
                    local root = get_git_root(context_path)
                    if not root or root == "" then
                        vim.notify("Not inside a Git repository.", vim.log.levels.WARN)
                        return
                    end

                    local items = git_status_items(root) or {}
                    if vim.tbl_isempty(items) then
                        vim.notify("No Git changes found.", vim.log.levels.INFO)
                        return
                    end

                    mini_pick.start({
                        source = {
                            name = "Git Changes",
                            items = items,
                            choose = function(item)
                                local win = target_win
                                if not win or not vim.api.nvim_win_is_valid(win) then
                                    win = mini_pick.get_picker_state().windows.target
                                end

                                if not win or not vim.api.nvim_win_is_valid(win) then
                                    vim.notify("No valid target window to open file.", vim.log.levels.ERROR)
                                    return
                                end

                                local should_focus = false
                                vim.api.nvim_win_call(win, function()
                                    local path = item.path or item
                                    if type(path) ~= "string" or path == "" then
                                        vim.notify("Invalid path.", vim.log.levels.ERROR)
                                        return
                                    end

                                    if vim.fn.filereadable(path) == 0 then
                                        local status = type(item) == "table" and item.status or ""
                                        local relpath = type(item) == "table" and item.relpath or nil
                                        local display = type(item) == "table" and item.display_path or nil
                                        local index_status = type(status) == "string" and status:sub(1, 1) or ""
                                        local worktree_status = type(status) == "string" and status:sub(2, 2) or ""

                                        if index_status == "D" or worktree_status == "D" then
                                            should_focus = open_git_diff_scratch(win, root, relpath or path, display, {
                                                cached = index_status == "D",
                                            })
                                            return
                                        end

                                        vim.notify("File not readable: " .. path, vim.log.levels.WARN)
                                        return
                                    end

                                    vim.cmd("edit " .. vim.fn.fnameescape(path))
                                    should_focus = true

                                    pcall(git_review.open, { win = win })
                                end)

                                if should_focus then
                                    vim.schedule(function()
                                        if vim.api.nvim_win_is_valid(win) then
                                            vim.api.nvim_set_current_win(win)
                                        end
                                    end)
                                end
                                return false
                            end,
                        },
                    })
                end

                local initial_buf = vim.api.nvim_get_current_buf()
                local initial_context_path = get_context_path(initial_buf)
                local initial_name = vim.api.nvim_buf_get_name(initial_buf)
                local initial_ft = vim.bo[initial_buf].filetype
                local initial_buftype = vim.bo[initial_buf].buftype

                local target_win = find_main_edit_win()
                if not (target_win and vim.api.nvim_win_is_valid(target_win)) then
                    target_win = vim.api.nvim_get_current_win()
                end

                -- In the main file buffer:
                -- - If there are changes (dirty buffer or git status), toggle the sidecar diff.
                -- - Otherwise, show the "Git Changes" picker (visible feedback).
                local is_file_buf = initial_buftype == "" and initial_name ~= "" and initial_ft ~= "NvimTree" and initial_ft ~= "toggleterm"
                if is_file_buf then
                    local has_changes = vim.bo[initial_buf].modified
                    if not has_changes then
                        local root = get_git_root(initial_name)
                        if root and root ~= "" then
                            local out = vim.fn.systemlist({
                                "git",
                                "-C",
                                root,
                                "-c",
                                "core.quotePath=false",
                                "status",
                                "--porcelain=v1",
                                "--",
                                initial_name,
                            })
                            if vim.v.shell_error == 0 then
                                for _, line in ipairs(out) do
                                    if type(line) == "string" and line ~= "" then
                                        has_changes = true
                                        break
                                    end
                                end
                            end
                        end
                    end

                    if has_changes then
                        pcall(git_review.toggle, { win = target_win })
                        return
                    end

                    open_git_changes_picker(target_win, initial_context_path)
                    return
                end

                -- From NvimTree/term/unnamed/special buffers: always open picker.
                open_git_changes_picker(target_win, initial_context_path)
            end

            vim.keymap.set('n', '<C-g>', ctrl_g, { desc = 'Git changes / review' })
            vim.keymap.set('t', '<C-g>', function()
                vim.api.nvim_feedkeys(
                    vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true),
                    "n",
                    false
                )
                vim.schedule(ctrl_g)
            end, { desc = 'Git changes / review' })
            vim.keymap.set('i', '<C-g>', function()
                vim.cmd("stopinsert")
                vim.schedule(ctrl_g)
            end, { desc = 'Git changes / review' })
        end,
    },
}
