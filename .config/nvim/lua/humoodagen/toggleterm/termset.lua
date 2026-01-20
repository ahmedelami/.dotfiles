local M = {}

function M.ensure_term_set(state, direction)
  local set = state.term_sets[direction]
  if not set then
    set = { terms = {}, current = 1 }
    state.term_sets[direction] = set
  end
  return set
end

function M.remove_term_from_set(state, term)
  if not term or not term.direction then
    return
  end

  local set = state.term_sets[term.direction]
  if not set then
    return
  end

  for idx, t in ipairs(set.terms) do
    if t == term or (t.id and term.id and t.id == term.id) then
      table.remove(set.terms, idx)
      if set.current > idx then
        set.current = set.current - 1
      elseif set.current == idx then
        if #set.terms == 0 then
          set.current = 1
        elseif idx > #set.terms then
          set.current = #set.terms
        else
          set.current = idx
        end
      end
      return
    end
  end
end

function M.attach_tab_lifecycle(state, term)
  if not term or term.__humoodagen_tab_lifecycle then
    return term
  end

  term.__humoodagen_tab_lifecycle = true
  local prev_on_exit = term.on_exit

  term.on_exit = function(t, job, exit_code, name)
    local was_current = t.bufnr and vim.api.nvim_get_current_buf() == t.bufnr
    local direction = t.direction

    if prev_on_exit then
      pcall(prev_on_exit, t, job, exit_code, name)
    end

    vim.schedule(function()
      M.remove_term_from_set(state, t)
      local set = direction and state.term_sets[direction] or nil
      if was_current and set and #set.terms > 0 and type(state.open_or_focus_term) == "function" then
        local next_term = set.terms[set.current] or set.terms[1]
        if next_term then
          state.open_or_focus_term(next_term)
        end
      end
      if type(state.sync_toggleterm_inactive_highlight) == "function" then
        state.sync_toggleterm_inactive_highlight()
      end
      vim.cmd("redrawstatus")
      if type(state.update_laststatus) == "function" then
        state.update_laststatus()
      end
    end)
  end

  return term
end

function M.create_term(state, direction)
  return M.attach_tab_lifecycle(state, state.Terminal:new({ direction = direction, hidden = true }))
end

function M.ensure_float_term(state)
  if state.float_term then
    return state.float_term
  end

  state.float_term = M.attach_tab_lifecycle(
    state,
    state.Terminal:new({
      direction = "float",
      hidden = true,
      float_opts = {
        border = "rounded",
        width = math.floor(vim.o.columns * 0.85),
        height = math.floor(vim.o.lines * 0.75),
        winblend = 0,
      },
      on_open = function(term)
        if term and term.bufnr and vim.api.nvim_buf_is_valid(term.bufnr) then
          vim.b[term.bufnr].humoodagen_term_cwd_sync = true
          local baseline = vim.b[term.bufnr].humoodagen_osc7_dir
          if type(baseline) ~= "string" or baseline == "" then
            baseline = nil
          end
          vim.b[term.bufnr].humoodagen_term_cwd_sync_baseline = baseline
          vim.b[term.bufnr].humoodagen_term_cwd_sync_dirty = false
          if not vim.b[term.bufnr].humoodagen_float_ctrl_c_close then
            vim.b[term.bufnr].humoodagen_float_ctrl_c_close = true
            vim.keymap.set({ "t", "n" }, "<C-c>", function()
              if term and term:is_open() then
                term:close()
              end
            end, { buffer = term.bufnr, silent = true, desc = "Close float terminal (Ctrl-C)" })
          end
        end
      end,
      on_close = function(term)
        if not (term and term.bufnr and vim.api.nvim_buf_is_valid(term.bufnr)) then
          return
        end
        vim.b[term.bufnr].humoodagen_term_cwd_sync = false
        local dirty = vim.b[term.bufnr].humoodagen_term_cwd_sync_dirty
        vim.b[term.bufnr].humoodagen_term_cwd_sync_dirty = false
        vim.b[term.bufnr].humoodagen_term_cwd_sync_baseline = nil
        if not dirty then
          return
        end
        local dir = vim.b[term.bufnr].humoodagen_osc7_dir
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
      end,
    })
  )

  return state.float_term
end

function M.ensure_first_term(state, direction)
  local set = M.ensure_term_set(state, direction)
  if #set.terms == 0 then
    table.insert(set.terms, M.create_term(state, direction))
    set.current = 1
  end
  return set
end

function M.current_term(state, direction)
  local set = M.ensure_first_term(state, direction)
  local index = set.current or 1
  if index < 1 then
    index = 1
  end
  if index > #set.terms then
    index = #set.terms
  end
  set.current = index
  return set.terms[index]
end

function M.new_term_tab_for_direction(state, direction)
  local set = M.ensure_first_term(state, direction)
  local term = M.create_term(state, direction)
  table.insert(set.terms, term)
  set.current = #set.terms
  return term
end

function M.term_tab_at(state, direction, index)
  local set = M.ensure_first_term(state, direction)
  if not index or index < 1 or index > #set.terms then
    return nil
  end
  set.current = index
  return set.terms[index]
end

function M.current_toggleterm(state)
  local buf = vim.api.nvim_get_current_buf()
  if vim.bo[buf].filetype ~= "toggleterm" then
    return nil
  end
  local term_id = vim.b[buf].toggle_number
  if not term_id then
    return nil
  end
  return state.term_module.get(term_id, true)
end

function M.sync_current_term_from_buf(state)
  local term = M.current_toggleterm(state)
  if not term or not term.direction then
    return
  end

  M.attach_tab_lifecycle(state, term)
  local set = M.ensure_term_set(state, term.direction)
  for idx, t in ipairs(set.terms) do
    if t == term or (t.id and term.id and t.id == term.id) then
      set.current = idx
      return
    end
  end

  table.insert(set.terms, term)
  set.current = #set.terms
end

function M.term_for_win(state, winid)
  if not winid or winid == 0 then
    winid = vim.api.nvim_get_current_win()
  end
  if not vim.api.nvim_win_is_valid(winid) then
    return nil
  end
  local buf = vim.api.nvim_win_get_buf(winid)
  if vim.bo[buf].filetype ~= "toggleterm" then
    return nil
  end
  local term_id = vim.b[buf].toggle_number
  if not term_id then
    return nil
  end
  return state.term_module.get(term_id, true)
end

return M
