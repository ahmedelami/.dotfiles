local M = {}
local panel_mode_patched = false

local function is_valid_tab(tabpage)
    return type(tabpage) == "number" and vim.api.nvim_tabpage_is_valid(tabpage)
end

local function is_valid_win(win)
    return type(win) == "number" and vim.api.nvim_win_is_valid(win)
end

local function current_diffview()
    local ok, lib = pcall(require, "diffview.lib")
    if not ok or type(lib) ~= "table" then
        return nil, nil
    end

    local view = lib.get_current_view()
    if not view then
        return nil, nil
    end

    return view, vim.api.nvim_get_current_tabpage()
end

local function is_panel_only_tab(tabpage)
    return is_valid_tab(tabpage) and vim.t[tabpage].humoodagen_diffview_panel_only == true
end

local function is_panel_only_view(view)
    return type(view) == "table" and is_panel_only_tab(view.tabpage or vim.api.nvim_get_current_tabpage())
end

local function patch_panel_only_behavior()
    if panel_mode_patched then
        return
    end

    local ok_async, async = pcall(require, "diffview.async")
    local ok_diff_view, diff_view_mod = pcall(require, "diffview.scene.views.diff.diff_view")
    local ok_standard, standard_view_mod = pcall(require, "diffview.scene.views.standard.standard_view")
    if not (ok_async and ok_diff_view and ok_standard) then
        return
    end

    local DiffView = diff_view_mod.DiffView
    local StandardView = standard_view_mod.StandardView
    if type(DiffView) ~= "table" or type(StandardView) ~= "table" then
        return
    end

    local original_ensure_layout = StandardView.ensure_layout
    StandardView.ensure_layout = function(self)
        if is_panel_only_view(self) then
            return
        end

        return original_ensure_layout(self)
    end

    local original_set_file = DiffView.set_file
    DiffView.set_file = async.void(function(self, file, focus, highlight)
        if is_panel_only_view(self) then
            if not file then
                return
            end

            self.panel:set_cur_file(file)
            if highlight or not self.panel:is_focused() then
                self.panel:highlight_file(file)
            end
            self.cur_entry = nil
            return
        end

        return original_set_file(self, file, focus, highlight)
    end)

    local original_next_file = DiffView.next_file
    DiffView.next_file = function(self, highlight)
        if is_panel_only_view(self) then
            if self.files:len() == 0 then
                return nil
            end

            local cur = self.panel:next_file()
            if cur and (highlight or not self.panel:is_focused()) then
                self.panel:highlight_file(cur)
            end
            self.cur_entry = nil
            return cur
        end

        return original_next_file(self, highlight)
    end

    local original_prev_file = DiffView.prev_file
    DiffView.prev_file = function(self, highlight)
        if is_panel_only_view(self) then
            if self.files:len() == 0 then
                return nil
            end

            local cur = self.panel:prev_file()
            if cur and (highlight or not self.panel:is_focused()) then
                self.panel:highlight_file(cur)
            end
            self.cur_entry = nil
            return cur
        end

        return original_prev_file(self, highlight)
    end

    panel_mode_patched = true
end

local function collapse_to_panel(view, diffview_tab)
    patch_panel_only_behavior()

    if not (type(view) == "table" and is_valid_tab(diffview_tab) and view.panel) then
        return false
    end

    vim.t[diffview_tab].humoodagen_diffview_panel_only = true

    local function apply_panel_only()
        if not is_valid_tab(diffview_tab) then
            return
        end

        local current_view, current_tab = current_diffview()
        if current_tab ~= diffview_tab or current_view ~= view then
            return
        end

        pcall(vim.cmd, "DiffviewFocusFiles")

        local files = type(view.panel.ordered_file_list) == "function" and view.panel:ordered_file_list() or nil
        if not view.panel.cur_file and type(files) == "table" and #files > 0 then
            view.panel:set_cur_file(files[1])
        end

        view.cur_entry = nil

        local panel_win = view.panel.winid
        if is_valid_win(panel_win) then
            pcall(vim.api.nvim_set_current_win, panel_win)
            if #vim.api.nvim_tabpage_list_wins(diffview_tab) > 1 then
                pcall(vim.cmd, "silent! only")
            end
        end
    end

    apply_panel_only()
    vim.schedule(apply_panel_only)
    return true
end

local function get_origin_tab(diffview_tab)
    if not is_valid_tab(diffview_tab) then
        return nil
    end

    local origin_tab = vim.t[diffview_tab].humoodagen_diffview_origin_tab
    if is_valid_tab(origin_tab) then
        return origin_tab
    end

    return nil
end

local function get_review_tab(diffview_tab)
    if not is_valid_tab(diffview_tab) then
        return nil
    end

    local review_tab = vim.t[diffview_tab].humoodagen_diffview_review_tab
    if is_valid_tab(review_tab) then
        return review_tab
    end

    return nil
end

local function set_review_tab(diffview_tab, review_tab)
    if not (is_valid_tab(diffview_tab) and is_valid_tab(review_tab)) then
        return
    end

    vim.t[diffview_tab].humoodagen_diffview_review_tab = review_tab
    vim.t[review_tab].humoodagen_diffview_panel_tab = diffview_tab
end

function M.set_origin_for_current_diffview(origin_tab)
    patch_panel_only_behavior()

    local _, diffview_tab = current_diffview()
    if not (is_valid_tab(origin_tab) and is_valid_tab(diffview_tab)) then
        return
    end

    vim.t[diffview_tab].humoodagen_diffview_origin_tab = origin_tab
end

function M.enter_panel_only_for_current_diffview()
    local view, diffview_tab = current_diffview()
    return collapse_to_panel(view, diffview_tab)
end

function M.close_current_diffview_and_return_origin()
    local _, diffview_tab = current_diffview()
    if not is_valid_tab(diffview_tab) then
        return false
    end

    local origin_tab = get_origin_tab(diffview_tab)
    local ok_close = pcall(vim.cmd, "DiffviewClose")
    if not ok_close then
        return false
    end

    if is_valid_tab(origin_tab) then
        pcall(vim.api.nvim_set_current_tabpage, origin_tab)
    end

    return true
end

function M.return_to_panel_from_review()
    local review_tab = vim.api.nvim_get_current_tabpage()
    local diffview_tab = vim.t[review_tab].humoodagen_diffview_panel_tab
    if not is_valid_tab(diffview_tab) then
        return false
    end

    local ok, git_review = pcall(require, "humoodagen.git_review")
    if ok and type(git_review) == "table" then
        pcall(git_review.close, { tabpage = review_tab })
    end

    vim.api.nvim_set_current_tabpage(diffview_tab)
    return M.enter_panel_only_for_current_diffview()
end

function M.open_selected_entry_in_review()
    patch_panel_only_behavior()

    local view, diffview_tab = current_diffview()
    if not (view and is_valid_tab(diffview_tab) and view.panel and view.panel.is_open and view.panel:is_open()) then
        return
    end

    local item = nil
    if type(view.infer_cur_file) == "function" then
        item = view:infer_cur_file(true)
    end
    if not item and type(view.panel.get_item_at_cursor) == "function" then
        item = view.panel:get_item_at_cursor()
    end
    if not item then
        item = view.panel.cur_file
    end
    if not item then
        return
    end

    if type(item.collapsed) == "boolean" then
        view.panel:toggle_item_fold(item)
        return
    end

    view.panel:set_cur_file(item)

    local path = item.absolute_path
    if (type(path) ~= "string" or path == "") and type(item.path) == "string" and item.path ~= "" then
        local root = type(view.adapter) == "table"
            and type(view.adapter.ctx) == "table"
            and type(view.adapter.ctx.toplevel) == "string"
            and view.adapter.ctx.toplevel
            or nil
        if root and root ~= "" then
            path = vim.fs.joinpath(root, item.path)
        else
            path = item.path
        end
    end
    if type(path) ~= "string" or path == "" then
        return
    end

    local review_tab = get_review_tab(diffview_tab)
    local ok_git_review, git_review = pcall(require, "humoodagen.git_review")
    if not ok_git_review or type(git_review) ~= "table" then
        vim.notify("Git review module unavailable.", vim.log.levels.ERROR)
        return
    end

    if is_valid_tab(review_tab) then
        vim.api.nvim_set_current_tabpage(review_tab)
        pcall(git_review.close, { tabpage = review_tab })
    else
        vim.cmd("tabnew")
        review_tab = vim.api.nvim_get_current_tabpage()
        set_review_tab(diffview_tab, review_tab)
    end

    local cur_buf = vim.api.nvim_get_current_buf()
    if vim.bo[cur_buf].modified then
        vim.notify("Save or discard changes before opening another diff review file.", vim.log.levels.WARN)
        return
    end

    vim.cmd("edit " .. vim.fn.fnameescape(path))
    git_review.open({ win = vim.api.nvim_get_current_win() })
end

return M
