local ide_like = vim.g.humoodagen_profile == "ide_like_exp"
local fast_start = ide_like and vim.env.HUMOODAGEN_FAST_START == "1" and vim.fn.argc() == 0
local is_ut7 = vim.env.__CFBundleIdentifier == "com.lifeanalytics.macos"

return {
    "nvim-tree/nvim-tree.lua",
    version = "*",
    lazy = fast_start,
    event = fast_start and { "User HumoodagenToggletermPromptReady", "VeryLazy" } or nil,
    cmd = { "NvimTreeToggle", "NvimTreeOpen", "NvimTreeClose", "NvimTreeFindFileToggle", "NvimTreeFindFile" },
    keys = {
        { "<leader>pe", "<cmd>NvimTreeToggle<CR>", desc = "Toggle NvimTree" },
        { "<leader>pV", "<cmd>NvimTreeFindFileToggle<CR>", desc = "NvimTree Find File" },
    },
    dependencies = {
        "echasnovski/mini.nvim",
        "nvim-tree/nvim-web-devicons",
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
		            hijack_directories = {
		                enable = true,
		            },
		            hijack_unnamed_buffer_when_opening = true,
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
		                enable = (not fast_start) and not is_ut7,
		                ignore = false,
		                timeout = 400,
		            },
            actions = {
                open_file = {
                    -- Don't force the tree back to `view.width` whenever a file is opened.
                    -- This keeps manual `:vertical resize` adjustments stable.
                    resize_window = false,
                    quit_on_open = true,
                },
            },
            view = {
                number = true,
                relativenumber = not fast_start,
                signcolumn = "no",
                width = "25%",
            },
		            renderer = {
		                add_trailing = false,
		                group_empty = false,
		                indent_width = 1,
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
		                        file = { enable = true, color = true },
		                        folder = { enable = false },
		                    },
                    padding = {
                        icon = " ",
                    },
		                    show = {
		                        file = true,
		                        folder = true,
		                        folder_arrow = false,
		                        git = false,
		                    },
			                    glyphs = {
			                        folder = {
			                            arrow_closed = "",
			                            arrow_open = "",
			                            default = "",
			                            open = "",
			                            empty = "",
			                            empty_open = "",
			                            symlink = "",
			                            symlink_open = "",
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
            tab = {
                sync = {
                    open = false,
                    close = false,
                },
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

        local function node_depth(node)
            if not node or type(node) ~= "table" then
                return 0
            end

            local depth = 0
            local parent = node.parent
            while parent and parent.parent do
                depth = depth + 1
                parent = parent.parent
            end
            return depth
        end

	        local function expand_tree_levels(levels)
	            local ok_api, api = pcall(require, "nvim-tree.api")
	            if not ok_api then
	                return
	            end

	            local n = tonumber(levels) or 0
	            if n <= 1 then
	                return
	            end

	            local function contains(tbl, value)
	                if type(tbl) ~= "table" then
	                    return false
	                end
	                for _, v in ipairs(tbl) do
	                    if v == value then
	                        return true
	                    end
	                end
	                return false
	            end

	            local function is_git_ignored_or_untracked_dir(node)
	                if type(node) ~= "table" or node.type ~= "directory" then
	                    return false
	                end

	                local status = node.git_status
	                if type(status) ~= "table" then
	                    return false
	                end

	                if status.file == "!!" or status.file == "??" then
	                    return true
	                end

	                local dir = status.dir
	                if type(dir) ~= "table" then
	                    return false
	                end

	                return contains(dir.direct, "??") or contains(dir.indirect, "??")
	            end

	            local expand_depth = n - 1
	            api.tree.expand_all(nil, {
	                expand_until = function(_, node)
	                    if not node or node.type ~= "directory" then
	                        return false
	                    end

	                    local name = type(node.name) == "string" and node.name or ""
	                    if name == "node_modules" then
	                        return false
	                    end
	                    if name:sub(1, 1) == "." then
	                        return false
	                    end
	                    if is_git_ignored_or_untracked_dir(node) then
	                        return false
	                    end

	                    return node_depth(node) < expand_depth
	                end,
	            })
	        end

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
                -- VS Code-style scrolling in the tree (no top/bottom margins).
                -- This also keeps the sticky header logic stable, because the
                -- top visible row stays inside the currently-selected subtree.
                vim.wo[win].scrolloff = 0
                vim.wo[win].sidescrolloff = 0
                vim.wo[win].breakindent = true
                vim.wo[win].breakindentopt = "list:-1"
                -- Make wrapped tree entries align under the filename (not at col 0).
                -- Uses breakindentopt=list:-1 and a tree-specific formatlistpat.
                vim.bo[buf].formatlistpat = "^\\%((│\\s\\|└\\s\\|  )\\+\\)\\ze\\S"
	            end
	
	            vim.schedule(function()
	                local levels = vim.g.humoodagen_nvim_tree_expand_levels
	                if levels == nil then
	                    levels = vim.env.HUMOODAGEN_NVIM_TREE_EXPAND_LEVELS
	                end
	                if levels == nil or levels == "" then
	                    levels = 1
	                end

	                expand_tree_levels(levels)
	            end)
        end)

	        local open_pipe_ns = vim.api.nvim_create_namespace("HumoodagenNvimTreeOpenPipes")
	        local sticky_header_ns = vim.api.nvim_create_namespace("HumoodagenNvimTreeStickyHeader")
	        local sticky_overlay_ns = vim.api.nvim_create_namespace("HumoodagenNvimTreeStickyOverlay")
	        local nvim_tree_cache = {}

	        local enable_open_pipes = true
	        local sticky_overlay_state = {}

        local function sticky_header_lnums(bufnr, top_lnum)
            local cache = nvim_tree_cache[bufnr]
            if type(cache) ~= "table" then
                return nil, "no_cache"
            end

            local w0 = tonumber(top_lnum) or 0
            local start_line = tonumber(cache.start_line) or 1
            if w0 < start_line then
                return nil, "above_start_line:" .. tostring(start_line)
            end

            local nodes_by_line = cache.nodes_by_line
            if type(nodes_by_line) ~= "table" then
                return nil, "no_nodes_by_line"
            end

            local line_for_path = cache.line_for_path
            if type(line_for_path) ~= "table" then
                return nil, "no_line_for_path"
            end

            local node = nodes_by_line[w0]
            local node_lnum = w0
            if type(node) ~= "table" then
                -- In rare cases the topline can be on a non-node row (e.g. blank
                -- padding at the end). Prefer the next node down, otherwise the
                -- nearest node up.
                for delta = 1, 12 do
                    local down_lnum = w0 + delta
                    local down = nodes_by_line[down_lnum]
                    if type(down) == "table" then
                        node = down
                        node_lnum = down_lnum
                        break
                    end

                    local up_lnum = w0 - delta
                    if up_lnum >= start_line then
                        local up = nodes_by_line[up_lnum]
                        if type(up) == "table" then
                            node = up
                            node_lnum = up_lnum
                            break
                        end
                    end
                end
            end
            if type(node) ~= "table" then
                return nil, "no_node_near:" .. tostring(w0)
            end

            -- Prefer the node parent chain for stacking: it's O(depth) and avoids
            -- edge cases where indentation-based ranges get out of sync.
            --
            -- VS Code-style: only "stick" directories once their own row has scrolled
            -- above the top visible line (lnum < w0).
            local lnums = {}
            local seen = {}
            local cur = node
            while type(cur) == "table" do
                if cur.type == "directory" then
                    local path = cur.absolute_path
                    if type(path) == "string" then
                        local lnum = line_for_path[path]
                        if type(lnum) == "number" and lnum < node_lnum and not seen[lnum] then
                            lnums[#lnums + 1] = lnum
                            seen[lnum] = true
                        end
                    end
                end
                cur = cur.parent
            end

            if #lnums == 0 then
                return nil, "no_dirs"
            end

            table.sort(lnums)
            return lnums, "ok"
        end

        local function sticky_header_virt_lines(bufnr, lnums)
            if type(lnums) ~= "table" or #lnums == 0 then
                return nil
            end

            local cache = nvim_tree_cache[bufnr]
            if type(cache) ~= "table" then
                return nil
            end

            local marks = cache.pipe_marks
            local blue_pipe = "▕"
            local grey_pipe = "│"

            local virt_lines = {}
            for _, lnum in ipairs(lnums) do
                local row = lnum - 1
                local base = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
                local first_non_space = base:find("%S")
                local icon_col = (first_non_space and (first_non_space - 1)) or 0

                local row_marks = (type(marks) == "table") and marks[row] or nil
                local prefix_cells = {}
                for _ = 1, icon_col do
                    prefix_cells[#prefix_cells + 1] = " "
                end
                if type(row_marks) == "table" then
                    for col, kind in pairs(row_marks) do
                        if type(col) == "number" and col >= 0 and col < icon_col then
                            prefix_cells[col + 1] = (kind == "blue") and blue_pipe or grey_pipe
                        end
                    end
                end

                local icon_charidx = vim.str_utfindex(base, icon_col)
                local icon = vim.fn.strcharpart(base, icon_charidx, 1)
                local name = vim.fn.strcharpart(base, icon_charidx + 2)
                if icon == "" then
                    icon = blue_pipe
                end
	                local icon_hl = (icon == "" and "NvimTreeClosedFolderIcon")
	                    or (icon == "" and "NvimTreeOpenedFolderIcon")
	                    or (icon == "" and "NvimTreeFolderArrowClosed")
	                    or (icon == "" and "NvimTreeFolderArrowOpen")
	                    or "NvimTreeFolderIcon"

                local segments = {}
                for _, cell in ipairs(prefix_cells) do
                    if cell == blue_pipe then
                        segments[#segments + 1] = { blue_pipe, "NvimTreeFolderIcon" }
                    elseif cell == grey_pipe then
                        segments[#segments + 1] = { grey_pipe, "NvimTreeIndentMarker" }
                    else
                        segments[#segments + 1] = { " ", "NvimTreeNormal" }
                    end
                end

                segments[#segments + 1] = { icon, icon_hl }
                segments[#segments + 1] = { " ", "NvimTreeNormal" }
                if name ~= "" then
                    segments[#segments + 1] = { name, "NvimTreeFolderName" }
                end

                virt_lines[#virt_lines + 1] = segments
            end

            return virt_lines
        end

	        local function get_overlay_state(tree_win)
	            local state = sticky_overlay_state[tree_win]
	            if type(state) ~= "table" then
	                state = {}
	                sticky_overlay_state[tree_win] = state
	            end
	            return state
	        end

	        local function overlay_close(tree_win)
	            local state = sticky_overlay_state[tree_win]
	            if type(state) ~= "table" then
	                return
	            end

	            if state.win and vim.api.nvim_win_is_valid(state.win) then
	                pcall(vim.api.nvim_win_close, state.win, true)
	            end
	            state.win = nil
	        end

	        local function overlay_ensure_buf(state)
	            if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
	                return state.buf
	            end

	            local buf = vim.api.nvim_create_buf(false, true)
	            vim.bo[buf].buftype = "nofile"
	            vim.bo[buf].bufhidden = "hide"
	            vim.bo[buf].swapfile = false
	            vim.bo[buf].modifiable = false
	            vim.bo[buf].filetype = "NvimTreeStickyHeader"
	            state.buf = buf
	            return buf
	        end

	        local function overlay_ensure_win(tree_win, state, width, height)
	            if state.win and vim.api.nvim_win_is_valid(state.win) then
	                pcall(vim.api.nvim_win_set_config, state.win, {
	                    relative = "win",
	                    win = tree_win,
	                    row = 0,
	                    col = 0,
	                    width = width,
	                    height = height,
	                    style = "minimal",
	                    focusable = false,
	                    zindex = 251,
	                })
	                return state.win
	            end

	            local buf = overlay_ensure_buf(state)
	            local win = vim.api.nvim_open_win(buf, false, {
	                relative = "win",
	                win = tree_win,
	                row = 0,
	                col = 0,
	                width = width,
	                height = height,
	                style = "minimal",
	                focusable = false,
	                noautocmd = true,
	                zindex = 251,
	            })
	            state.win = win

	            vim.wo[win].wrap = false
	            vim.wo[win].cursorline = false
	            vim.wo[win].number = false
	            vim.wo[win].relativenumber = false
	            vim.wo[win].signcolumn = "no"
	            vim.wo[win].foldcolumn = "0"
	            vim.wo[win].winblend = 0
	            vim.wo[win].winhl = "Normal:NvimTreeNormal,NormalNC:NvimTreeNormal,EndOfBuffer:NvimTreeNormal"

	            return win
	        end

	        local function overlay_render(tree_win, bufnr, topline, lnums, width, textoff)
	            if not (tree_win and vim.api.nvim_win_is_valid(tree_win)) then
	                overlay_close(tree_win)
	                sticky_overlay_state[tree_win] = nil
	                return
	            end
	            if not (bufnr and vim.api.nvim_buf_is_valid(bufnr)) then
	                overlay_close(tree_win)
	                sticky_overlay_state[tree_win] = nil
	                return
	            end
	            if vim.bo[bufnr].filetype ~= "NvimTree" then
	                overlay_close(tree_win)
	                sticky_overlay_state[tree_win] = nil
	                return
	            end

	            local state = get_overlay_state(tree_win)
	            local cache = nvim_tree_cache[bufnr]
	            if type(cache) ~= "table" then
	                overlay_close(tree_win)
	                return
	            end

	            if type(lnums) ~= "table" or #lnums == 0 then
	                overlay_close(tree_win)
	                return
	            end

	            local height = #lnums
	            width = tonumber(width) or vim.api.nvim_win_get_width(tree_win)
	            textoff = tonumber(textoff) or 0

	            overlay_ensure_win(tree_win, state, width, height)
	            local header_buf = overlay_ensure_buf(state)
	            vim.api.nvim_buf_clear_namespace(header_buf, sticky_overlay_ns, 0, -1)

	            local gutter = (textoff > 0) and string.rep(" ", textoff) or ""
	            local marks = cache.pipe_marks
	            local blue_pipe = "▕"
	            local grey_pipe = "│"

	            local lines = {}
	            local highlights = {}

	            for idx, lnum in ipairs(lnums) do
	                local row = lnum - 1
	                local base = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
	                local first_non_space = base:find("%S")
	                local icon_col = (first_non_space and (first_non_space - 1)) or 0

	                local row_marks = (type(marks) == "table") and marks[row] or nil
	                local prefix_cells = {}
	                for _ = 1, icon_col do
	                    prefix_cells[#prefix_cells + 1] = " "
	                end
	                if type(row_marks) == "table" then
	                    for col, kind in pairs(row_marks) do
	                        if type(col) == "number" and col >= 0 and col < icon_col then
	                            prefix_cells[col + 1] = (kind == "blue") and blue_pipe or grey_pipe
	                        end
	                    end
	                end

	                local icon_charidx = vim.str_utfindex(base, icon_col)
	                local icon = vim.fn.strcharpart(base, icon_charidx, 1)
	                local name = vim.fn.strcharpart(base, icon_charidx + 2)
	                if icon == "" then
	                    icon = blue_pipe
	                end
	                local icon_hl = (icon == "" and "NvimTreeClosedFolderIcon")
	                    or (icon == "" and "NvimTreeOpenedFolderIcon")
	                    or (icon == "" and "NvimTreeFolderArrowClosed")
	                    or (icon == "" and "NvimTreeFolderArrowOpen")
	                    or "NvimTreeFolderIcon"

	                local prefix = table.concat(prefix_cells)
	                lines[#lines + 1] = gutter .. prefix .. icon .. " " .. name

	                local line_idx = idx - 1
	                local col = #gutter
	                for _, cell in ipairs(prefix_cells) do
	                    local bytes = #cell
	                    if cell == blue_pipe then
	                        highlights[#highlights + 1] = { hl = "NvimTreeFolderIcon", line = line_idx, start_col = col, end_col = col + bytes }
	                    elseif cell == grey_pipe then
	                        highlights[#highlights + 1] = { hl = "NvimTreeIndentMarker", line = line_idx, start_col = col, end_col = col + bytes }
	                    end
	                    col = col + bytes
	                end

	                local icon_bytes = #icon
	                highlights[#highlights + 1] = { hl = icon_hl, line = line_idx, start_col = col, end_col = col + icon_bytes }
	                col = col + icon_bytes
	                col = col + 1

	                local name_bytes = #name
	                if name_bytes > 0 then
	                    highlights[#highlights + 1] = { hl = "NvimTreeFolderName", line = line_idx, start_col = col, end_col = col + name_bytes }
	                end
	            end

	            vim.bo[header_buf].modifiable = true
	            vim.api.nvim_buf_set_lines(header_buf, 0, -1, false, lines)
	            vim.bo[header_buf].modifiable = false

	            for _, h in ipairs(highlights) do
	                pcall(vim.api.nvim_buf_add_highlight, header_buf, sticky_overlay_ns, h.hl, h.line, h.start_col, h.end_col)
	            end

	            state.last_key = state.key
	            state.last_topline = topline
	        end

	        local function overlay_schedule(tree_win)
	            local state = sticky_overlay_state[tree_win]
	            if type(state) ~= "table" then
	                return
	            end
	            if state.scheduled then
	                return
	            end
	            state.scheduled = true
	            vim.schedule(function()
	                state.scheduled = false
	                if not (tree_win and vim.api.nvim_win_is_valid(tree_win)) then
	                    sticky_overlay_state[tree_win] = nil
	                    return
	                end
	                overlay_render(tree_win, state.bufnr, state.topline, state.lnums, state.width, state.textoff)
	            end)
	        end

	        local sticky_runtime = {}
	        local sticky_log_path = vim.fn.stdpath("cache") .. "/humoodagen_nvim_tree_sticky.log"

	        local function sticky_log(line)
	            local ok_stat, stat = pcall(vim.loop.fs_stat, sticky_log_path)
	            if ok_stat and stat and stat.size and stat.size > 200000 then
	                pcall(vim.fn.writefile, {}, sticky_log_path)
	            end
	            pcall(vim.fn.writefile, { line }, sticky_log_path, "a")
	        end

	        local function sticky_refresh(tree_win)
	            local ok = pcall(function()
	                if not (tree_win and vim.api.nvim_win_is_valid(tree_win)) then
	                    return
                end

                local bufnr = vim.api.nvim_win_get_buf(tree_win)
                if not (bufnr and vim.api.nvim_buf_is_valid(bufnr)) then
                    return
                end
                if vim.bo[bufnr].filetype ~= "NvimTree" then
                    overlay_close(tree_win)
                    return
                end

                local window_w0 = vim.api.nvim_win_call(tree_win, function()
                    return vim.fn.line("w0")
                end)
	                if type(window_w0) ~= "number" or window_w0 < 1 then
	                    overlay_close(tree_win)
	                    return
	                end

	                -- Compute sticky stack relative to the first *visible* row under the
	                -- overlay. Without this, the sticky headers can appear "late" when
	                -- the overlay is already covering the next lines.
	                local probe = window_w0
	                local lnums, why
	                local lines = 0
	                for _ = 1, 6 do
	                    local new_lnums, new_why = sticky_header_lnums(bufnr, probe)
	                    local new_lines = (type(new_lnums) == "table") and #new_lnums or 0
	                    local new_probe = window_w0 + new_lines
	                    lnums, why, lines = new_lnums, new_why, new_lines
	                    if new_probe == probe then
	                        break
	                    end
	                    probe = new_probe
	                end

	                local key = table.concat({
	                    tostring(bufnr),
	                    tostring(window_w0),
	                    tostring(probe),
	                    (type(lnums) == "table" and table.concat(lnums, ",") or ""),
	                }, ":")

	                local rt = sticky_runtime[tree_win]
	                if type(rt) ~= "table" then
	                    rt = {}
	                    sticky_runtime[tree_win] = rt
	                end

	                if type(lnums) ~= "table" or #lnums == 0 then
	                    overlay_close(tree_win)
	                else
	                    local state = get_overlay_state(tree_win)
	                    state.bufnr = bufnr
	                    state.topline = window_w0
	                    state.lnums = lnums
	                    state.width = vim.api.nvim_win_get_width(tree_win)
	                    local ok_info, info = pcall(vim.fn.getwininfo, tree_win)
	                    state.textoff = (ok_info and type(info) == "table" and type(info[1]) == "table" and type(info[1].textoff) == "number")
	                            and info[1].textoff
	                        or 0
	                    state.key = key

	                    local overlay_ok = state.win and vim.api.nvim_win_is_valid(state.win)
	                    if state.last_key ~= key or not overlay_ok then
	                        overlay_schedule(tree_win)
	                    end
	                end

	                local log_key = table.concat({ tostring(key), tostring(why), tostring(lines) }, "|")
	                if rt.log_key ~= log_key then
	                    rt.log_key = log_key
	                    local overlay_state = sticky_overlay_state[tree_win]
	                    local overlay_win = overlay_state and overlay_state.win or nil
	                    sticky_log(table.concat({
	                        os.date("%H:%M:%S"),
	                        "win=" .. tostring(tree_win),
	                        "buf=" .. tostring(bufnr),
	                        "w0=" .. tostring(window_w0),
	                        "probe=" .. tostring(probe),
	                        "why=" .. tostring(why),
	                        "lines=" .. tostring(lines),
	                        "overlay=" .. tostring(overlay_win and vim.api.nvim_win_is_valid(overlay_win) or false),
	                    }, " "))
	                end
	            end)

            if not ok then
                -- Best effort: avoid sticky artifacts if something goes wrong.
                if tree_win and vim.api.nvim_win_is_valid(tree_win) then
                    overlay_close(tree_win)
                end
            end
        end

        local sticky_group = vim.api.nvim_create_augroup("HumoodagenNvimTreeStickyHeaders", { clear = true })
        vim.api.nvim_create_autocmd({ "WinScrolled", "WinResized", "BufWinEnter" }, {
            group = sticky_group,
            callback = function()
                local win = (vim.v.event and vim.v.event.winid) or vim.api.nvim_get_current_win()
                sticky_refresh(win)
            end,
        })

        -- Fallback: some setups don't reliably fire WinScrolled for the tree (e.g. certain
        -- mouse/scroll mappings). The decoration provider runs on redraw, so it keeps the
        -- sticky header in sync even in those cases.
        vim.api.nvim_set_decoration_provider(sticky_header_ns, {
            on_win = function(_, tree_win, bufnr, topline, botline)
                if vim.bo[bufnr].filetype ~= "NvimTree" then
                    return false
                end
                sticky_refresh(tree_win)
                return false
            end,
        })

        local function apply_open_pipes(bufnr)
            if not (bufnr and vim.api.nvim_buf_is_valid(bufnr)) then
                return
            end
            if vim.bo[bufnr].filetype ~= "NvimTree" then
                return
            end

            vim.api.nvim_buf_clear_namespace(bufnr, open_pipe_ns, 0, -1)

            local ok_core, core = pcall(require, "nvim-tree.core")
            if not ok_core then
                return
            end

            local explorer = core.get_explorer()
            if not explorer or not explorer.opts or not explorer.opts.renderer then
                return
            end

            local indent_width = tonumber(explorer.opts.renderer.indent_width) or 3
            if indent_width < 1 then
                indent_width = 1
            end

            local start_line = core.get_nodes_starting_line()
            if type(start_line) ~= "number" or start_line < 1 then
                return
            end

            local nodes_by_line = explorer:get_nodes_by_line(start_line)
            if type(nodes_by_line) ~= "table" then
                return
            end

            local line_nums = {}
            for lnum, _ in pairs(nodes_by_line) do
                if type(lnum) == "number" then
                    table.insert(line_nums, lnum)
                end
            end
            table.sort(line_nums)

            local line_for_path = {}
            for _, lnum in ipairs(line_nums) do
                local node = nodes_by_line[lnum]
                if type(node) == "table" and type(node.absolute_path) == "string" then
                    line_for_path[node.absolute_path] = lnum
                end
            end

            local cache = nvim_tree_cache[bufnr]
            if type(cache) ~= "table" then
                cache = {}
                nvim_tree_cache[bufnr] = cache
            end
            cache.start_line = start_line
            cache.nodes_by_line = nodes_by_line
            cache.line_for_path = line_for_path
            cache.end_line_by_line = nil
            cache.pipe_marks = nil
            cache.rev = (tonumber(cache.rev) or 0) + 1

            if not enable_open_pipes then
                return
            end

            local open_dirs_by_lnum = {}
            local icon_col_by_lnum = {}
            for _, lnum in ipairs(line_nums) do
                local node = nodes_by_line[lnum]
                open_dirs_by_lnum[lnum] = (type(node) == "table" and node.type == "directory" and node.open == true and type(node.nodes) == "table")

                local row = lnum - 1
                local text = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
                local first_non_space = text:find("%S")
                icon_col_by_lnum[lnum] = (first_non_space and (first_non_space - 1)) or 0
            end

            local end_line_by_line = {}
            do
                local stack = {}
                for idx, lnum in ipairs(line_nums) do
                    local col = icon_col_by_lnum[lnum] or 0
                    while #stack > 0 do
                        local prev_lnum = line_nums[stack[#stack]]
                        local prev_col = icon_col_by_lnum[prev_lnum] or 0
                        if col > prev_col then
                            break
                        end
                        local popped = table.remove(stack)
                        end_line_by_line[line_nums[popped]] = line_nums[idx - 1] or line_nums[popped]
                    end
                    table.insert(stack, idx)
                end

                local last = line_nums[#line_nums]
                for _, idx in ipairs(stack) do
                    end_line_by_line[line_nums[idx]] = last
                end
            end

			            local marks = {}
			            for i, lnum in ipairs(line_nums) do
			                if open_dirs_by_lnum[lnum] then
			                    local icon_col = icon_col_by_lnum[lnum] or 0
			                    local end_lnum = end_line_by_line[lnum] or lnum
			                    local j = i + 1
			                    while j <= #line_nums and line_nums[j] <= end_lnum do
			                        local row = line_nums[j] - 1
			                        marks[row] = marks[row] or {}
			                        -- VS Code-style: only grey indent guides (no blue folder
			                        -- "open subtree" line). Draw the guide under the folder
			                        -- chevron column (not under the first letter of the name).
			                        marks[row][icon_col] = "grey"
			                        j = j + 1
			                    end
			                end
			            end

			            local blue_pipe = "▕"
			            local grey_pipe = "│"

			            for row, cols in pairs(marks) do
			                local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
			                for col, kind in pairs(cols) do
			                    local byte = line:sub(col + 1, col + 1)
			                    -- Only draw over indentation whitespace; never overwrite
			                    -- icons/labels (keeps folder icons stable).
			                    if byte == " " or byte == "\t" then
			                        local pipe = (kind == "blue") and blue_pipe or grey_pipe
			                        local hl = (kind == "blue") and "NvimTreeFolderIcon" or "NvimTreeIndentMarker"
			                        pcall(vim.api.nvim_buf_set_extmark, bufnr, open_pipe_ns, row, col, {
			                            virt_text = { { pipe, hl } },
			                            virt_text_pos = "overlay",
			                            hl_mode = "combine",
			                            priority = 200,
			                        })
			                    end
			                end
			            end

            cache.end_line_by_line = end_line_by_line
            cache.pipe_marks = marks
        end

	        events.subscribe(events.Event.TreeRendered, function(payload)
	            local bufnr = payload and payload.bufnr or nil
	            vim.schedule(function()
	                apply_open_pipes(bufnr)
	                if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
	                    local wins = vim.fn.win_findbuf(bufnr)
	                    if type(wins) == "table" then
	                        for _, win in ipairs(wins) do
	                            sticky_refresh(win)
	                        end
	                    end
	                end
	            end)
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
            local view = require("nvim-tree.view")
            local tree_win = view.get_winnr()
            if not (tree_win and vim.api.nvim_win_is_valid(tree_win)) then
                return
            end

            for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
                if win ~= tree_win and is_main_edit_win(win) then
                    return
                end
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
	
			        -- Open nvim-tree on startup when launching with no args.
			        local function open_nvim_tree(data)
			            local no_args = data.file == ""
		
		            if not no_args then
		                return false
		            end
		
		            perf_mark("nvim-tree:open:start", data.file)
		
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
		            if fast_start and main_win then
		                pcall(vim.api.nvim_win_call, main_win, open_tree_stable)
		            else
		                require("nvim-tree.api").tree.open({ focus = false })
		            end

		            pcall(ensure_main_edit_win)

		            local focus_win = find_main_win()
		            if focus_win and vim.api.nvim_win_is_valid(focus_win) then
		                vim.api.nvim_set_current_win(focus_win)
		            elseif origin_win and vim.api.nvim_win_is_valid(origin_win) then
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

                -- Don't auto-open nvim-tree on startup; netrw handles the startup explorer.
                vim.g.humoodagen_startup_tree_opened = true

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

                    -- When Neovim starts with a directory arg, nvim-tree can
                    -- hijack it before UIEnter and replace the argv entry with
                    -- "NvimTree_1". In that case `open_nvim_tree()` won't run,
                    -- but we still want a main edit window to the right.
                    if not opened then
                        local ok_view, view = pcall(require, "nvim-tree.view")
                        if ok_view and view.is_visible() then
                            pcall(ensure_main_edit_win)
                            for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
                                if is_main_edit_win(win) then
                                    vim.api.nvim_set_current_win(win)
                                    break
                                end
                            end
                        end
                    end
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
