local M = {}

local function mkdirp(path)
    if path == "" then
        return
    end
    vim.fn.mkdir(path, "p")
end

local function create_path(input)
    if input == nil then
        return
    end

    input = vim.fn.trim(input)
    if input == "" then
        return
    end

    local is_dir = input:sub(-1) == "/"
    local full_path = vim.fn.fnamemodify(input, ":p")

    if is_dir then
        mkdirp(full_path)
        vim.notify("Created directory: " .. full_path, vim.log.levels.INFO)
        return
    end

    mkdirp(vim.fn.fnamemodify(full_path, ":h"))

    if vim.fn.filereadable(full_path) == 0 then
        local ok, err = pcall(vim.fn.writefile, {}, full_path, "b")
        if not ok then
            vim.notify("Failed to create file: " .. tostring(err), vim.log.levels.ERROR)
            return
        end
    end

    vim.cmd.edit(full_path)
end

vim.api.nvim_create_user_command("New", function(opts)
    create_path(opts.args)
end, { nargs = 1, complete = "file" })

M.create_path = create_path

local function termcodes(str)
    return vim.api.nvim_replace_termcodes(str, true, false, true)
end

local function is_known_command(cmd)
    if cmd == nil or cmd == "" then
        return false
    end
    if vim.fn.exists(":" .. cmd) == 2 then
        return true
    end
    local no_bang = cmd:gsub("!+$", "")
    if no_bang ~= cmd and vim.fn.exists(":" .. no_bang) == 2 then
        return true
    end
    return false
end

local function should_create_from_cmdline(cmdline)
    if cmdline == nil then
        return false
    end
    local cmd = vim.fn.trim(cmdline)
    if cmd == "" then
        return false
    end
    if cmd:find("%s") then
        return false
    end

    local first = cmd:sub(1, 1)
    if first == "!" or first == "%" or first == "@" or first == "#" then
        return false
    end
    if cmd:match("^%d") then
        return false
    end

    local leading = cmd:match("^[%a]+")
    if leading and is_known_command(leading) then
        return false
    end
    if is_known_command(cmd) then
        return false
    end

    return true
end

local function cmdline_new_or_execute()
    if vim.fn.getcmdtype() ~= ":" then
        return termcodes("<CR>")
    end

    local cmd = vim.fn.getcmdline()
    if should_create_from_cmdline(cmd) then
        return termcodes("<C-U>:New " .. cmd .. "<CR>")
    end

    return termcodes("<CR>")
end

vim.keymap.set("c", "<CR>", cmdline_new_or_execute, { expr = true })

return M
