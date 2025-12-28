return {
    "nvim-tree/nvim-tree.lua",
    version = "*",
    lazy = false,
    dependencies = {
        "nvim-tree/nvim-web-devicons",
    },
    config = function()
        local function on_attach(bufnr)
            local api = require('nvim-tree.api')

            local function opts(desc)
                return { desc = 'nvim-tree: ' .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
            end

            -- [Nav]igation Group
            vim.keymap.set('n', 'l', api.node.open.edit, opts('[Nav] Open/Expand'))
            vim.keymap.set('n', 'h', function()
                local node = api.tree.get_node_under_cursor()
                if node.type == 'directory' and node.open then
                    api.node.open.edit()
                else
                    api.node.navigate.parent_close()
                end
            end, opts('[Nav] Collapse/Parent'))
            vim.keymap.set('n', '<CR>', api.node.open.edit, opts('[Nav] Open'))
            vim.keymap.set('n', 'W', api.tree.collapse_all, opts('[Nav] Collapse All'))
            vim.keymap.set('n', 'E', api.tree.expand_all, opts('[Nav] Expand All'))

            -- [File] Management Group
            vim.keymap.set('n', 'a', api.fs.create, opts('[File] Create'))
            vim.keymap.set('n', 'x', function()
                local node = api.tree.get_node_under_cursor()
                if node.name == '..' then return end
                
                local answer = vim.fn.confirm("Trash " .. node.name .. "?", "&yes\n&no", 2)
                if answer == 1 then
                    api.fs.trash(node)
                end
            end, opts('[File] Trash'))
            vim.keymap.set('n', 'r', api.fs.rename, opts('[File] Rename'))
            vim.keymap.set('n', 'c', api.fs.copy.node, opts('[File] Copy'))
            vim.keymap.set('n', 'p', api.fs.paste, opts('[File] Paste'))

            -- [Mark] Bulk Operations Group
            vim.keymap.set('n', 'm', api.marks.toggle, opts('[Mark] Toggle Selection'))
            vim.keymap.set('n', 'M', api.marks.bulk.move, opts('[Mark] Bulk Move Selected'))
            vim.keymap.set('n', 'D', api.marks.bulk.delete, opts('[Mark] Bulk Delete Selected'))

            -- [System] & Filters Group
            vim.keymap.set('n', 'q', api.tree.close, opts('[System] Quit'))
            vim.keymap.set('n', 'R', api.tree.reload, opts('[System] Refresh'))
            vim.keymap.set('n', 'H', api.tree.toggle_hidden_filter, opts('[System] Toggle Hidden (Dotfiles)'))
            vim.keymap.set('n', 'I', api.tree.toggle_gitignore_filter, opts('[System] Toggle Git Ignore'))
            vim.keymap.set('n', '?', api.tree.toggle_help, opts('[System] Show Help'))
        end

        require("nvim-tree").setup({
            on_attach = on_attach,
            trash = {
                cmd = "trash", -- Requires 'trash-cli' or similar on your system
            },
            hijack_netrw = true,
            hijack_unnamed_buffer_when_opening = true,
            sort_by = "case_sensitive",
            ui = {
                confirm = {
                    remove = false,
                    trash = false,
                },
            },
            git = {
                enable = true,
                ignore = false,
                timeout = 400,
            },
            view = {
                width = 30,
            },
            renderer = {
                group_empty = true,
                highlight_git = "name",
                indent_markers = {
                    enable = true,
                    inline_arrows = true,
                    icons = {
                        corner = "└",
                        edge = "│",
                        item = "│",
                        bottom = "─",
                        none = " ",
                    },
                },
                icons = {
                    git_placement = "after",
                    show = {
                        file = true,
                        folder = false,
                        folder_arrow = true,
                        git = true,
                    },
                    glyphs = {
                        folder = {
                            arrow_closed = "",
                            arrow_open = "",
                        },
                        git = {
                            unstaged = "",
                            staged = "",
                            unmerged = "",
                            renamed = "",
                            untracked = "",
                            deleted = "",
                            ignored = "",
                        },
                    },
                },
            },
            filters = {
                dotfiles = false,
            },
        })

        vim.keymap.set("n", "<leader>pe", "<cmd>NvimTreeToggle<CR>", { desc = "Toggle NvimTree" })
        vim.keymap.set("n", "<leader>pv", "<cmd>NvimTreeFindFileToggle<CR>", { desc = "NvimTree Find File" })

        -- Open nvim-tree on startup if no file is specified
        local function open_nvim_tree(data)
            -- buffer is a [No Name]
            local no_name = data.file == "" and vim.bo[data.buf].buftype == ""

            -- buffer is a directory
            local directory = vim.fn.isdirectory(data.file) == 1

            if not no_name and not directory then
                return
            end

            -- change to the directory
            if directory then
                vim.cmd.cd(data.file)
            end

            -- open the tree
            require("nvim-tree.api").tree.open()
        end

        vim.api.nvim_create_autocmd({ "VimEnter" }, { callback = open_nvim_tree })
    end,
}
