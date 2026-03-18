return {
    {
        "lukas-reineke/indent-blankline.nvim",
        main = "ibl",
        event = { "BufReadPost", "BufNewFile" },
        config = function()
            local vscode_theme = require("humoodagen.vscode_theme")
            local hooks = require("ibl.hooks")

            local function apply_indent_highlights()
                local theme = vscode_theme.current()
                local colors = type(theme) == "table" and theme.colors or {}

                local indent_fg = colors["editorIndentGuide.background1"] or "#D3D3D3"
                local scope_fg = colors["editorIndentGuide.activeBackground1"] or "#939393"

                vim.api.nvim_set_hl(0, "IblIndent", { fg = indent_fg, nocombine = true })
                vim.api.nvim_set_hl(0, "IblWhitespace", { fg = indent_fg, nocombine = true })
                vim.api.nvim_set_hl(0, "IblScope", { fg = scope_fg, nocombine = true })
            end

            hooks.register(hooks.type.HIGHLIGHT_SETUP, apply_indent_highlights)
            apply_indent_highlights()

            require("ibl").setup({
                indent = {
                    char = "│",
                    tab_char = "│",
                    highlight = "IblIndent",
                },
                whitespace = {
                    highlight = "IblWhitespace",
                    remove_blankline_trail = false,
                },
                scope = {
                    enabled = true,
                    show_start = false,
                    show_end = false,
                    highlight = "IblScope",
                },
                exclude = {
                    filetypes = {
                        "TelescopePrompt",
                        "Trouble",
                        "alpha",
                        "dashboard",
                        "gitcommit",
                        "help",
                        "lazy",
                        "mason",
                        "notify",
                        "NvimTree",
                        "oil",
                        "toggleterm",
                        "trouble",
                    },
                    buftypes = {
                        "nofile",
                        "prompt",
                        "quickfix",
                        "terminal",
                    },
                },
            })
        end,
    },
}
