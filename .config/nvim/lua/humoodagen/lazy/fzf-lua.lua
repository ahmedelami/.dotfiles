return {
    "ibhagwan/fzf-lua",
    dependencies = { "echasnovski/mini.nvim" },
    cmd = { "FzfLua" },
    keys = {
        { "<leader>pv", mode = "n" },
        { "<leader>pf", mode = "n" },
        { "<leader>ps", mode = "n" },
        { "<C-j>", mode = { "n", "v", "x" } },
        { "<C-p>", mode = "n" },
        { "<C-g>", mode = { "n", "t", "i" } },
        { "<M-k>", mode = "n" },
        { "<C-k>", mode = { "n", "v", "x" } },
    },
    config = function()
        local fzf = require("fzf-lua")
        local actions = require("fzf-lua.actions")
        local config = require("fzf-lua.config")
        local utils = require("fzf-lua.utils")
        local commands = require("humoodagen.commands")

        fzf.setup({
            winopts = {
                split = "botright new",
                preview = {
                    hidden = true,
                },
            },
        })

        local function find_files_cwd()
            fzf.files({ cwd = vim.fn.getcwd() })
        end

        local function normalize_grep_search(text)
            if type(text) ~= "string" then
                return nil
            end

            local normalized = text
                :gsub("\r\n", "\n")
                :gsub("\r", "\n")
                :gsub("\n", " ")
                :gsub("%s+", " ")
            normalized = vim.trim(normalized)
            if normalized == "" then
                return nil
            end

            return normalized
        end

        local function get_visual_selection()
            return normalize_grep_search(utils.get_visual_selection())
        end

        local function live_grep_cwd(search)
            local opts = {
                cwd = vim.fn.getcwd(),
                keymap = {
                    fzf = {
                        ["ctrl-j"] = "abort",
                    },
                },
            }

            if search then
                opts.search = search
            end

            fzf.live_grep(opts)
        end

        local function live_grep_visual_cwd()
            local search = get_visual_selection()
            if not search then
                return
            end

            vim.schedule(function()
                live_grep_cwd(search)
            end)
        end

        local function git_files_or_files_cwd()
            local ok_path, path = pcall(require, "fzf-lua.path")
            if ok_path and type(path.git_root) == "function" then
                local root = path.git_root({ cwd = vim.fn.getcwd() }, true)
                if type(root) == "string" and root ~= "" then
                    fzf.git_files({ cwd = root })
                    return
                end
            end

            find_files_cwd()
        end

        vim.keymap.set("n", "<leader>pv", find_files_cwd, { desc = "Find files (cwd)" })
        vim.keymap.set("n", "<leader>pf", find_files_cwd, { desc = "Find files (cwd)" })
        vim.keymap.set("n", "<C-p>", git_files_or_files_cwd, { desc = "Git files (or cwd files)" })
        vim.keymap.set("n", "<leader>ps", live_grep_cwd, { desc = "Live grep (cwd)" })
        vim.keymap.set("n", "<C-j>", live_grep_cwd, { desc = "Live grep (cwd)" })
        vim.keymap.set({ "v", "x" }, "<C-j>", live_grep_visual_cwd, { desc = "Live grep selection (cwd)" })

        vim.keymap.set("n", "<M-k>", find_files_cwd, { desc = "Find files (cwd)" })

        local function find_files_or_create(ctx)
            ctx = ctx or {}
            local origin_win = ctx.origin_win
            local origin_buf = ctx.origin_buf
            local query = normalize_grep_search(ctx.query)

            local default_actions = config.globals.actions.files
            local function accept_or_create(selected, opts)
                if selected and #selected > 0 then
                    return actions.file_edit_or_qf(selected, opts)
                end

                local query = opts.last_query
                if type(query) ~= "string" or vim.fn.trim(query) == "" then
                    return
                end

                commands.create_path(query)
            end

            local function restore_origin_term_mode(target_win)
                if not (target_win and vim.api.nvim_win_is_valid(target_win)) then
                    return
                end

                local buf = vim.api.nvim_win_get_buf(target_win)
                if not (buf and vim.api.nvim_buf_is_valid(buf)) then
                    return
                end
                if vim.bo[buf].filetype ~= "toggleterm" then
                    return
                end

                local desired = vim.b[buf].humoodagen_term_mode
                if type(desired) ~= "string" or desired == "" then
                    desired = "t"
                end
                if desired:sub(1, 1) ~= "t" then
                    return
                end

                vim.defer_fn(function()
                    if not vim.api.nvim_win_is_valid(target_win) then
                        return
                    end
                    if vim.api.nvim_get_current_win() ~= target_win then
                        return
                    end

                    local cur_buf = vim.api.nvim_win_get_buf(target_win)
                    if vim.bo[cur_buf].filetype ~= "toggleterm" then
                        return
                    end
                    if vim.api.nvim_get_mode().mode ~= "t" then
                        vim.cmd("startinsert")
                    end
                end, 10)
            end

            local function jump_back_to_origin()
                local target_win = nil
                if origin_win and vim.api.nvim_win_is_valid(origin_win) then
                    target_win = origin_win
                elseif origin_buf and vim.api.nvim_buf_is_valid(origin_buf) then
                    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
                        if vim.api.nvim_win_get_buf(win) == origin_buf then
                            target_win = win
                            break
                        end
                    end
                end

                if not target_win then
                    return
                end

                vim.api.nvim_set_current_win(target_win)
                restore_origin_term_mode(target_win)
            end

            local function abort_and_restore()
                vim.defer_fn(jump_back_to_origin, 10)
            end

            local file_actions = vim.tbl_extend("force", {}, default_actions, {
                ["enter"] = accept_or_create,
                ["tab"] = accept_or_create,
                ["ctrl-k"] = abort_and_restore,
            })

            fzf.files({
                cwd = vim.fn.getcwd(),
                query = query,
                actions = file_actions,
                headers = false,
                cwd_prompt = false,
                prompt = "",
                keymap = {
                    fzf = {
                        ["right"] = "transform-query:python3 -c 'import sys; q=sys.argv[1] if len(sys.argv)>1 else \"\"; s=sys.argv[2] if len(sys.argv)>2 else \"\"; o=sys.stdout; if not s: o.write(q); raise SystemExit; if not q: i=s.find(\"/\"); o.write(s if i==-1 else s[:i+1]); raise SystemExit; if not s.startswith(q): o.write(q); raise SystemExit; rest=s[len(q):]; i=rest.find(\"/\"); o.write(s if i==-1 else s[:len(q)+i+1])' {q} {-1}",
                    },
                },
                fzf_opts = {
                    ["--info"] = "hidden",
                    ["--border"] = "none",
                    ["--delimiter"] = utils.nbsp,
                },
                winopts = {
                    border = "none",
                    title = "",
                },
            })
        end

        _G.HumoodagenFindFilesOrCreate = find_files_or_create

        vim.keymap.set({ "n", "v", "x" }, "<C-k>", function(ctx)
            local mode = vim.api.nvim_get_mode().mode
            local first = mode:sub(1, 1)
            if first == "v" or mode == "V" or mode == "\022" then
                local selection = get_visual_selection()
                vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
                vim.schedule(function()
                    ctx = ctx or {}
                    ctx.query = selection
                    find_files_or_create(ctx)
                end)
                return
            end
            find_files_or_create(ctx)
        end, { desc = "Find/create files (cwd)" })

        -- Git review:
        -- - If current file has changes: toggle the sidecar unified diff.
        -- - Otherwise: show a picker of Git changes.
        local git_review = require("humoodagen.git_review")

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

        local function normalize_path(pathname)
            if type(pathname) ~= "string" or pathname == "" then
                return nil
            end
            local abs = vim.fn.fnamemodify(pathname, ":p")
            if abs == "" then
                return nil
            end
            return abs
        end

        local function get_git_root(context_path)
            local pathname = normalize_path(context_path) or normalize_path(vim.fn.getcwd())
            if not pathname then
                return nil
            end

            local dir = pathname
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
                    local pathname = vim.trim(line:sub(4))
                    local display_path = pathname

                    if status:find("R", 1, true) or status:find("C", 1, true) then
                        local parts = vim.split(pathname, " -> ", { plain = true })
                        if #parts >= 2 then
                            pathname = parts[#parts]
                        end
                    end

                    if pathname ~= "" and not seen[status .. "\n" .. pathname] then
                        seen[status .. "\n" .. pathname] = true
                        table.insert(items, {
                            text = status .. " " .. display_path,
                            path = root .. "/" .. pathname,
                            relpath = pathname,
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

            local lines = {}
            local by_line = {}
            for _, item in ipairs(items) do
                table.insert(lines, item.text)
                by_line[item.text] = item
            end

            fzf.fzf_exec(lines, {
                prompt = "Git Changes > ",
                cwd = root,
                winopts = {
                    title = "Git Changes",
                },
                fzf_opts = {
                    ["--info"] = "inline",
                    ["--multi"] = false,
                },
                actions = {
                    ["default"] = function(selected)
                        local line = selected and selected[1]
                        local item = line and by_line[line] or nil
                        if not item then
                            return
                        end

                        local win = target_win
                        if not (win and vim.api.nvim_win_is_valid(win)) then
                            win = vim.api.nvim_get_current_win()
                        end

                        local should_focus = false
                        vim.api.nvim_win_call(win, function()
                            local pathname = item.path
                            if type(pathname) ~= "string" or pathname == "" then
                                vim.notify("Invalid path.", vim.log.levels.ERROR)
                                return
                            end

                            if vim.fn.filereadable(pathname) == 0 then
                                local status = item.status or ""
                                local relpath = item.relpath or nil
                                local display = item.display_path or nil
                                local index_status = type(status) == "string" and status:sub(1, 1) or ""
                                local worktree_status = type(status) == "string" and status:sub(2, 2) or ""

                                if index_status == "D" or worktree_status == "D" then
                                    should_focus = open_git_diff_scratch(win, root, relpath or pathname, display, {
                                        cached = index_status == "D",
                                    })
                                    return
                                end

                                vim.notify("File not readable: " .. pathname, vim.log.levels.WARN)
                                return
                            end

                            vim.cmd("edit " .. vim.fn.fnameescape(pathname))
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
                    end,
                },
            })
        end

        local function ctrl_g()
            local initial_buf = vim.api.nvim_get_current_buf()
            local initial_context_path = get_context_path(initial_buf)
            local initial_name = vim.api.nvim_buf_get_name(initial_buf)
            local initial_ft = vim.bo[initial_buf].filetype
            local initial_buftype = vim.bo[initial_buf].buftype

            local target_win = find_main_edit_win()
            if not (target_win and vim.api.nvim_win_is_valid(target_win)) then
                target_win = vim.api.nvim_get_current_win()
            end

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

            open_git_changes_picker(target_win, initial_context_path)
        end

        vim.keymap.set("n", "<C-g>", ctrl_g, { desc = "Git changes / review" })
        vim.keymap.set("t", "<C-g>", function()
            vim.api.nvim_feedkeys(
                vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true),
                "n",
                false
            )
            vim.schedule(ctrl_g)
        end, { desc = "Git changes / review" })
        vim.keymap.set("i", "<C-g>", function()
            vim.cmd("stopinsert")
            vim.schedule(ctrl_g)
        end, { desc = "Git changes / review" })
    end,
}
