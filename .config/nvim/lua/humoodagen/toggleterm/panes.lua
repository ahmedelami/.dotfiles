local M = {}

local function perf_mark(label, extra)
  if vim.env.HUMOODAGEN_PERF ~= "1" then
    return
  end
  local ok, perf = pcall(require, "humoodagen.perf")
  if ok then
    perf.mark(label, extra)
  end
end

local function focus_main_insert_if_needed(origin_win, origin_mode)
  if not (origin_win and vim.api.nvim_win_is_valid(origin_win)) then
    return
  end
  if origin_mode:sub(1, 1) ~= "i" then
    return
  end
  local buf = vim.api.nvim_win_get_buf(origin_win)
  if vim.bo[buf].buftype ~= "" then
    return
  end
  local ft = vim.bo[buf].filetype
  if ft == "NvimTree" or ft == "toggleterm" then
    return
  end
  vim.cmd("startinsert")
end

function M.setup(state, mode, termset)
  local ui = state.ui
  local term_module = state.term_module
  local debug = state.debug
  local term_sets = state.term_sets

  local function with_directional_open_windows(direction, fn)
    local original = ui.find_open_windows
    ui.find_open_windows = function(comparator)
      local has_open, windows = original(comparator)
      if not has_open then
        return false, windows
      end
      local filtered = {}
      for _, win in ipairs(windows) do
        local term = term_module.get(win.term_id, true)
        if term and term.direction == direction then
          table.insert(filtered, win)
        end
      end
      return #filtered > 0, filtered
    end

    local ok, err = pcall(fn)
    ui.find_open_windows = original
    if not ok then
      error(err)
    end
  end

  local function is_main_win(win)
    if not win or not vim.api.nvim_win_is_valid(win) then
      return false
    end
    local buf = vim.api.nvim_win_get_buf(win)
    local bt = vim.bo[buf].buftype
    local ft = vim.bo[buf].filetype
    if bt == "terminal" or ft == "toggleterm" or ft == "NvimTree" then
      return false
    end
    local cfg = vim.api.nvim_win_get_config(win)
    if cfg.relative ~= "" then
      return false
    end
    return true
  end

  local nav_group = vim.api.nvim_create_augroup("ToggleTermNav", { clear = true })
  vim.api.nvim_create_autocmd({ "WinEnter", "BufEnter" }, {
    group = nav_group,
    callback = function()
      local win = vim.api.nvim_get_current_win()
      if is_main_win(win) then
        state.last_main_win = win
      end
      state.sync_toggleterm_inactive_highlight()
      vim.schedule(state.update_laststatus)
    end,
  })

  vim.api.nvim_create_autocmd("ModeChanged", {
    group = nav_group,
    callback = function()
      state.sync_toggleterm_inactive_highlight()
    end,
  })

  vim.api.nvim_create_autocmd("TermOpen", {
    group = nav_group,
    callback = function(ev)
      local buf = ev.buf
      if not state.is_toggleterm_buf(buf) then
        return
      end

      mode.enable_term_cwd_sync(state, buf)

      state.sync_toggleterm_inactive_highlight()
      vim.schedule(state.update_laststatus)
    end,
  })

  vim.api.nvim_create_autocmd({ "WinEnter", "BufEnter" }, {
    group = nav_group,
    callback = function()
      local buf = vim.api.nvim_get_current_buf()
      if not state.is_toggleterm_buf(buf) then
        return
      end

      mode.enable_term_cwd_sync(state, buf)
      termset.sync_current_term_from_buf(state)
      vim.opt_local.statusline = "%!v:lua.HumoodagenToggletermStatusline()"
      vim.opt_local.winbar = ""
      vim.wo.cursorline = false
      state.fix_toggleterm_inactive_statusline(buf)
      local stored = vim.b[buf].humoodagen_term_mode
      if type(stored) ~= "string" or stored == "" then
        vim.b[buf].humoodagen_term_mode = "t"
      end

      local term = termset.current_toggleterm(state)
      mode.restore_term_mode(state, term)
      vim.schedule(state.sync_toggleterm_inactive_highlight)

      local desired = vim.b[buf].humoodagen_term_mode
      if type(desired) == "string" and desired:sub(1, 1) == "t" then
        mode.ensure_job_mode(state, buf)
      end

      if type(desired) == "string" and desired:sub(1, 1) == "n" then
        local cursor = vim.b[buf].humoodagen_term_nt_cursor
        if type(cursor) == "table" and #cursor == 2 then
          local win = vim.api.nvim_get_current_win()
          local function restore_cursor(tag)
            if not vim.api.nvim_win_is_valid(win) then
              return
            end
            if vim.api.nvim_get_current_win() ~= win then
              return
            end
            if vim.api.nvim_get_current_buf() ~= buf then
              return
            end
            if vim.bo[buf].filetype ~= "toggleterm" then
              return
            end
            if vim.api.nvim_get_mode().mode:sub(1, 1) ~= "n" then
              return
            end

            local line_count = vim.api.nvim_buf_line_count(buf)
            local row = math.min(math.max(1, cursor[1]), line_count)
            local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, true)[1] or ""
            local max_col = #line > 0 and (#line - 1) or 0
            local col = math.min(math.max(0, cursor[2]), max_col)
            debug.log(string.format("term_nt_cursor restore(%s) row=%d col=%d", tag, row, col))
            pcall(vim.api.nvim_win_set_cursor, win, { row, col })
          end

          vim.schedule(function()
            restore_cursor("schedule")
          end)
          vim.defer_fn(function()
            restore_cursor("defer10")
          end, 10)
          vim.defer_fn(function()
            restore_cursor("defer50")
          end, 50)
        end
      end
    end,
  })

  vim.api.nvim_create_autocmd("WinLeave", {
    group = nav_group,
    callback = function()
      local buf = vim.api.nvim_get_current_buf()
      if vim.bo[buf].filetype == "toggleterm" then
        vim.wo.cursorline = false
        local mode_now = vim.api.nvim_get_mode().mode
        if mode_now:sub(1, 1) == "n" then
          local ok, cursor = pcall(vim.api.nvim_win_get_cursor, 0)
          if ok and type(cursor) == "table" and #cursor == 2 then
            vim.b[buf].humoodagen_term_nt_cursor = cursor
            debug.log(string.format("term_nt_cursor save row=%d col=%d", cursor[1], cursor[2]))
          end
        end
      end
    end,
  })

  local function find_main_win()
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if is_main_win(win) then
        return win
      end
    end
    return nil
  end

  local function find_tree_win()
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.bo[buf].filetype == "NvimTree" then
        return win
      end
    end
    return nil
  end

  local function ensure_main_win()
    local existing = find_main_win()
    if existing and vim.api.nvim_win_is_valid(existing) then
      state.last_main_win = existing
      return existing
    end

    local wins = vim.api.nvim_tabpage_list_wins(0)
    if #wins == 0 then
      return nil
    end

    local anchor = find_tree_win() or wins[1]
    if anchor and vim.api.nvim_win_is_valid(anchor) then
      vim.api.nvim_set_current_win(anchor)
    end

    vim.cmd("vsplit")
    vim.cmd("enew")
    local new_win = vim.api.nvim_get_current_win()
    state.last_main_win = new_win
    return new_win
  end

  local function safe_close_term(term)
    if not term or not term.is_open or not term:is_open() then
      return
    end

    local origin_tab = vim.api.nvim_get_current_tabpage()
    local origin_win = vim.api.nvim_get_current_win()
    ui.set_origin_window()

    local win = term.window
    if win and vim.api.nvim_win_is_valid(win) then
      local tab = vim.api.nvim_win_get_tabpage(win)
      local wins = vim.api.nvim_tabpage_list_wins(tab)
      if #wins <= 1 then
        vim.api.nvim_set_current_tabpage(tab)
        vim.api.nvim_set_current_win(win)
        vim.cmd("vsplit")
        vim.cmd("enew")
        state.last_main_win = vim.api.nvim_get_current_win()
        vim.api.nvim_set_current_tabpage(origin_tab)
        if origin_win and vim.api.nvim_win_is_valid(origin_win) then
          vim.api.nvim_set_current_win(origin_win)
        end
      end
    end

    pcall(function()
      term:close()
    end)
  end

	  local function open_horizontal_in_main(term)
	    local size = ui._resolve_size(ui.get_size(nil, term.direction), term)
	    local target_win = find_main_win()
	    if not (target_win and vim.api.nvim_win_is_valid(target_win)) then
	      target_win = ensure_main_win()
	    end
	    if target_win and vim.api.nvim_win_is_valid(target_win) then
	      vim.api.nvim_set_current_win(target_win)
	    end
	
	    ui.set_origin_window()
	    if type(size) == "number" and size > 0 then
	      vim.cmd("rightbelow " .. tostring(size) .. "split")
	    else
	      vim.cmd("rightbelow split")
	    end

	    local win = vim.api.nvim_get_current_win()
	    if type(size) == "number" and size > 0 then
	      local ok_h, h = pcall(vim.api.nvim_win_get_height, win)
	      if ok_h and h ~= size then
	        ui.resize_split(term, size)
	      end
	    end
	    local valid_buf = term.bufnr and vim.api.nvim_buf_is_valid(term.bufnr)
	    local bufnr = valid_buf and term.bufnr or ui.create_buf()
	    vim.api.nvim_win_set_buf(win, bufnr)
	    term.window, term.bufnr = win, bufnr
	    term:__set_options()

    if not valid_buf then
      perf_mark("toggleterm:term:spawn:begin", "id=" .. tostring(term.id))
      term:spawn()
      perf_mark("toggleterm:term:spawn:done", "id=" .. tostring(term.id))
    else
      ui.switch_buf(bufnr)
    end

    ui.hl_term(term)
    vim.schedule(state.sync_toggleterm_inactive_highlight)
	    if term.on_open then
	      term:on_open()
	    end
	  end

	  local function open_horizontal_in_win(term, win)
	    local size = ui._resolve_size(ui.get_size(nil, term.direction), term)
	    if not (win and vim.api.nvim_win_is_valid(win)) then
	      open_horizontal_in_main(term)
	      return
	    end

	    vim.api.nvim_set_current_win(win)
	    if type(size) == "number" and size > 0 then
	      local ok_h, h = pcall(vim.api.nvim_win_get_height, win)
	      if ok_h and h ~= size then
	        ui.resize_split(term, size)
	      end
	    end

	    local valid_buf = term.bufnr and vim.api.nvim_buf_is_valid(term.bufnr)
	    local bufnr = valid_buf and term.bufnr or ui.create_buf()
	    vim.api.nvim_win_set_buf(win, bufnr)
	    term.window, term.bufnr = win, bufnr
	    term:__set_options()

	    if not valid_buf then
	      perf_mark("toggleterm:term:spawn:begin", "id=" .. tostring(term.id))
	      term:spawn()
	      perf_mark("toggleterm:term:spawn:done", "id=" .. tostring(term.id))
	    else
	      ui.switch_buf(bufnr)
	    end

	    ui.hl_term(term)
	    vim.schedule(state.sync_toggleterm_inactive_highlight)
	    if term.on_open then
	      term:on_open()
	    end
	  end

  local function toggle_bottom_terminal(term)
    if term:is_open() then
      safe_close_term(term)
      return
    end

    local set = term_sets[term.direction]
    if set then
      for _, other in pairs(set.terms) do
        if other ~= term and other:is_open() then
          safe_close_term(other)
        end
      end
    end

    open_horizontal_in_main(term)
  end

  local function toggle_terminal(term, opts)
    local current_mode = vim.api.nvim_get_mode().mode
    local mode_prefix = current_mode:sub(1, 1)
    if mode_prefix == "c" then
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-c>", true, false, true), "n", false)
    end

    local should_open = not term:is_open()

    vim.schedule(function()
      if opts and opts.prefer_main then
        local target = state.last_main_win
        if not (target and vim.api.nvim_win_is_valid(target) and is_main_win(target)) then
          target = find_main_win()
        end
        if not (target and vim.api.nvim_win_is_valid(target)) then
          target = ensure_main_win()
        end
        if target and vim.api.nvim_win_is_valid(target) then
          vim.api.nvim_set_current_win(target)
        end
      end

      local direction = term.direction
      if should_open then
        local set = term_sets[direction]
        if set then
          for _, other in pairs(set.terms) do
            if other ~= term and other:is_open() then
              safe_close_term(other)
            end
          end
        end
      end

      if direction then
        with_directional_open_windows(direction, function()
          term:toggle()
        end)
      else
        term:toggle()
      end
    end)
  end

	  local function run_in_normal(fn, opts)
	    local current_mode = vim.api.nvim_get_mode().mode
	    local mode_prefix = current_mode:sub(1, 1)
	    local was_term_job = mode_prefix == "t"
	    if mode_prefix == "t" then
      local buf = vim.api.nvim_get_current_buf()
      if vim.bo[buf].filetype == "toggleterm" then
        vim.b[buf].humoodagen_term_mode = "t"
        mode.cancel_pending_term_exit(state, buf)
      end
    elseif mode_prefix == "c" then
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-c>", true, false, true), "n", false)
    end
	
	    local function run()
	      local ok, err = pcall(fn)
	      if was_term_job then
	        local buf = vim.api.nvim_get_current_buf()
	        if vim.bo[buf].filetype == "toggleterm" then
	          vim.cmd("startinsert")
	        end
	      end
	      if not ok then
	        error(err)
	      end
	    end
	
	    if opts and opts.immediate then
	      run()
	    else
	      vim.schedule(run)
	    end
	  end

  local function focus_main_win()
    local target = state.last_main_win
    if target and vim.api.nvim_win_is_valid(target) and is_main_win(target) then
      vim.api.nvim_set_current_win(target)
      return true
    end

    target = find_main_win()
    if target and vim.api.nvim_win_is_valid(target) then
      vim.api.nvim_set_current_win(target)
      return true
    end

    target = ensure_main_win()
    if target and vim.api.nvim_win_is_valid(target) then
      vim.api.nvim_set_current_win(target)
      return true
    end

    return false
  end

  local function focus_term_window(term)
    if term.window and vim.api.nvim_win_is_valid(term.window) then
      vim.api.nvim_set_current_win(term.window)
      mode.restore_term_mode(state, term)
      return true
    end

    if term.bufnr and vim.api.nvim_buf_is_valid(term.bufnr) then
      for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_get_buf(win) == term.bufnr then
          vim.api.nvim_set_current_win(win)
          mode.restore_term_mode(state, term)
          return true
        end
      end
    end

    return false
  end

  local function open_or_focus_term(term)
    if focus_term_window(term) then
      vim.cmd("redrawstatus")
      return
    end

    local set = term_sets[term.direction]
    if set then
      for _, other in pairs(set.terms) do
        if other ~= term and other:is_open() then
          safe_close_term(other)
        end
      end
    end

    if term.direction == "horizontal" then
      open_horizontal_in_main(term)
    elseif term.direction == "vertical" then
      focus_main_win()
      with_directional_open_windows("vertical", function()
        term:open()
      end)
    else
      term:open()
    end

    vim.schedule(state.sync_toggleterm_inactive_highlight)
    mode.restore_term_mode(state, term)
    vim.cmd("redrawstatus")
  end

  state.open_or_focus_term = open_or_focus_term

  local function open_or_focus_bottom()
    run_in_normal(function()
      open_or_focus_term(termset.current_term(state, "horizontal"))
    end)
  end

  local function open_or_focus_right()
    run_in_normal(function()
      open_or_focus_term(termset.current_term(state, "vertical"))
    end)
  end

  local switch_bottom_workspace

  local function new_term_tab(direction)
    run_in_normal(function()
      local resolved_direction = direction
      if type(resolved_direction) ~= "string" or resolved_direction == "" then
        local term = termset.current_toggleterm(state)
        resolved_direction = term and term.direction or "horizontal"
      end

      if resolved_direction == "horizontal" and type(switch_bottom_workspace) == "function" then
        local set = term_sets.horizontal
        local prev = set and set.current or 1

        local new_term = termset.new_term_tab_for_direction(state, resolved_direction)
        local new_index = (set and set.current) or (prev + 1)

        if set then
          set.current = prev
        end

        switch_bottom_workspace(new_index, { focus = "term", update_terminal = true, reset_main = true })
        open_or_focus_term(new_term)

        local buf = new_term.bufnr
        if buf and vim.api.nvim_buf_is_valid(buf) then
          vim.b[buf].humoodagen_term_mode = "t"
          mode.cancel_pending_term_exit(state, buf)
          mode.ensure_job_mode(state, buf)
        end

        vim.cmd("redrawstatus")
        return
      end

      local new_term = termset.new_term_tab_for_direction(state, resolved_direction)
      open_or_focus_term(new_term)

      local buf = new_term.bufnr
      if buf and vim.api.nvim_buf_is_valid(buf) then
        vim.b[buf].humoodagen_term_mode = "t"
        mode.cancel_pending_term_exit(state, buf)
        mode.ensure_job_mode(state, buf)
      end

      vim.cmd("redrawstatus")
    end)
  end

  local function switch_term_tab(index)
    run_in_normal(function()
      local term = termset.current_toggleterm(state)
      if not term or not term.direction then
        return
      end
      if term.direction == "horizontal" and type(switch_bottom_workspace) == "function" then
        switch_bottom_workspace(index, { focus = "term", update_terminal = true })
        vim.cmd("redrawstatus")
        return
      end
      local target = termset.term_tab_at(state, term.direction, index)
      if not target then
        return
      end
      open_or_focus_term(target)
      vim.cmd("redrawstatus")
    end)
  end

  local main_only_state = nil

  local function any_term_open(direction)
    local set = term_sets[direction]
    if not set then
      return false
    end
    for _, t in ipairs(set.terms) do
      if t and t:is_open() then
        return true
      end
    end
    return false
  end

  local function close_terms(direction)
    local set = term_sets[direction]
    if not set then
      return
    end
    for _, t in ipairs(set.terms) do
      if t and t:is_open() then
        safe_close_term(t)
      end
    end
  end

  local function toggle_main_only()
    run_in_normal(function()
      focus_main_win()
      local ok_tree, tree = pcall(require, "nvim-tree.api")
      local tree_visible = ok_tree and tree.tree.is_visible() or false
      local bottom_open = any_term_open("horizontal")
      local right_open = any_term_open("vertical")

      if not main_only_state then
        main_only_state = {
          tree = tree_visible,
          bottom = bottom_open,
          right = right_open,
        }

        if ok_tree and tree_visible then
          tree.tree.close()
        end
        close_terms("horizontal")
        close_terms("vertical")
        focus_main_win()
        vim.cmd("redrawstatus")
        return
      end

      local prev = main_only_state
      main_only_state = nil

      if ok_tree and prev.tree then
        tree.tree.open({ focus = false })
      end
      if prev.bottom then
        toggle_bottom_terminal(termset.current_term(state, "horizontal"))
      end
      if prev.right then
        toggle_terminal(termset.current_term(state, "vertical"), { prefer_main = true })
      end

      focus_main_win()
      vim.cmd("redrawstatus")
    end)
  end

  local function is_valid_workspace_buf(buf)
    if not (buf and vim.api.nvim_buf_is_valid(buf)) then
      return false
    end
    if vim.bo[buf].buftype ~= "" then
      return false
    end
    local ft = vim.bo[buf].filetype
    return ft ~= "NvimTree" and ft ~= "toggleterm"
  end

  local function bottom_workspace_table()
    if type(state.bottom_workspace_main_buf) ~= "table" then
      state.bottom_workspace_main_buf = {}
    end
    return state.bottom_workspace_main_buf
  end

  local function bottom_workspace_view_table()
    if type(state.bottom_workspace_view) ~= "table" then
      state.bottom_workspace_view = {}
    end
    return state.bottom_workspace_view
  end

  local function get_main_win()
    if state.last_main_win and vim.api.nvim_win_is_valid(state.last_main_win) and is_main_win(state.last_main_win) then
      return state.last_main_win
    end
    local win = find_main_win()
    if win and vim.api.nvim_win_is_valid(win) then
      state.last_main_win = win
      return win
    end
    return nil
  end

  local function capture_main_for_workspace(index)
    local win = get_main_win()
    if not win then
      return
    end
    local buf = vim.api.nvim_win_get_buf(win)
    if not is_valid_workspace_buf(buf) then
      return
    end
    bottom_workspace_table()[index] = buf

    local ok, view = pcall(vim.api.nvim_win_call, win, function()
      return vim.fn.winsaveview()
    end)
    if ok and type(view) == "table" then
      bottom_workspace_view_table()[index] = view
    end
  end

  local function ensure_main_for_workspace(index)
    local t = bottom_workspace_table()
    local buf = t[index]
    if is_valid_workspace_buf(buf) then
      return buf
    end

    local win = ensure_main_win()
    if not (win and vim.api.nvim_win_is_valid(win)) then
      return nil
    end

    bottom_workspace_view_table()[index] = nil

    vim.api.nvim_win_call(win, function()
      vim.cmd("enew")
    end)

    buf = vim.api.nvim_win_get_buf(win)
    if is_valid_workspace_buf(buf) then
      t[index] = buf
      return buf
    end
    return nil
  end

  local function restore_view_for_workspace(index, win)
    if not (win and vim.api.nvim_win_is_valid(win)) then
      return
    end

    local view = bottom_workspace_view_table()[index]
    if type(view) ~= "table" then
      return
    end

    pcall(vim.api.nvim_win_call, win, function()
      pcall(vim.fn.winrestview, view)
    end)
  end

  local function ensure_bottom_term_tab(index)
    local set = termset.ensure_first_term(state, "horizontal")
    while #set.terms < index do
      termset.new_term_tab_for_direction(state, "horizontal")
    end
    set.current = index
    return set.terms[index]
  end

  local function cd_if_changed(dir)
    if type(dir) ~= "string" or dir == "" then
      return
    end
    if vim.fn.isdirectory(dir) == 0 then
      return
    end
    if vim.loop.cwd() == dir then
      return
    end
    vim.cmd("cd " .. vim.fn.fnameescape(dir))
  end

  local function workspace_dir_from_term(term)
    if not (term and term.bufnr and vim.api.nvim_buf_is_valid(term.bufnr)) then
      return nil
    end
    if not vim.b[term.bufnr].humoodagen_term_cwd_sync then
      return nil
    end
    local dir = vim.b[term.bufnr].humoodagen_osc7_dir
    if type(dir) ~= "string" or dir == "" then
      return nil
    end
    if vim.fn.isdirectory(dir) == 0 then
      return nil
    end
    return dir
  end

  local function workspace_dir_from_buf(buf)
    if not (buf and vim.api.nvim_buf_is_valid(buf)) then
      return nil
    end
    local name = vim.api.nvim_buf_get_name(buf)
    if name == "" then
      return nil
    end
    local dir = vim.fn.fnamemodify(name, ":h")
    if type(dir) ~= "string" or dir == "" then
      return nil
    end
    if vim.fn.isdirectory(dir) == 0 then
      return nil
    end
    return dir
  end

  local function sync_tree_to_buf(buf)
    if not (buf and vim.api.nvim_buf_is_valid(buf)) then
      return
    end
    local ok, api = pcall(require, "nvim-tree.api")
    if not ok then
      return
    end
    if not api.tree.is_visible() then
      return
    end
    pcall(api.tree.find_file, { buf = buf, open = false, focus = false })
  end

  switch_bottom_workspace = function(index, opts)
    opts = opts or {}
    if type(index) ~= "number" or index < 1 then
      return
    end

    local prev = term_sets.horizontal and term_sets.horizontal.current or 1
    capture_main_for_workspace(prev)
    if opts.reset_main then
      bottom_workspace_table()[index] = nil
      bottom_workspace_view_table()[index] = nil
    end

    local origin_mode = vim.api.nvim_get_mode().mode
    local term = ensure_bottom_term_tab(index)

    local main_win = ensure_main_win()
    local main_buf = ensure_main_for_workspace(index)
    if main_win and vim.api.nvim_win_is_valid(main_win) and main_buf then
      vim.api.nvim_win_set_buf(main_win, main_buf)
      state.last_main_win = main_win
      restore_view_for_workspace(index, main_win)
    end

    local desired_dir = workspace_dir_from_term(term) or workspace_dir_from_buf(main_buf)
    cd_if_changed(desired_dir)
    sync_tree_to_buf(main_buf)

    local update_terminal = opts.update_terminal
    if update_terminal == nil then
      update_terminal = any_term_open("horizontal")
    end
    if opts.focus == "term" then
      update_terminal = true
    end

    if update_terminal and term then
      open_or_focus_term(term)
    end

    if opts.focus ~= "term" and main_win and vim.api.nvim_win_is_valid(main_win) then
      vim.api.nvim_set_current_win(main_win)
      local first = type(origin_mode) == "string" and origin_mode:sub(1, 1) or ""
      if first == "i" then
        vim.cmd("startinsert")
      elseif first == "n" then
        vim.cmd("stopinsert")
      end
    end
  end

  local function workspace_action(index)
    return function()
      run_in_normal(function()
        switch_bottom_workspace(index, { focus = "main" })
        vim.cmd("redrawstatus")
      end)
    end
  end

  _G.HumoodagenPanes = {
    jump_bottom = open_or_focus_bottom,
    jump_right = open_or_focus_right,
    jump_main = function()
      run_in_normal(function()
        focus_main_win()
        local buf = vim.api.nvim_get_current_buf()
        if vim.bo[buf].buftype ~= "" then
          return
        end
        if vim.api.nvim_buf_get_name(buf) ~= "" then
          return
        end
        if vim.bo[buf].modified then
          return
        end
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        for _, line in ipairs(lines) do
          if line ~= "" then
            return
          end
        end
        vim.cmd("startinsert")
      end)
    end,
    workspace_1 = workspace_action(1),
    workspace_2 = workspace_action(2),
    workspace_3 = workspace_action(3),
    workspace_4 = workspace_action(4),
    workspace_5 = workspace_action(5),
    workspace_6 = workspace_action(6),
    workspace_7 = workspace_action(7),
    workspace_8 = workspace_action(8),
    workspace_9 = workspace_action(9),
    new_term_tab = function()
      new_term_tab()
    end,
    toggle_bottom = function()
      run_in_normal(function()
        local origin_win = vim.api.nvim_get_current_win()

        local term = termset.current_term(state, "horizontal")
        if term:is_open() then
          safe_close_term(term)
          if origin_win and vim.api.nvim_win_is_valid(origin_win) and origin_win ~= term.window then
            vim.api.nvim_set_current_win(origin_win)
          else
            focus_main_win()
          end
          vim.cmd("redrawstatus")
          return
        end

        open_or_focus_term(term)
        if term.bufnr and vim.api.nvim_buf_is_valid(term.bufnr) then
          vim.b[term.bufnr].humoodagen_term_mode = "t"
          mode.cancel_pending_term_exit(state, term.bufnr)
          mode.ensure_job_mode(state, term.bufnr)
        else
          vim.cmd("startinsert")
        end
        vim.cmd("redrawstatus")
      end)
    end,
    toggle_right = function()
      local origin_win = vim.api.nvim_get_current_win()
      local origin_mode = vim.api.nvim_get_mode().mode

      local term = termset.current_term(state, "vertical")
      if term:is_open() then
        local closing_current = term.window and origin_win and term.window == origin_win
        safe_close_term(term)
        if closing_current then
          focus_main_win()
        end
        vim.cmd("redrawstatus")
        return
      end

      local set = term_sets[term.direction]
      if set then
        for _, other in ipairs(set.terms) do
          if other ~= term and other:is_open() then
            safe_close_term(other)
          end
        end
      end

      focus_main_win()
      with_directional_open_windows("vertical", function()
        term:open()
      end)

      if origin_win and vim.api.nvim_win_is_valid(origin_win) then
        vim.api.nvim_set_current_win(origin_win)
        focus_main_insert_if_needed(origin_win, origin_mode)
      else
        focus_main_win()
      end

      vim.cmd("redrawstatus")
    end,
    toggle_float = function()
      run_in_normal(function()
        local term = termset.ensure_float_term(state)
        toggle_terminal(term, { prefer_main = true })
      end)
    end,
    toggle_main_only = toggle_main_only,
  }

	  local startup_group = vim.api.nvim_create_augroup("HumoodagenToggletermStartup", { clear = true })
	  local function open_startup_terminals()
	    if #vim.api.nvim_list_uis() == 0 then
	      return
    end
    if vim.g.humoodagen_startup_terminals_opened then
      return
    end
	    vim.g.humoodagen_startup_terminals_opened = true
	    perf_mark("toggleterm:startup:scheduled")

	    local stable_layout = vim.env.HUMOODAGEN_FAST_START == "1" and vim.fn.argc() == 0

	    run_in_normal(function()
	      perf_mark("toggleterm:startup:begin")
	      local desired_cwd = vim.loop.cwd()
	      local repos = vim.fn.expand("~/repos")
      if vim.fn.isdirectory(repos) == 1 then
        local real_repos = vim.loop.fs_realpath(repos)
        if real_repos and real_repos == desired_cwd then
          desired_cwd = repos
        end
      end

      local origin_win = vim.api.nvim_get_current_win()
      local origin_mode = vim.api.nvim_get_mode().mode
      local origin_buf = nil
      if origin_win and vim.api.nvim_win_is_valid(origin_win) then
        origin_buf = vim.api.nvim_win_get_buf(origin_win)
      end

      local focus_bottom = vim.fn.argc() == 0
      if not focus_bottom then
        local argv0 = vim.fn.argv(0)
        if type(argv0) == "string" and argv0 ~= "" and vim.fn.isdirectory(argv0) == 1 then
          focus_bottom = true
        end
      end
      if not focus_bottom and origin_buf and vim.bo[origin_buf].filetype == "NvimTree" then
        focus_bottom = true
      end

      local function has_open_direction(direction)
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
          local buf = vim.api.nvim_win_get_buf(win)
          if vim.bo[buf].filetype == "toggleterm" then
            local id = vim.b[buf].toggle_number
            if id then
              local t = term_module.get(id, true)
              if t and t.direction == direction and t:is_open() then
                return true
              end
            end
          end
        end
        return false
      end

      local right = termset.current_term(state, "vertical")
      if right then
        right.dir = desired_cwd
      end

	      local bottom = termset.current_term(state, "horizontal")
	      if bottom then
	        bottom.dir = desired_cwd
	      end

      if bottom and vim.env.HUMOODAGEN_FAST_START == "1" then
        local marked = false
        local prev_on_stdout = bottom.on_stdout
        bottom.on_stdout = function(term, job, data, name)
          if not marked then
            marked = true
            local count = type(data) == "table" and #data or 0
            if vim.env.HUMOODAGEN_PERF == "1" then
              perf_mark("toggleterm:stdout:first", "lines=" .. tostring(count))
            end
            if vim.g.humoodagen_toggleterm_prompt_ready ~= true then
              vim.g.humoodagen_toggleterm_prompt_ready = true
              vim.schedule(function()
                pcall(vim.api.nvim_exec_autocmds, "User", { pattern = "HumoodagenToggletermPromptReady" })
              end)
            end
            term.on_stdout = prev_on_stdout
          end
          if prev_on_stdout then
            pcall(prev_on_stdout, term, job, data, name)
          end
        end
      end

      if bottom and vim.env.HUMOODAGEN_FAST_START == "1" and vim.env.HUMOODAGEN_TOGGLETERM_STARTUP_FAST_SHELL ~= "0" then
        bottom.cmd = "/bin/zsh -i"
        if type(bottom.env) == "table" then
          bottom.env.HUMOODAGEN_TOGGLETERM_FAST_INIT = "1"
          bottom.env.HUMOODAGEN_TOGGLETERM_FAST_SHELL = "1"
          bottom.env.PS1 = "%(?.%F{33}➜%f.%F{196}➜%f) %B%F{magenta}%c%f%b "
          local zdotdir_orig = bottom.env.HUMOODAGEN_ZDOTDIR_ORIG or vim.env.ZDOTDIR or vim.env.HOME or ""
          if zdotdir_orig ~= "" then
            bottom.env.HISTFILE = zdotdir_orig .. "/.zsh_history"
          end
        end
        perf_mark("toggleterm:startup:shell", bottom.cmd)
      end

	      local opened_bottom = false
	      if bottom and focus_bottom and stable_layout and vim.env.HUMOODAGEN_NVIM_STABLE_LAYOUT ~= "0" then
	        local main_win = find_main_win()
	        if not (main_win and vim.api.nvim_win_is_valid(main_win)) then
	          main_win = ensure_main_win()
	        end
	        if main_win and vim.api.nvim_win_is_valid(main_win) then
	          vim.api.nvim_set_current_win(main_win)
	        end

	        local tree_win = vim.g.humoodagen_startup_tree_winid
	        local bottom_win = vim.g.humoodagen_startup_bottom_winid

	        if not (tree_win and vim.api.nvim_win_is_valid(tree_win)) then
	          local width = math.floor(vim.o.columns * 0.15)
	          if width < 10 then
	            width = 10
	          end
	          vim.cmd("topleft " .. tostring(width) .. "vsplit")
	          tree_win = vim.api.nvim_get_current_win()
	          vim.g.humoodagen_startup_tree_winid = tree_win
	        end

	        local existing_tree_buf = nil
	        if tree_win and vim.api.nvim_win_is_valid(tree_win) then
	          existing_tree_buf = vim.api.nvim_win_get_buf(tree_win)
	        end
	        if not (existing_tree_buf and vim.api.nvim_buf_is_valid(existing_tree_buf) and vim.bo[existing_tree_buf].filetype == "NvimTree") then
	          local tree_buf = vim.api.nvim_create_buf(false, true)
	          vim.bo[tree_buf].buftype = "nofile"
	          vim.bo[tree_buf].bufhidden = "wipe"
	          vim.bo[tree_buf].swapfile = false
	          vim.bo[tree_buf].modifiable = false
	          vim.api.nvim_win_set_buf(tree_win, tree_buf)
	          vim.wo[tree_win].number = false
	          vim.wo[tree_win].relativenumber = false
	          vim.wo[tree_win].signcolumn = "no"
	          vim.wo[tree_win].winbar = ""
	        end

	        if not (bottom_win and vim.api.nvim_win_is_valid(bottom_win)) then
	          if main_win and vim.api.nvim_win_is_valid(main_win) then
	            vim.api.nvim_set_current_win(main_win)
	          else
	            vim.cmd("wincmd l")
	          end

	          local size = ui._resolve_size(ui.get_size(nil, bottom.direction), bottom)
	          if type(size) == "number" and size > 0 then
	            vim.cmd("rightbelow " .. tostring(size) .. "split")
	          else
	            vim.cmd("rightbelow split")
	          end
	          bottom_win = vim.api.nvim_get_current_win()
	          vim.g.humoodagen_startup_bottom_winid = bottom_win
	        end

	        perf_mark("toggleterm:startup:open_horizontal_in_win:begin", "id=" .. tostring(bottom.id))
	        open_horizontal_in_win(bottom, bottom_win)
	        perf_mark("toggleterm:startup:open_horizontal_in_win:done", "id=" .. tostring(bottom.id))
	        opened_bottom = true
	      end

	      if bottom then
	        if focus_bottom then
	          if not opened_bottom then
	            open_or_focus_term(bottom)
	          end
	          if bottom.bufnr and vim.api.nvim_buf_is_valid(bottom.bufnr) then
	            vim.b[bottom.bufnr].humoodagen_term_mode = "t"
	            mode.cancel_pending_term_exit(state, bottom.bufnr)
	          end
	          if vim.api.nvim_get_mode().mode:sub(1, 1) ~= "t" then
	            vim.cmd("startinsert")
	          end
	        elseif not has_open_direction("horizontal") and not bottom:is_open() then
	          toggle_bottom_terminal(bottom)
	        end
	      end

        if right and not has_open_direction("vertical") and not right:is_open() then
          open_or_focus_term(right)
          if focus_bottom and bottom then
            open_or_focus_term(bottom)
          end
        end

      if not focus_bottom then
        if origin_win and vim.api.nvim_win_is_valid(origin_win) then
          vim.api.nvim_set_current_win(origin_win)
          focus_main_insert_if_needed(origin_win, origin_mode)
        else
          local tree_win = find_tree_win()
          if tree_win and vim.api.nvim_win_is_valid(tree_win) then
            vim.api.nvim_set_current_win(tree_win)
          else
            focus_main_win()
          end
        end

        local final_mode = vim.api.nvim_get_mode().mode
        local final_prefix = type(final_mode) == "string" and final_mode:sub(1, 1) or ""
        if final_prefix == "t" then
          vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true), "n", false)
        elseif final_prefix == "i" or final_prefix == "R" then
          vim.cmd("stopinsert")
        end
      end

	      vim.cmd("redrawstatus")
	      state.update_laststatus()
	      perf_mark("toggleterm:startup:done")
		      pcall(vim.api.nvim_exec_autocmds, "User", { pattern = "HumoodagenToggletermStartupDone" })
		    end, { immediate = stable_layout and vim.env.HUMOODAGEN_NVIM_STABLE_LAYOUT ~= "0" })
	  end

	  vim.api.nvim_create_autocmd("VimEnter", {
	    group = startup_group,
	    callback = function()
	      if vim.g.humoodagen_profile ~= "ide_like_exp" then
	        return
	      end
	      open_startup_terminals()
	    end,
	  })

  local function set_term_tab_keymaps(buf)
    if vim.b[buf].humoodagen_term_tab_keymaps_set then
      return
    end
    vim.b[buf].humoodagen_term_tab_keymaps_set = true

    local opts = { buffer = buf, silent = true }
    vim.keymap.set("t", "<Esc>", function()
      local has_pending = vim.fn.getchar(1) ~= 0
      if not has_pending and (vim.g.humoodagen_suppress_toggleterm_mode_capture or 0) == 0 then
        if vim.g.neovide then
          mode.schedule_term_mode_nt(state, buf)
        else
          vim.b[buf].humoodagen_term_mode = "nt"
          debug.log("term_mode <- nt source=term_esc buf=" .. tostring(buf))
        end
      end
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true), "n", false)
    end, vim.tbl_extend("force", opts, { desc = "Terminal normal mode (Esc)" }))

    vim.keymap.set("t", "<C-[>", function()
      local has_pending = vim.fn.getchar(1) ~= 0
      if not has_pending and (vim.g.humoodagen_suppress_toggleterm_mode_capture or 0) == 0 then
        if vim.g.neovide then
          mode.schedule_term_mode_nt(state, buf)
        else
          vim.b[buf].humoodagen_term_mode = "nt"
          debug.log("term_mode <- nt source=term_ctrl_[ buf=" .. tostring(buf))
        end
      end
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true), "n", false)
    end, vim.tbl_extend("force", opts, { desc = "Terminal normal mode (Ctrl-[)" }))

    vim.keymap.set("n", "i", function()
      vim.b[buf].humoodagen_term_mode = "t"
      mode.cancel_pending_term_exit(state, buf)
      debug.log("term_mode <- t source=term_i buf=" .. tostring(buf))
      vim.cmd("startinsert")
    end, vim.tbl_extend("force", opts, { desc = "Terminal insert mode (i)" }))

    vim.keymap.set("n", "a", function()
      vim.b[buf].humoodagen_term_mode = "t"
      mode.cancel_pending_term_exit(state, buf)
      debug.log("term_mode <- t source=term_a buf=" .. tostring(buf))
      vim.cmd("startinsert")
    end, vim.tbl_extend("force", opts, { desc = "Terminal insert mode (a)" }))

    vim.keymap.set({ "t", "n" }, "<C-b>t", new_term_tab, vim.tbl_extend("force", opts, { desc = "Toggleterm new tab" }))
    vim.keymap.set(
      { "t", "n" },
      "<D-t>",
      new_term_tab,
      vim.tbl_extend("force", opts, { desc = "Toggleterm new tab (Cmd+T)" })
    )

    for i = 1, 9 do
      vim.keymap.set({ "t", "n" }, "<C-b>" .. i, function()
        switch_term_tab(i)
      end, vim.tbl_extend("force", opts, { desc = "Toggleterm tab " .. i }))
      vim.keymap.set({ "t", "n" }, "<D-" .. i .. ">", function()
        switch_term_tab(i)
      end, vim.tbl_extend("force", opts, { desc = "Toggleterm tab " .. i .. " (Cmd+" .. i .. ")" }))
    end
  end

  vim.api.nvim_create_autocmd("FileType", {
    pattern = "toggleterm",
    callback = function(args)
      vim.opt_local.statusline = "%!v:lua.HumoodagenToggletermStatusline()"
      vim.opt_local.winbar = ""
      set_term_tab_keymaps(args.buf)
    end,
  })

  vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
    callback = function(args)
      local buf = args.buf
      if vim.bo[buf].filetype == "toggleterm" then
        set_term_tab_keymaps(buf)
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "WinClosed", "BufWinEnter", "BufWinLeave", "TabEnter" }, {
    callback = function()
      state.update_laststatus()
    end,
  })
end

return M
