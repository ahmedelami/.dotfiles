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

        vim.api.nvim_create_autocmd("FileType", {
            pattern = "fzf",
            callback = function(event)
                vim.keymap.set("t", "<C-k>", "<C-c>", {
                    buffer = event.buf,
                    nowait = true,
                    silent = true,
                    desc = "Close fzf (Ctrl+K toggle)",
                })
            end,
        })

        local function find_files_cwd()
            fzf.files({ cwd = vim.fn.getcwd() })
        end

        vim.keymap.set("n", "<M-k>", find_files_cwd, { desc = "Find files (cwd)" })

        local function find_files_or_create()
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
            local file_actions = vim.tbl_extend("force", {}, default_actions, {
                ["enter"] = accept_or_create,
                ["tab"] = accept_or_create,
            })

            fzf.files({
                cwd = vim.fn.getcwd(),
                actions = file_actions,
                headers = false,
                cwd_prompt = false,
                prompt = "",
                keymap = {
                    fzf = {
                        ["ctrl-k"] = "abort",
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

        vim.keymap.set("n", "<C-k>", find_files_or_create, { desc = "Find/create files (cwd)" })
    end,
}
