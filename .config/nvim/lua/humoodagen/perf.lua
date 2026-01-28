local M = {}

local uv = vim.uv or vim.loop

local function trace_ui_enabled()
    return vim.env.HUMOODAGEN_PERF_UI == "1"
end

local function log_path()
    return vim.fn.stdpath("state") .. "/humoodagen-perf.log"
end

local function epoch_ns()
    local sec, usec = uv.gettimeofday()
    return (sec * 1e9) + (usec * 1e3)
end

local function launch_ts_ns_raw()
    local raw = vim.env.HUMOODAGEN_LAUNCH_TS_NS
    if type(raw) ~= "string" or raw == "" then
        return nil
    end
    return raw
end

local function launch_ts_ns()
    local raw = launch_ts_ns_raw()
    if not raw then
        return nil
    end
    local n = tonumber(raw)
    if type(n) ~= "number" or n <= 0 then
        return nil
    end
    return n
end

local function ms_since_launch()
    local ts = launch_ts_ns()
    if not ts then
        return nil
    end
    return (epoch_ns() - ts) / 1e6
end

local function start_ns()
    local t = vim.g.humoodagen_start_hrtime
    if type(t) == "number" and t > 0 then
        return t
    end
    t = uv.hrtime()
    vim.g.humoodagen_start_hrtime = t
    return t
end

local function ms_since_start()
    return (uv.hrtime() - start_ns()) / 1e6
end

local function write(line)
    pcall(vim.fn.writefile, { line }, log_path(), "a")
end

local function lazy_profile_path()
    return vim.fn.stdpath("state") .. "/humoodagen-lazy-profile.json"
end

local function now()
    return os.date("%Y-%m-%d %H:%M:%S")
end

local function should_dump_lazy_profile()
    if not M.enabled() then
        return false
    end
    if vim.env.HUMOODAGEN_GHOSTTY ~= "1" then
        return false
    end
    if vim.env.HUMOODAGEN_FAST_START ~= "1" then
        return false
    end
    if vim.fn.argc() ~= 0 then
        return false
    end
    if vim.env.HUMOODAGEN_PERF_DUMP_LAZY == "0" then
        return false
    end
    return true
end

local function dump_lazy_profile(source)
    if not should_dump_lazy_profile() then
        return
    end

    local ok_util, util = pcall(require, "lazy.core.util")
    if not ok_util or type(util) ~= "table" then
        return
    end

    local ok_stats, stats_mod = pcall(require, "lazy.stats")
    local stats = ok_stats and stats_mod and stats_mod.stats and stats_mod.stats() or nil

    local function normalize_data(data)
        if type(data) == "string" then
            return { source = data }
        end
        if type(data) ~= "table" then
            return { value = tostring(data) }
        end
        local out = {}
        for k, v in pairs(data) do
            if type(k) == "string" then
                out[k] = v
            end
        end
        return out
    end

    local function convert(entry)
        if type(entry) ~= "table" then
            return { data = { value = tostring(entry) }, time = 0, children = {} }
        end
        local node = {
            data = normalize_data(entry.data),
            time = entry.time or 0,
            children = {},
        }
        for _, child in ipairs(entry) do
            node.children[#node.children + 1] = convert(child)
        end
        return node
    end

    local root = util._profiles and util._profiles[1] or nil
    if type(root) ~= "table" then
        return
    end

    local out = {
        generated_at = now(),
        source = tostring(source or ""),
        argv = vim.v.argv,
        env = {
            HUMOODAGEN_GHOSTTY = vim.env.HUMOODAGEN_GHOSTTY,
            HUMOODAGEN_FAST_START = vim.env.HUMOODAGEN_FAST_START,
            HUMOODAGEN_TMUX_IMPL = vim.env.HUMOODAGEN_TMUX_IMPL,
        },
        lazy_stats = stats,
        profile = {
            name = root.name,
            children = {},
        },
    }
    for _, child in ipairs(root) do
        out.profile.children[#out.profile.children + 1] = convert(child)
    end

    pcall(vim.fn.writefile, { vim.json.encode(out) }, lazy_profile_path(), "b")
end

local function layout_leaf(win)
    if not (win and vim.api.nvim_win_is_valid(win)) then
        return "leaf(?)"
    end

    local ok_buf, buf = pcall(vim.api.nvim_win_get_buf, win)
    if not ok_buf then
        return "leaf(" .. tostring(win) .. ":?)"
    end

    local ok_ft, ft = pcall(function()
        return vim.bo[buf].filetype
    end)
    if not ok_ft then
        ft = ""
    end
    if ft == "" then
        ft = "?"
    end

    local ok_w, w = pcall(vim.api.nvim_win_get_width, win)
    local ok_h, h = pcall(vim.api.nvim_win_get_height, win)
    if not ok_w then
        w = 0
    end
    if not ok_h then
        h = 0
    end

    return string.format("leaf(%s:%s:%sx%s)", tostring(win), tostring(ft), tostring(w), tostring(h))
end

local function layout_to_string(node)
    if type(node) ~= "table" then
        return tostring(node)
    end

    local kind = node[1]
    if kind == "leaf" then
        return layout_leaf(node[2])
    end

    local children = node[2]
    local parts = {}
    if type(children) == "table" then
        for _, child in ipairs(children) do
            parts[#parts + 1] = layout_to_string(child)
        end
    end
    return tostring(kind) .. "(" .. table.concat(parts, ",") .. ")"
end

local function mark_layout(label)
    if not (M.enabled() and trace_ui_enabled()) then
        return
    end

    local ok, layout = pcall(vim.fn.winlayout)
    if not ok then
        return
    end

    local s = layout_to_string(layout)
    if vim.g.humoodagen_perf_layout_last == s then
        return
    end
    vim.g.humoodagen_perf_layout_last = s
    M.mark("layout " .. tostring(label), s)
end

function M.enabled()
    return vim.g.humoodagen_perf_enabled == true
end

function M.mark(label, extra)
    if not M.enabled() then
        return
    end
    local line = string.format("%9.2fms | %s", ms_since_start(), tostring(label))
    local launch_ms = ms_since_launch()
    if type(launch_ms) == "number" then
        line = line .. string.format(" | launch=%9.2fms", launch_ms)
    end
    if extra ~= nil then
        line = line .. " | " .. tostring(extra)
    end
    write(line)
end

function M.clear()
    pcall(vim.fn.writefile, {}, log_path(), "b")
end

function M.open()
    vim.cmd("tabnew " .. vim.fn.fnameescape(log_path()))
end

local function set_once(key)
    local seen = vim.g.humoodagen_perf_seen
    if type(seen) ~= "table" then
        seen = {}
        vim.g.humoodagen_perf_seen = seen
    end
    if seen[key] then
        return false
    end
    seen[key] = true
    return true
end

local function mark_once(key, label, extra)
    if not M.enabled() then
        return
    end
    if not set_once(key) then
        return
    end
    M.mark(label, extra)
end

function M.enable()
    if M.enabled() then
        return
    end
    vim.g.humoodagen_perf_enabled = true
    vim.g.humoodagen_perf_seen = {}

        write(
            string.format(
	            "=== %s pid=%s nvim=%s launch_ts_ns=%s ===",
	            now(),
	            tostring(uv.os_getpid()),
	            vim.version().major .. "." .. vim.version().minor .. "." .. vim.version().patch,
	            tostring(launch_ts_ns_raw())
	        )
	    )
    M.mark("perf enabled", "argv=" .. table.concat(vim.v.argv or {}, " "))

    local group = vim.api.nvim_create_augroup("HumoodagenPerf", { clear = true })

    vim.api.nvim_create_autocmd("UIEnter", {
        group = group,
        callback = function()
            mark_once("UIEnter", "UIEnter")
            mark_layout("UIEnter")
            vim.schedule(function()
                mark_once("UIEnter:schedule", "UIEnter:schedule")
                mark_layout("UIEnter:schedule")
            end)
        end,
    })

    vim.api.nvim_create_autocmd("VimEnter", {
        group = group,
        callback = function()
            mark_once("VimEnter", "VimEnter", "argc=" .. tostring(vim.fn.argc()))
            mark_layout("VimEnter")
            vim.schedule(function()
                mark_once("VimEnter:schedule", "VimEnter:schedule")
                mark_layout("VimEnter:schedule")
            end)
        end,
    })

    vim.api.nvim_create_autocmd("TermOpen", {
        group = group,
        callback = function(ev)
            local buf = ev and ev.buf or 0
            local ft = buf ~= 0 and vim.bo[buf].filetype or ""
            mark_once("TermOpen", "TermOpen", "ft=" .. tostring(ft))
            mark_layout("TermOpen")
        end,
    })

    if trace_ui_enabled() then
        vim.g.humoodagen_perf_layout_last = nil

        vim.api.nvim_create_autocmd({ "WinEnter", "WinClosed", "WinResized", "BufWinEnter", "VimResized", "ColorScheme" }, {
            group = group,
            callback = function(ev)
                local evname = ev and ev.event or "?"
                mark_layout(evname)
            end,
        })
    end

    vim.api.nvim_create_autocmd("User", {
        group = group,
        pattern = "VeryLazy",
        callback = function()
            mark_once("User:VeryLazy", "User VeryLazy")
            mark_layout("User:VeryLazy")
        end,
    })

    vim.api.nvim_create_autocmd("User", {
        group = group,
        pattern = "LazyDone",
        callback = function()
            mark_once("User:LazyDone", "User LazyDone")
            mark_layout("User:LazyDone")
            vim.schedule(function()
                dump_lazy_profile("LazyDone")
            end)
        end,
    })

    local ns = vim.api.nvim_create_namespace("HumoodagenPerfOnKey")
    vim.on_key(function(key)
        if not M.enabled() then
            return
        end
        mark_once("first_key", "first key", vim.fn.keytrans(key))
        vim.on_key(nil, ns)
    end, ns)

    vim.api.nvim_create_user_command("HumoodagenPerfOpen", function()
        M.open()
    end, {})

    vim.api.nvim_create_user_command("HumoodagenPerfClear", function()
        M.clear()
        M.mark("cleared")
    end, {})

    vim.api.nvim_create_user_command("HumoodagenPerfMark", function(opts)
        M.mark(opts.args)
    end, { nargs = 1 })
end

return M
