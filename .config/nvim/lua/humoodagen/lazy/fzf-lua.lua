return {
    "ibhagwan/fzf-lua",
    dependencies = { "echasnovski/mini.nvim" },
    config = function()
        local fzf = require("fzf-lua")
        local actions = require("fzf-lua.actions")
        local config = require("fzf-lua.config")
        local utils = require("fzf-lua.utils")
        local commands = require("humoodagen.commands")

        fzf.setup({
            files = {
                git_icons = false,
                file_icons = false,
            },
            winopts = {
                height = 0.60,
                width = 0.60,
                row = 0.35,
                col = 0.50,
                border = "rounded",
                preview = {
                    hidden = true,
                },
            },
            fzf_opts = {
                ["--layout"] = "reverse",
                ["--info"] = "inline",
                ["--prompt"] = "Files > ",
            },
        })

        local function find_files_cwd()
            fzf.files({ cwd = vim.fn.getcwd() })
        end

        vim.keymap.set("n", "<M-k>", find_files_cwd, { desc = "Find files (cwd)" })

        local function find_files_or_create(ctx)
            ctx = ctx or {}
            local origin_win = ctx.origin_win
            local origin_buf = ctx.origin_buf

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
                vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
                vim.schedule(function()
                    find_files_or_create(ctx)
                end)
                return
            end
            find_files_or_create(ctx)
        end, { desc = "Find/create files (cwd)" })
    end,
}
