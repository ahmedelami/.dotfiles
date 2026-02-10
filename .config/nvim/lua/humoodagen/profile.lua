local M = {}

local DEFAULT_PROFILE = "normal"

local function trim(s)
    if type(s) ~= "string" then
        return nil
    end
    s = vim.fn.trim(s)
    if s == "" then
        return nil
    end
    return s
end

local function env_profile()
    return trim(vim.env.HUMOODAGEN_NVIM_PROFILE)
end

function M.get()
    local g = trim(vim.g.humoodagen_profile)
    if g then
        return g
    end
    return env_profile() or DEFAULT_PROFILE
end

function M.is(name)
    return M.get() == name
end

function M.set(name)
    vim.g.humoodagen_profile = trim(name) or DEFAULT_PROFILE
end

local function ensure_lazy_plugin(name)
    local ok_lazy, lazy = pcall(require, "lazy")
    if not ok_lazy then
        return
    end
    pcall(lazy.load, { plugins = { name } })
end

local function ensure_nvim_tree_open()
    local ok_api, api = pcall(require, "nvim-tree.api")
    if ok_api then
        api.tree.open({ focus = false })
        return true
    end

    local ok = pcall(vim.cmd, "NvimTreeOpen")
    if not ok then
        return false
    end

    ok_api, api = pcall(require, "nvim-tree.api")
    if ok_api then
        api.tree.open({ focus = false })
    end
    return true
end

local function ensure_panes_actions()
    local actions = _G.HumoodagenPanes
    if actions then
        return actions
    end

    ensure_lazy_plugin("toggleterm.nvim")
    return _G.HumoodagenPanes
end

local function apply_ide_like_layout()
    local origin_mode = vim.api.nvim_get_mode().mode

    ensure_nvim_tree_open()

    local actions = ensure_panes_actions()
    if actions then
        pcall(actions.jump_right)
        pcall(actions.jump_bottom)
    end

    require("humoodagen.window").focus_main()

    local first = type(origin_mode) == "string" and origin_mode:sub(1, 1) or ""
    if first == "i" then
        pcall(vim.cmd, "startinsert")
    elseif first == "n" then
        pcall(vim.cmd, "stopinsert")
    end
end

function M.setup()
    if vim.g.humoodagen_profile == nil then
        vim.g.humoodagen_profile = env_profile() or DEFAULT_PROFILE
    end

    vim.api.nvim_create_user_command("HumoodagenProfile", function(opts)
        if opts.args == "" then
            vim.notify("humoodagen_profile=" .. M.get())
            return
        end
        M.set(opts.args)
        vim.notify("humoodagen_profile=" .. M.get())
    end, { nargs = "?" })

    vim.api.nvim_create_user_command("HumoodagenIdeLikeExp", function()
        M.set("ide_like_exp")
        apply_ide_like_layout()
        vim.notify("humoodagen_profile=ide_like_exp")
    end, {})

    vim.api.nvim_create_user_command("HumoodagenNormalExp", function()
        M.set(DEFAULT_PROFILE)
        vim.notify("humoodagen_profile=" .. DEFAULT_PROFILE)
    end, {})
end

return M
