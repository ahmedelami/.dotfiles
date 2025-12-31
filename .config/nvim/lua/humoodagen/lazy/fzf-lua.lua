return {
    "ibhagwan/fzf-lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
        local fzf = require("fzf-lua")
        local actions = require("fzf-lua.actions")
        local config = require("fzf-lua.config")
        local utils = require("fzf-lua.utils")
        local commands = require("humoodagen.commands")

        fzf.setup({
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

            local function jump_back_to_origin()
                if origin_win and vim.api.nvim_win_is_valid(origin_win) then
                    vim.api.nvim_set_current_win(origin_win)
                    return
                end

                if origin_buf and vim.api.nvim_buf_is_valid(origin_buf) then
                    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
                        if vim.api.nvim_win_get_buf(win) == origin_buf then
                            vim.api.nvim_set_current_win(win)
                            return
                        end
                    end
                end
            end

            local function abort_and_restore()
                vim.schedule(jump_back_to_origin)
            end

            local file_actions = vim.tbl_extend("force", {}, default_actions, {
                ["enter"] = accept_or_create,
                ["tab"] = accept_or_create,
                ["_humoodagen_abort"] = abort_and_restore,
            })

            fzf.files({
                cwd = vim.fn.getcwd(),
                actions = file_actions,
                headers = false,
                cwd_prompt = false,
                prompt = "",
                keymap = {
                    fzf = {
                        ["ctrl-k"] = "print(_humoodagen_abort)+abort",
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

        vim.keymap.set({ "n", "v", "x" }, "<C-k>", function(ctx)
            local mode = vim.api.nvim_get_mode().mode
            local first = mode:sub(1, 1)
            if first == "v" or mode == "V" or mode == "\022" then
                vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
                vim.schedule(function()
                    find_files_or_create(ctx)
                end)
                return
            end
            find_files_or_create(ctx)
        end, { desc = "Find/create files (cwd)" })
    end,
}
