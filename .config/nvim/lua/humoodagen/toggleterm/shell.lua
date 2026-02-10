local M = {}

local function first_token(cmd)
  if type(cmd) ~= "string" then
    return nil
  end
  cmd = vim.trim(cmd)
  if cmd == "" then
    return nil
  end

  local quoted = cmd:match('^"([^"]+)"') or cmd:match("^'([^']+)'")
  if quoted and quoted ~= "" then
    return quoted
  end

  return cmd:match("^(%S+)")
end

local function is_executable(cmd)
  local exe = first_token(cmd)
  if not exe or exe == "" then
    return false
  end
  return vim.fn.executable(exe) == 1
end

local function cmd_kind(cmd)
  local exe = first_token(cmd)
  if not exe or exe == "" then
    return nil
  end
  local base = vim.fn.fnamemodify(exe, ":t")
  if base == "nu" or base == "nu.exe" then
    return "nu"
  end
  if base == "zsh" then
    return "zsh"
  end
  return base
end

function M.resolve()
  local override = vim.env.HUMOODAGEN_TOGGLETERM_SHELL
  if type(override) ~= "string" or override == "" then
    override = vim.g.humoodagen_toggleterm_shell
  end

  if type(override) == "string" and override ~= "" and is_executable(override) then
    return override
  end

  if vim.fn.executable("nu") == 1 then
    return "nu"
  end

  return vim.o.shell
end

function M.resolve_interactive()
  local cmd = M.resolve()
  if cmd_kind(cmd) == "zsh" and not cmd:match("%s%-i(%s|$)") then
    return cmd .. " -i"
  end
  return cmd
end

function M.kind(cmd)
  return cmd_kind(cmd)
end

return M

