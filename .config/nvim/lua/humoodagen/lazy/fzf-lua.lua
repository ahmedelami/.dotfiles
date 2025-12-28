return {
    "ibhagwan/fzf-lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
        local fzf = require("fzf-lua")
        local actions = require("fzf-lua.actions")
        local config = require("fzf-lua.config")
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

        local function find_files_or_create()
            local default_actions = config.globals.actions.files
            local file_actions = vim.tbl_extend("force", {}, default_actions, {
                ["enter"] = function(selected, opts)
                    if selected and #selected > 0 then
                        return actions.file_edit_or_qf(selected, opts)
                    end

                    local query = opts.last_query
                    if type(query) ~= "string" or vim.fn.trim(query) == "" then
                        return
                    end

                    commands.create_path(query)
                end,
            })

            fzf.files({
                cwd = vim.fn.getcwd(),
                actions = file_actions,
                headers = false,
                cwd_prompt = false,
                prompt = "",
                fzf_opts = {
                    ["--info"] = "hidden",
                    ["--border"] = "none",
                },
                winopts = {
                    border = "none",
                    title = "",
                },
            })
        end

        vim.keymap.set("n", "<C-e>", find_files_or_create, { desc = "Find/create files (cwd)" })
    end,
}
