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

require("humoodagen")