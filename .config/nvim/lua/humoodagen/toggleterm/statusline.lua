local M = {}

local function set_toggleterm_status_hl()
  vim.api.nvim_set_hl(0, "HumoodagenToggletermTabActive", { fg = "#ffffff", bg = "#005eff", bold = true })
  vim.api.nvim_set_hl(0, "HumoodagenToggletermTabInactive", { fg = "#000000", bg = "#d6d6d6", bold = true })
end

function M.fix_toggleterm_inactive_statusline(state, buf)
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    return
  end
  if vim.bo[buf].filetype ~= "toggleterm" then
    return
  end

  local num = vim.b[buf].toggle_number
  if not num then
    return
  end

  vim.api.nvim_set_hl(0, ("ToggleTerm%sStatusLineNC"):format(num), { bg = "NONE" })
end

local function fix_all_toggleterm_inactive_statuslines(state)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == "toggleterm" then
      M.fix_toggleterm_inactive_statusline(state, buf)
    end
  end
end

function M.is_toggleterm_buf(_state, buf)
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    return false
  end
  if vim.bo[buf].filetype == "toggleterm" then
    return true
  end
  if vim.bo[buf].buftype == "terminal" and vim.b[buf].toggle_number ~= nil then
    return true
  end
  return false
end

local function any_toggleterm_window(state)
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
      local buf = vim.api.nvim_win_get_buf(win)
      if state.is_toggleterm_buf(buf) then
        return true
      end
    end
  end
  return false
end

local function ensure_toggleterm_statuslines(state)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) then
      local buf = vim.api.nvim_win_get_buf(win)
      if state.is_toggleterm_buf(buf) then
        vim.wo[win].statusline = "%!v:lua.HumoodagenToggletermStatusline()"
        vim.wo[win].winbar = ""
      elseif vim.bo[buf].buftype == "" and vim.bo[buf].filetype ~= "NvimTree" then
        vim.wo[win].statusline = "%!v:lua.HumoodagenPaneBorderStatusline()"
      end
    end
  end
end

function M.update_laststatus(state)
  if vim.g.humoodagen_profile ~= "ide_like_exp" then
    vim.o.laststatus = state.base_laststatus
    vim.go.statusline = state.base_statusline

    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_is_valid(win) then
        local local_statusline = vim.wo[win].statusline
        if local_statusline == "%!v:lua.HumoodagenToggletermStatusline()" or local_statusline == "%!v:lua.HumoodagenPaneBorderStatusline()" then
          vim.wo[win].statusline = ""
        end
      end
    end
    return
  end

  if any_toggleterm_window(state) then
    vim.g.humoodagen_seen_toggleterm_window = true
    vim.o.laststatus = 2
    vim.go.statusline = " "
    ensure_toggleterm_statuslines(state)
  else
    vim.o.laststatus = state.base_laststatus
    vim.go.statusline = state.base_statusline

    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_is_valid(win) then
        local local_statusline = vim.wo[win].statusline
        if local_statusline == "%!v:lua.HumoodagenToggletermStatusline()" or local_statusline == "%!v:lua.HumoodagenPaneBorderStatusline()" then
          vim.wo[win].statusline = ""
        end
      end
    end
  end
end

local function parse_winhighlight(value)
  local map = {}
  if type(value) ~= "string" or value == "" then
    return map
  end
  for entry in value:gmatch("[^,]+") do
    local from, to = entry:match("^([^:]+):(.+)$")
    if from and to then
      map[from] = to
    end
  end
  return map
end

local function build_winhighlight(map)
  local parts = {}
  for from, to in pairs(map) do
    table.insert(parts, from .. ":" .. to)
  end
  table.sort(parts)
  return table.concat(parts, ",")
end

local function normalize_toggleterm_winhighlight(value)
  local map = parse_winhighlight(value)
  local normal = map.Normal or "Normal"
  map.NormalNC = normal
  map.TermNormal = normal
  map.TermNormalNC = normal
  map.CursorLine = "Normal"
  map.CursorLineNr = "LineNr"
  map.StatusLine = "Normal"
  map.StatusLineNC = "Normal"
  return build_winhighlight(map)
end

function M.sync_toggleterm_inactive_highlight(state)
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    if state.is_toggleterm_buf(buf) then
      vim.wo[win].cursorline = false
      local current_wh = vim.wo[win].winhighlight or ""
      local normalized = normalize_toggleterm_winhighlight(current_wh)
      if normalized ~= current_wh then
        vim.wo[win].winhighlight = normalized
      end
    end
  end
end

function M.setup(state, termset)
  state.is_toggleterm_buf = function(buf)
    return M.is_toggleterm_buf(state, buf)
  end
  state.update_laststatus = function()
    M.update_laststatus(state)
  end
  state.sync_toggleterm_inactive_highlight = function()
    M.sync_toggleterm_inactive_highlight(state)
  end
  state.fix_toggleterm_inactive_statusline = function(buf)
    M.fix_toggleterm_inactive_statusline(state, buf)
  end

  set_toggleterm_status_hl()
  fix_all_toggleterm_inactive_statuslines(state)
  vim.api.nvim_create_autocmd("ColorScheme", {
    callback = function()
      set_toggleterm_status_hl()
      fix_all_toggleterm_inactive_statuslines(state)
    end,
  })

  _G.HumoodagenPaneBorderStatusline = function()
    local win = vim.g.statusline_winid
    if not (win and win ~= 0 and vim.api.nvim_win_is_valid(win)) then
      return ""
    end

    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].buftype ~= "" then
      return ""
    end

    local ft = vim.bo[buf].filetype
    if ft == "toggleterm" or ft == "NvimTree" then
      return ""
    end

    local width = vim.api.nvim_win_get_width(win)
    if width < 1 then
      return ""
    end

    if state.border_cache[width] == nil then
      state.border_cache[width] = "%#WinSeparator#" .. string.rep(state.border_char, width) .. "%#Normal#"
    end

    return state.border_cache[width]
  end

  _G.HumoodagenToggletermStatusline = function()
    local term = termset.term_for_win(state, vim.g.statusline_winid)
    if not term or not term.direction then
      return ""
    end

    termset.attach_tab_lifecycle(state, term)
    local set = termset.ensure_term_set(state, term.direction)

    local current = nil
    for idx, t in ipairs(set.terms) do
      if t == term or (t.id and term.id and t.id == term.id) then
        current = idx
        break
      end
    end
    if not current then
      table.insert(set.terms, term)
      current = #set.terms
    end

    set.current = current
    local total = #set.terms
    if total == 0 then
      return ""
    end

    local inactive_hl = "%#HumoodagenToggletermTabInactive#"
    local active_hl = "%#HumoodagenToggletermTabActive#"

    local parts = { inactive_hl }
    for i = 1, total do
      if i == current then
        table.insert(parts, active_hl)
        table.insert(parts, tostring(i))
        table.insert(parts, inactive_hl)
      else
        table.insert(parts, tostring(i))
      end

      if i < total then
        table.insert(parts, "|")
      end
    end

    table.insert(parts, "%#Normal#")
    return table.concat(parts)
  end
end

return M
