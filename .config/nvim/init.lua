local uv = vim.uv or vim.loop
vim.g.humoodagen_start_hrtime = uv.hrtime()

if vim.env.HUMOODAGEN_PERF == "1" then
  require("humoodagen.perf").enable()
end

vim.g.deprecation_warnings = false
vim.g.lspconfig_suppress_deprecation = true
vim.o.number = true

-- Silence specific lspconfig deprecation warning flash
local notify = vim.notify
vim.notify = function(msg, ...)
    if type(msg) == "string" and msg:find("lspconfig.*deprecated") then
        return
    end
    notify(msg, ...)
end

pcall(function()
  vim.loader.enable()
end)

require("humoodagen")
