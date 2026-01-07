if not vim.g.neovide then
    return
end

-- Make Neovide feel "instant" (no cursor/trail animation).
vim.g.neovide_cursor_animation_length = 0
vim.g.neovide_cursor_short_animation_length = 0
-- `trail_size` < 1 can add visible lag; 1 makes the cursor jump immediately.
vim.g.neovide_cursor_trail_size = 1.0
vim.g.neovide_cursor_animate_in_insert_mode = false
vim.g.neovide_cursor_animate_command_line = false
vim.g.neovide_cursor_vfx_mode = ""

-- Neovide can appear to "lag" on certain UI updates when it idles. Force it to
-- render continuously so cursor/mode visuals update immediately.
vim.g.neovide_no_idle = true

-- When launching Neovide from Spotlight/Finder with no file args, default to
-- `~/repos` so the file tree opens there.
if vim.fn.argc() == 0 then
    local repos = vim.fn.expand("~/repos")
    if vim.fn.isdirectory(repos) == 1 then
        pcall(vim.cmd, "cd " .. vim.fn.fnameescape(repos))
    end
end
