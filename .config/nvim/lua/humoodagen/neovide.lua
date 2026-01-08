if not vim.g.neovide then
    return
end

-- Ensure Neovide's grid reaches the window edges (no extra padding).
vim.g.neovide_padding_top = 0
vim.g.neovide_padding_bottom = 0
vim.g.neovide_padding_left = 0
vim.g.neovide_padding_right = 0

-- Cursor animation (smear/trail) to improve tracking.
vim.g.neovide_cursor_animation_length = 0.08
vim.g.neovide_cursor_short_animation_length = 0.04
vim.g.neovide_cursor_trail_size = 0.8
vim.g.neovide_cursor_animate_in_insert_mode = true
-- Cmdline/search cursor animation can look like the cursor "jumps" between panes
-- in split-heavy layouts; keep it instant.
vim.g.neovide_cursor_animate_command_line = false
vim.g.neovide_cursor_vfx_mode = ""

-- Neovide can appear to "lag" on certain UI updates when it idles. Force it to
-- render continuously so cursor/mode visuals update immediately.
vim.g.neovide_no_idle = true

-- Zoom (scale) with Cmd +/- like a normal macOS app. Without explicit mappings,
-- some setups pass through the raw keys ("-" and "=") which then trigger Vim
-- motions/indent instead of resizing the UI.
vim.g.neovide_scale_factor = vim.g.neovide_scale_factor or 1.0

local function neovide_change_scale(delta)
    local current = tonumber(vim.g.neovide_scale_factor) or 1.0
    local next = current + delta
    if next < 0.5 then
        next = 0.5
    elseif next > 2.5 then
        next = 2.5
    end
    vim.g.neovide_scale_factor = next
end

local zoom_modes = { "n", "i", "v", "t", "c" }
vim.keymap.set(zoom_modes, "<D-=>", function()
    neovide_change_scale(0.1)
end, { silent = true, nowait = true, desc = "Neovide zoom in" })
vim.keymap.set(zoom_modes, "<D-+>", function()
    neovide_change_scale(0.1)
end, { silent = true, nowait = true, desc = "Neovide zoom in" })
vim.keymap.set(zoom_modes, "<D-->", function()
    neovide_change_scale(-0.1)
end, { silent = true, nowait = true, desc = "Neovide zoom out" })
vim.keymap.set(zoom_modes, "<D-_>", function()
    neovide_change_scale(-0.1)
end, { silent = true, nowait = true, desc = "Neovide zoom out" })
vim.keymap.set(zoom_modes, "<D-0>", function()
    vim.g.neovide_scale_factor = 1.0
end, { silent = true, nowait = true, desc = "Neovide zoom reset" })

-- When launching Neovide from Spotlight/Finder with no file args, default to
-- `~/repos` so the file tree opens there.
if vim.fn.argc() == 0 then
    local repos = vim.fn.expand("~/repos")
    if vim.fn.isdirectory(repos) == 1 then
        pcall(vim.cmd, "cd " .. vim.fn.fnameescape(repos))
    end
end

-- Make Cmd+V behave like "paste" everywhere (Neovide doesn't always paste into
-- the cmdline/terminal by default).
local function paste_system_clipboard()
    local text = vim.fn.getreg("+")
    if type(text) ~= "string" or text == "" then
        return
    end

    local ok = pcall(vim.api.nvim_paste, text, true, -1)
    if ok then
        return
    end

    local job = vim.b.terminal_job_id
    if type(job) == "number" and job > 0 then
        pcall(vim.api.nvim_chan_send, job, text)
    end
end

local function paste_cmdline_clipboard()
    local text = vim.fn.getreg("+")
    if type(text) ~= "string" or text == "" then
        return
    end

    -- Cmdline must be one line; keep it predictable.
    text = text:gsub("\r\n", "\n"):gsub("\r", "\n"):gsub("\n", " ")
    pcall(vim.api.nvim_paste, text, true, -1)

    -- Noice/neovide can delay cmdline redraw after paste; force a harmless
    -- cmdline update so the pasted text becomes visible immediately.
    vim.schedule(function()
        pcall(
            vim.api.nvim_feedkeys,
            vim.api.nvim_replace_termcodes("<Space><BS>", true, false, true),
            "n",
            false
        )
    end)
end

vim.keymap.set("c", "<D-v>", paste_cmdline_clipboard, { silent = true, desc = "Paste (cmdline)" })
vim.keymap.set("c", "<D-V>", paste_cmdline_clipboard, { silent = true, desc = "Paste (cmdline)" })
vim.keymap.set("c", "<C-v>", paste_cmdline_clipboard, { silent = true, desc = "Paste (cmdline) (Ctrl+V)" })

vim.keymap.set({ "t", "i" }, "<D-v>", paste_system_clipboard, { silent = true, desc = "Paste (system clipboard)" })
vim.keymap.set({ "t", "i" }, "<D-V>", paste_system_clipboard, { silent = true, desc = "Paste (system clipboard)" })
