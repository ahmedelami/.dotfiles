return {
    "okuuva/auto-save.nvim",
    version = "^1.0.0", -- use the latest major version
    cmd = "ASToggle", -- optional for lazy loading on command
    event = { "InsertLeave", "TextChanged" }, -- load when typing starts
    opts = {
        enabled = true, -- start auto-save when the plugin is loaded
        trigger_events = {
            -- Save immediately when switching buffers or losing focus
            immediate_save = { "BufLeave", "FocusLost" },
            -- Save after a delay when typing stops or you leave insert mode
            defer_save = { "InsertLeave", "TextChanged" },
            -- Cancel the pending save if you start typing again (resets the timer)
            cancel_deferred_save = { "InsertEnter" },
        },
        -- Save 1 second (1000ms) after you stop typing.
        -- 5s is quite long; 1s feels snappy but doesn't spam disk IO.
        debounce_delay = 1000,

        -- Don't save special buffers (like the file tree or terminal)
        condition = function(buf)
            local fn = vim.fn
            local utils = require("auto-save.utils.data")
            if vim.api.nvim_buf_get_name(buf) == "" then
                return false
            end
            if fn.getbufvar(buf, "&modifiable") == 1 and
               utils.not_in(fn.getbufvar(buf, "&filetype"), { "NvimTree", "toggleterm", "TelescopePrompt" }) then
                return true
            end
            return false
        end,
    },
    config = function(_, opts)
        require("auto-save").setup(opts)
    end,
}
