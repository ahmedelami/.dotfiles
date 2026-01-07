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
            local Input = require("nui.input")
            local undo = require("humoodagen.nvim_tree_undo")

            local function opts(desc)
                return { desc = 'nvim-tree: ' .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
            end

            -- [Nav]igation Group
            vim.keymap.set('n', 'l', api.node.open.edit, opts('[Nav] Open/Expand'))
            vim.keymap.set('n', 'h', function()
                local node = api.tree.get_node_under_cursor()
                if not node then
                    return
                end
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
                if not node or node.name == '..' then return end

                local answer = vim.fn.confirm("Trash " .. node.name .. "?", "&yes\n&no", 2)
                if answer == 1 then
                    if not undo.trash(node) then
                        api.fs.trash(node)
                    else
                        api.tree.reload()
                    end
                end
            end, opts('[File] Trash'))
            vim.keymap.set('n', 'r', api.fs.rename, opts('[File] Rename'))
            vim.keymap.set('n', 'c', api.fs.copy.node, opts('[File] Copy'))
            vim.keymap.set('n', 'p', api.fs.paste, opts('[File] Paste'))
            vim.keymap.set('n', 'u', function()
                undo.undo_last()
            end, opts('[Undo] Last Action'))

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

            local function inline_create()
                local node = api.tree.get_node_under_cursor()
                if not node then
                    return
                end

                local base_dir = node.absolute_path
                if node.type ~= "directory" then
                    base_dir = (node.parent and node.parent.absolute_path) or vim.fn.fnamemodify(base_dir, ":h")
                end

                local rel_base = vim.fn.fnamemodify(base_dir, ":.")
                if rel_base == "" then
                    rel_base = base_dir
                end

                local path_sep = package.config:sub(1, 1)
                local prompt = rel_base
                if prompt:sub(-1) ~= path_sep then
                    prompt = prompt .. path_sep
                end

                local input = Input({
                    relative = "cursor",
                    position = { row = 1, col = 0 },
                    size = { width = math.min(80, math.max(24, #prompt + 10)) },
                    border = { style = "rounded", text = { top = "New", top_align = "left" } },
                    win_options = { winblend = 0 },
                }, {
                    prompt = prompt,
                    on_submit = function(value)
                        if not value or vim.fn.trim(value) == "" then
                            return
                        end

                        local target = value
                        if target:sub(1, 1) ~= path_sep and not target:match("^%a:[/\\]") then
                            target = base_dir .. path_sep .. target
                        end

                        local is_dir = target:sub(-1) == path_sep
                        local dir_path = is_dir and target or vim.fn.fnamemodify(target, ":h")
                        if dir_path ~= "" then
                            vim.fn.mkdir(dir_path, "p")
                        end
                        if not is_dir then
                            local ok, fd = pcall(vim.loop.fs_open, target, "w", 420)
                            if ok and type(fd) == "number" then
                                vim.loop.fs_close(fd)
                            end
                        end

                        local record_path = target
                        if record_path:sub(-1) == path_sep then
                            record_path = record_path:sub(1, -2)
                        end
                        undo.record_create(record_path)

                        api.tree.reload()
                        api.tree.find_file({ buf = target, open = true, focus = true })
                    end,
                })

                input:mount()
            end

            vim.keymap.set('n', 'i', inline_create, opts('[File] Inline Create'))
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
                number = true,
                relativenumber = true,
                signcolumn = "no",
                width = "15%",
            },
            renderer = {
                group_empty = true,
                highlight_git = "name",
                indent_markers = {
                    enable = true,
                    inline_arrows = false,
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
                        folder = true,
                        folder_arrow = false,
                        git = true,
                    },
                    glyphs = {
                        folder = {
                            arrow_closed = "",
                            arrow_open = "",
                            default = "",
                            open = "",
                            empty = "",
                            empty_open = "",
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

        local undo = require("humoodagen.nvim_tree_undo")
        local events = require("nvim-tree.events")
        events.subscribe(events.Event.FileCreated, function(payload)
            if payload and payload.fname then
                undo.record_create(payload.fname)
            end
        end)
        events.subscribe(events.Event.FolderCreated, function(payload)
            if payload and payload.folder_name then
                undo.record_create(payload.folder_name)
            end
        end)
        events.subscribe(events.Event.NodeRenamed, function(payload)
            if payload and payload.old_name and payload.new_name then
                undo.record_rename(payload.old_name, payload.new_name)
            end
        end)

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
            return true
        end

        local function ensure_main_edit_win()
            for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
                if is_main_edit_win(win) then
                    return
                end
            end

            local view = require("nvim-tree.view")
            local tree_win = view.get_winnr()
            if not (tree_win and vim.api.nvim_win_is_valid(tree_win)) then
                return
            end

            vim.api.nvim_set_current_win(tree_win)
            vim.cmd("vsplit")
            local new_win = vim.api.nvim_get_current_win()
            vim.cmd("enew")
            if vim.api.nvim_win_is_valid(tree_win) then
                vim.api.nvim_set_current_win(tree_win)
            end

            local ok_api, api = pcall(require, "nvim-tree.api")
            if ok_api then
                api.tree.resize()
            end
        end

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
            ensure_main_edit_win()
        end

        vim.api.nvim_create_autocmd({ "VimEnter" }, { callback = open_nvim_tree })
        vim.api.nvim_create_autocmd("FileType", {
            pattern = "NvimTree",
            callback = function()
                vim.opt_local.numberwidth = 1
                vim.opt_local.signcolumn = "no"
                ensure_main_edit_win()
            end,
        })
    end,
}
