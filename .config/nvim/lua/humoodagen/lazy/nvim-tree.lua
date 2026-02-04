local fast_start = vim.env.HUMOODAGEN_FAST_START == "1" and vim.fn.argc() == 0
local is_ut7 = vim.env.__CFBundleIdentifier == "com.lifeanalytics.macos"

return {
    "nvim-tree/nvim-tree.lua",
    version = "*",
    lazy = fast_start,
    event = fast_start and { "User HumoodagenToggletermPromptReady", "VeryLazy" } or nil,
    cmd = { "NvimTreeToggle", "NvimTreeOpen", "NvimTreeClose", "NvimTreeFindFileToggle", "NvimTreeFindFile" },
    keys = {
        { "<leader>pe", "<cmd>NvimTreeToggle<CR>", desc = "Toggle NvimTree" },
        { "<leader>pv", "<cmd>NvimTreeFindFileToggle<CR>", desc = "NvimTree Find File" },
    },
    dependencies = {
        "echasnovski/mini.nvim",
    },
    config = function()
        local function on_attach(bufnr)
            local api = require('nvim-tree.api')
            local undo = require("humoodagen.nvim_tree_undo")
            local Input

            local function require_input()
                if Input then
                    return Input
                end
                Input = require("nui.input")
                return Input
            end

            local function opts(desc)
                return { desc = 'nvim-tree: ' .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
            end

            -- [View] Group
            vim.keymap.set('n', 'zw', function()
                vim.wo.wrap = not vim.wo.wrap
            end, opts('[View] Toggle Wrap'))

            -- Keep j/k linewise in the tree even when wrapping is enabled.
            vim.keymap.set('n', 'j', 'j', opts('[Nav] Down'))
            vim.keymap.set('n', 'k', 'k', opts('[Nav] Up'))

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
            vim.keymap.set('n', '<D-o>', api.tree.change_root_to_node, opts('[Nav] Root to node'))
            vim.keymap.set('n', '<D-O>', api.tree.change_root_to_parent, opts('[Nav] Root up'))
            vim.keymap.set('n', '<C-b>o', api.tree.change_root_to_node, opts('[Nav] Root to node (Ctrl+B o)'))
            vim.keymap.set('n', '<C-b>O', api.tree.change_root_to_parent, opts('[Nav] Root up (Ctrl+B O)'))
            vim.keymap.set('n', '<CR>', api.node.open.edit, opts('[Nav] Open'))
            vim.keymap.set('n', 'W', api.tree.collapse_all, opts('[Nav] Collapse All'))
            vim.keymap.set('n', 'E', api.tree.expand_all, opts('[Nav] Expand All'))

            -- [File] Management Group
            vim.keymap.set('n', 'a', api.fs.create, opts('[File] Create'))

            local function same_path(a, b)
                if type(a) ~= "string" or a == "" or type(b) ~= "string" or b == "" then
                    return false
                end
                if a == b then
                    return true
                end
                local ra = vim.loop.fs_realpath(a)
                local rb = vim.loop.fs_realpath(b)
                return ra and rb and ra == rb
            end

            local function clear_open_file_buffers(path)
                if type(path) ~= "string" or path == "" then
                    return
                end

                for _, buf in ipairs(vim.api.nvim_list_bufs()) do
                    if vim.api.nvim_buf_is_loaded(buf) then
                        local name = vim.api.nvim_buf_get_name(buf)
                        if same_path(name, path) then
                            -- If the file is visible in a window, switch that window
                            -- to a fresh unnamed buffer so we don't leave the user
                            -- looking at a deleted file.
                            for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
                                if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf then
                                    vim.api.nvim_win_call(win, function()
                                        vim.cmd("enew")
                                    end)
                                end
                            end

                            -- If the buffer has unsaved edits, keep its contents but
                            -- detach it from the deleted filename to avoid E211.
                            if vim.bo[buf].modified then
                                pcall(vim.api.nvim_buf_set_name, buf, "")
                                vim.bo[buf].swapfile = false
                            else
                                pcall(vim.api.nvim_buf_delete, buf, { force = true })
                            end
                        end
                    end
                end
            end

            vim.keymap.set('n', 'x', function()
                local node = api.tree.get_node_under_cursor()
                if not node or node.name == '..' then return end

                local answer = vim.fn.confirm("Trash " .. node.name .. "?", "&yes\n&no", 2)
                if answer == 1 then
                    if node.type ~= "directory" and node.absolute_path then
                        clear_open_file_buffers(node.absolute_path)
                    end
                    if not undo.trash(node) then
                        api.fs.trash(node)
                    else
                        api.tree.reload()
                    end
                end
            end, opts('[File] Trash'))
            vim.keymap.set('n', 'r', function()
                local original = vim.ui.input

                vim.ui.input = function(input_opts, on_confirm)
                    local Input = require_input()
                    local prompt = (input_opts and input_opts.prompt) or "Rename to "
                    local default_value = ""
                    if input_opts then
                        default_value = input_opts.default or input_opts.default_value or ""
                    end

                    local input = Input({
                        relative = "cursor",
                        position = { row = 1, col = 0 },
                        size = { width = math.min(80, math.max(24, #prompt + #default_value + 10)) },
                        border = { style = "rounded", text = { top = "Rename", top_align = "left" } },
                        win_options = { winblend = 0 },
                    }, {
                        prompt = prompt,
                        default_value = default_value,
                        on_submit = function(value)
                            vim.ui.input = original
                            on_confirm(value)
                        end,
                        on_close = function()
                            vim.ui.input = original
                            on_confirm(nil)
                        end,
                    })

                    input:mount()

                    -- Keep <Esc> for Normal-mode editing inside the prompt; use
                    -- <C-c> to cancel the rename prompt.
                    local function cancel()
                        pcall(function()
                            input:unmount()
                        end)
                    end
                    vim.keymap.set({ "n", "i" }, "<C-c>", cancel, { buffer = input.bufnr, noremap = true, silent = true, nowait = true })
                end

                local ok, err = pcall(api.fs.rename)
                if not ok then
                    vim.ui.input = original
                    error(err)
                end
            end, opts('[File] Rename'))
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
                local Input = require_input()

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
	            hijack_unnamed_buffer_when_opening = false,
	            sync_root_with_cwd = true,
	            update_focused_file = {
	                enable = true,
	                update_root = false,
	            },
	            sort_by = "case_sensitive",
	            ui = {
	                confirm = {
	                    remove = false,
	                    trash = false,
                },
		            },
		            git = {
		                enable = vim.env.HUMOODAGEN_FAST_START ~= "1" and not is_ut7,
		                ignore = false,
		                timeout = 400,
		            },
            actions = {
                open_file = {
                    -- Don't force the tree back to `view.width` whenever a file is opened.
                    -- This keeps manual `:vertical resize` adjustments stable.
                    resize_window = false,
                },
            },
            view = {
                number = true,
                relativenumber = vim.env.HUMOODAGEN_FAST_START ~= "1",
                signcolumn = "no",
                width = "7.5%",
            },
            renderer = {
                add_trailing = false,
                group_empty = true,
                highlight_git = "name",
                -- Show only the last folder segment (e.g. "/analytics-dash") in
                -- the tree header instead of the full path, and truncate to
                -- avoid wrapping in narrow tree widths.
                root_folder_label = function(path)
                    if type(path) ~= "string" or path == "" then
                        return ""
                    end

                    local clean = path:gsub("[/\\]+$", "")
                    local name = vim.fn.fnamemodify(clean, ":t")
                    if name == "" then
                        name = clean
                    end

                    local label = "/" .. name

                    local max = 30
                    local ok_view, view = pcall(require, "nvim-tree.view")
                    if ok_view then
                        local win = view.get_winnr()
                        if win and vim.api.nvim_win_is_valid(win) then
                            max = math.max(8, vim.api.nvim_win_get_width(win) - 2)
                        end
                    end

                    if vim.fn.strdisplaywidth(label) <= max then
                        return label
                    end

                    -- Keep the end of the folder name (right side), and always
                    -- show a "/" prefix for readability.
                    local keep = math.max(1, max - 2) -- "…/"
                    local chars = vim.fn.strchars(name)
                    local tail = vim.fn.strcharpart(name, math.max(0, chars - keep), keep)
                    return "…/" .. tail
                end,
                indent_markers = {
                    enable = false,
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
                    web_devicons = {
                        file = { enable = false, color = false },
                        -- mini.icons can mock `nvim-web-devicons` for files, but
                        -- the devicons API can't tell "folder vs file name".
                        -- Keep folders on nvim-tree glyphs, and use devicons
                        -- only for file icons.
                        folder = { enable = false },
                    },
                    padding = {
                        icon = "",
                    },
                    show = {
                        file = false,
                        folder = true,
                        folder_arrow = false,
                        git = false,
                    },
                    glyphs = {
                        folder = {
                            arrow_closed = "",
                            arrow_open = "",
                            default = "▏",
                            open = "▏",
                            empty = "▏",
                            empty_open = "▏",
                            symlink = "▏",
                            symlink_open = "▏",
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
        events.subscribe(events.Event.TreeOpen, function()
            local ok_view, view = pcall(require, "nvim-tree.view")
            if not ok_view then
                return
            end
            local win = view.get_winnr()
            if win and vim.api.nvim_win_is_valid(win) then
                local buf = vim.api.nvim_win_get_buf(win)
                vim.wo[win].wrap = false
                vim.wo[win].linebreak = true
                vim.wo[win].breakindent = true
                vim.wo[win].breakindentopt = "list:-1"
                -- Make wrapped tree entries align under the filename (not at col 0).
                -- Uses breakindentopt=list:-1 and a tree-specific formatlistpat.
                vim.bo[buf].formatlistpat = "^\\%((│\\s\\|└\\s\\|  )\\+\\)\\ze\\S"
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

	        local function perf_mark(label, extra)
	            if vim.env.HUMOODAGEN_PERF ~= "1" then
	                return
	            end
            local ok, perf = pcall(require, "humoodagen.perf")
            if ok then
                perf.mark(label, extra)
            end
	        end
	
		        -- Open nvim-tree on startup if no file is specified
		        local function open_nvim_tree(data)
		            local no_args = data.file == ""
		            local directory = vim.fn.isdirectory(data.file) == 1
	
	            if not no_args and not directory then
	                return false
	            end
	
	            perf_mark("nvim-tree:open:start", data.file)
	
	            -- change to the directory
		            if directory then
		                vim.cmd.cd(data.file)
		            end
		
		            -- open the tree
		            local origin_win = vim.api.nvim_get_current_win()
		            local origin_mode = vim.api.nvim_get_mode().mode

		            local function find_main_win()
		                for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		                    local buf = vim.api.nvim_win_get_buf(win)
		                    local ft = vim.bo[buf].filetype
		                    if ft ~= "NvimTree" and ft ~= "toggleterm" then
		                        return win
		                    end
		                end
		                return nil
		            end

		            local function desired_tree_width()
		                local ok_view, view = pcall(require, "nvim-tree.view")
		                if not ok_view then
		                    return nil
		                end

		                local width = view.View and view.View.width or nil
		                if type(width) == "number" then
		                    return width
		                end
		                if type(width) == "string" and width:sub(-1) == "%" then
		                    local n = tonumber(width:sub(1, -2))
		                    if n then
		                        return math.floor(vim.o.columns * (n / 100))
		                    end
		                end
		                return nil
		            end

		            local function open_tree_stable()
		                local ok_view, view = pcall(require, "nvim-tree.view")
		                local ok_api, api = pcall(require, "nvim-tree.api")
		                if not ok_api then
		                    return
		                end

		                if ok_view and view.is_visible() then
		                    return
		                end

		                local target_win = vim.g.humoodagen_startup_tree_winid
		                if not (target_win and vim.api.nvim_win_is_valid(target_win)) then
		                    -- Create a full-height left split at the final width, then open the
		                    -- tree inside that window without any extra reposition/resize.
		                    local width = desired_tree_width()
		                    if type(width) == "number" and width > 0 then
		                        vim.cmd("topleft " .. tostring(width) .. "vsplit")
		                    else
		                        vim.cmd("topleft vsplit")
		                    end
		                    target_win = vim.api.nvim_get_current_win()
		                end

		                api.tree.open({ winid = target_win, focus = false })
		                vim.g.humoodagen_startup_tree_opened = true
		                vim.g.humoodagen_startup_tree_winid = nil
		            end

		            local main_win = find_main_win()
		            if vim.env.HUMOODAGEN_FAST_START == "1" and vim.fn.argc() == 0 and main_win then
		                pcall(vim.api.nvim_win_call, main_win, open_tree_stable)
		            else
		                require("nvim-tree.api").tree.open({ focus = false })
		            end

		            if origin_win and vim.api.nvim_win_is_valid(origin_win) then
		                vim.api.nvim_set_current_win(origin_win)
		            end

		            if type(origin_mode) == "string"
		                and origin_mode:sub(1, 1) == "t"
		                and vim.api.nvim_get_mode().mode:sub(1, 1) ~= "t"
		            then
		                vim.cmd("startinsert")
		            end
		            perf_mark("nvim-tree:open:done")
		            return true
		        end

                local function schedule_fast_start_open()
                    if not fast_start then
                        return
                    end
                    if vim.g.humoodagen_startup_tree_opened == true then
                        return
                    end

                    local buf = vim.api.nvim_get_current_buf()
                    local startup_data = { file = "", buf = buf }
                    local opened = false

                    local function open_once(source)
                        if opened then
                            return
                        end
                        if open_nvim_tree(startup_data) then
                            opened = true
                            perf_mark("nvim-tree:open:source", source)
                        end
                    end

                    if vim.g.humoodagen_toggleterm_prompt_ready == true then
                        vim.schedule(function()
                            open_once("prompt_ready")
                        end)
                        return
                    end

                    local group = vim.api.nvim_create_augroup("HumoodagenNvimTreeFastStartOpen", { clear = true })
                    vim.api.nvim_create_autocmd("User", {
                        group = group,
                        pattern = "HumoodagenToggletermPromptReady",
                        once = true,
                        callback = function()
                            vim.schedule(function()
                                open_once("prompt_ready")
                            end)
                        end,
                    })

                    vim.defer_fn(function()
                        open_once("fallback_delay")
                    end, 300)
                end

                schedule_fast_start_open()
	
	        vim.api.nvim_create_autocmd("UIEnter", {
	            once = true,
	            callback = function()
	                if fast_start then
	                    return
	                end
	                if vim.g.humoodagen_startup_tree_opened == true then
	                    return
	                end
	                local buf = vim.api.nvim_get_current_buf()
	                local file = vim.fn.argc() > 0 and vim.fn.argv(0) or ""
	                local startup_data = { file = file, buf = buf }
	                local opened = false

	                local function open_once(source)
	                    if opened then
	                        return
	                    end
	                    if open_nvim_tree(startup_data) then
	                        opened = true
	                        perf_mark("nvim-tree:open:source", source)
	                    end
	                end

	                open_once("uienter")
	            end,
	        })

        local function ensure_nvim_tree_normal_mode()
            local buf = vim.api.nvim_get_current_buf()
            if not (buf and vim.api.nvim_buf_is_valid(buf)) then
                return
            end
            if vim.bo[buf].filetype ~= "NvimTree" then
                return
            end

            local mode = vim.api.nvim_get_mode().mode
            local first = type(mode) == "string" and mode:sub(1, 1) or ""
            if first == "i" or first == "R" then
                pcall(vim.cmd, "stopinsert")
            elseif first == "t" then
                vim.api.nvim_feedkeys(
                    vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true),
                    "n",
                    false
                )
            end
        end

        local nvim_tree_mode_group = vim.api.nvim_create_augroup("HumoodagenNvimTreeNormalMode", { clear = true })
        vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
            group = nvim_tree_mode_group,
            callback = function()
                vim.schedule(ensure_nvim_tree_normal_mode)
            end,
        })
        vim.api.nvim_create_autocmd("ModeChanged", {
            group = nvim_tree_mode_group,
            callback = function()
                vim.schedule(ensure_nvim_tree_normal_mode)
            end,
        })

        vim.api.nvim_create_autocmd("FileType", {
            pattern = "NvimTree",
            callback = function()
                vim.schedule(ensure_nvim_tree_normal_mode)
                vim.opt_local.numberwidth = 1
                vim.opt_local.signcolumn = "no"
                vim.opt_local.winbar = ""
            end,
        })
    end,
}
