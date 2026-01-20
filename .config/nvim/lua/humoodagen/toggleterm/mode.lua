local M = {}

function M.enable_term_cwd_sync(state, buf)
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    return
  end

  vim.b[buf].humoodagen_term_cwd_sync = true

  if vim.b[buf].humoodagen_term_cwd_sync_baseline == nil then
    local baseline = vim.b[buf].humoodagen_osc7_dir
    if type(baseline) ~= "string" or baseline == "" then
      baseline = vim.loop.cwd()
    end
    if type(baseline) ~= "string" or baseline == "" then
      baseline = nil
    end
    vim.b[buf].humoodagen_term_cwd_sync_baseline = baseline
  end

  if vim.b[buf].humoodagen_term_cwd_sync_dirty == nil then
    vim.b[buf].humoodagen_term_cwd_sync_dirty = false
  end
end

function M.cancel_pending_term_exit(state, buf)
  if not (buf and state.pending_term_exit[buf]) then
    return
  end
  state.pending_term_exit[buf] = nil
  if vim.api.nvim_buf_is_valid(buf) then
    vim.b[buf].humoodagen_term_exit_pending = nil
  end
  state.debug.log("term_exit_pending canceled buf=" .. tostring(buf))
end

function M.schedule_term_mode_nt(state, buf)
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    return
  end
  M.cancel_pending_term_exit(state, buf)

  local token = tostring(vim.loop.hrtime())
  state.pending_term_exit[buf] = token
  vim.b[buf].humoodagen_term_exit_pending = token
  state.debug.log("term_mode schedule <- nt source=term_exit buf=" .. tostring(buf))

  vim.defer_fn(function()
    if not vim.api.nvim_buf_is_valid(buf) then
      return
    end
    if state.pending_term_exit[buf] ~= token then
      return
    end
    state.pending_term_exit[buf] = nil
    vim.b[buf].humoodagen_term_exit_pending = nil
    vim.b[buf].humoodagen_term_mode = "nt"
    state.debug.log("term_mode <- nt source=term_exit_deferred buf=" .. tostring(buf))
  end, 50)
end

function M.restore_term_mode(state, _term)
  local buf = vim.api.nvim_get_current_buf()
  if vim.bo[buf].filetype ~= "toggleterm" then
    return
  end

  local desired = vim.b[buf].humoodagen_term_mode
  if type(desired) ~= "string" or desired == "" then
    desired = "t"
  end

  local want_job = desired:sub(1, 1) == "t"
  if want_job then
    local win = vim.api.nvim_get_current_win()
    local token = tostring(vim.loop.hrtime())
    local deadline = vim.loop.hrtime() + 500 * 1e6
    vim.b[buf].humoodagen_term_restore_token = token
    vim.b[buf].humoodagen_term_restore_active = true

    local function stop(reason)
      if not vim.api.nvim_buf_is_valid(buf) then
        return
      end
      if vim.b[buf].humoodagen_term_restore_token ~= token then
        return
      end
      vim.b[buf].humoodagen_term_restore_token = nil
      vim.b[buf].humoodagen_term_restore_active = nil
      if reason then
        state.debug.log("term_restore done reason=" .. reason .. " desired=" .. desired)
      end
    end

    local function attempt(tag)
      if not vim.api.nvim_win_is_valid(win) then
        stop("invalid_win")
        return
      end
      if vim.api.nvim_get_current_win() ~= win then
        stop("win_changed")
        return
      end
      if vim.api.nvim_get_current_buf() ~= buf then
        stop("buf_changed")
        return
      end
      if vim.bo[buf].filetype ~= "toggleterm" then
        stop("not_toggleterm")
        return
      end
      if vim.b[buf].humoodagen_term_restore_token ~= token then
        return
      end

      local mode = vim.api.nvim_get_mode().mode
      if mode:sub(1, 1) == "t" then
        stop("already_t")
        return
      end

      local desired_now = vim.b[buf].humoodagen_term_mode
      if type(desired_now) ~= "string" or desired_now == "" then
        desired_now = "t"
      end
      if desired_now:sub(1, 1) ~= "t" then
        stop("desired=" .. desired_now)
        return
      end

      if vim.b[buf].humoodagen_term_exit_pending ~= nil then
        stop("exit_pending")
        return
      end

      if vim.loop.hrtime() > deadline then
        stop("timeout")
        return
      end

      if mode:sub(1, 1) == "n" then
        state.debug.log("term_restore startinsert(" .. tag .. ") desired=" .. desired)
        pcall(vim.cmd, "startinsert")
      end

      vim.defer_fn(function()
        attempt("defer10")
      end, 10)
    end

    vim.schedule(function()
      attempt("schedule")
    end)
    return
  end

  local mode = vim.api.nvim_get_mode().mode
  if mode == "t" then
    state.debug.log("term_restore to_normal desired=" .. desired)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true), "n", false)
  end
end

function M.ensure_job_mode(_state, buf)
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    return
  end

  local function attempt()
    if not vim.api.nvim_buf_is_valid(buf) then
      return
    end
    if vim.api.nvim_get_current_buf() ~= buf then
      return
    end
    if vim.bo[buf].filetype ~= "toggleterm" then
      return
    end
    if vim.api.nvim_get_mode().mode:sub(1, 1) ~= "t" then
      pcall(vim.cmd, "startinsert")
    end
  end

  vim.schedule(attempt)
  vim.defer_fn(attempt, 20)
  vim.defer_fn(attempt, 100)
end

function M.setup(state)
  _G.HumoodagenCancelToggletermPendingExit = function()
    M.cancel_pending_term_exit(state, vim.api.nvim_get_current_buf())
  end
end

return M
