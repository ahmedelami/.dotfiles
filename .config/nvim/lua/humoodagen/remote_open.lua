local M = {}

local function safe_unlink(path)
    if type(path) ~= "string" or path == "" then
        return
    end
    pcall(vim.loop.fs_unlink, path)
end

function M.open_from_file(path)
    local files = {}
    if type(path) == "string" and path ~= "" then
        local ok, lines = pcall(vim.fn.readfile, path)
        if ok and type(lines) == "table" then
            files = lines
        end
    end

    safe_unlink(path)

    require("humoodagen.window").focus_main()

    for _, file in ipairs(files) do
        if type(file) == "string" and file ~= "" then
            vim.cmd("drop " .. vim.fn.fnameescape(file))
        end
    end
end

return M

