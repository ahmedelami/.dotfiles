return {
    "neovim/nvim-lspconfig",
    dependencies = {
        "stevearc/conform.nvim",
        "williamboman/mason.nvim",
        "williamboman/mason-lspconfig.nvim",
        "hrsh7th/cmp-nvim-lsp",
        "hrsh7th/cmp-buffer",
        "hrsh7th/cmp-path",
        "hrsh7th/cmp-cmdline",
        "hrsh7th/nvim-cmp",
        "L3MON4D3/LuaSnip",
        "saadparwaiz1/cmp_luasnip",
        "j-hui/fidget.nvim",
    },

    config = function()
        require("conform").setup({
            formatters_by_ft = {
            }
        })
        local cmp = require('cmp')
        local cmp_lsp = require("cmp_nvim_lsp")
        local capabilities = vim.tbl_deep_extend(
            "force",
            {},
            vim.lsp.protocol.make_client_capabilities(),
            cmp_lsp.default_capabilities())

        -- -------------------------------------------------------
        -- on_attach: best-practice per-buffer setup for LSP attach
        -- only enable documentHighlight if the server supports it
        -- -------------------------------------------------------
        local function on_attach(client, bufnr)
            -- LSP key mappings (buffer-local)
            local opts = { buffer = bufnr, remap = false }

            -- Go to definition (the classic gd!)
            vim.keymap.set("n", "gd", function() vim.lsp.buf.definition() end, opts)

            -- Go to declaration
            vim.keymap.set("n", "gD", function() vim.lsp.buf.declaration() end, opts)

            -- Show hover information
            vim.keymap.set("n", "K", function() vim.lsp.buf.hover() end, opts)

            -- Go to implementation
            vim.keymap.set("n", "gi", function() vim.lsp.buf.implementation() end, opts)

            -- Show signature help
            vim.keymap.set("n", "<leader>sh", function() vim.lsp.buf.signature_help() end, opts)

            -- Rename symbol
            vim.keymap.set("n", "<leader>rn", function() vim.lsp.buf.rename() end, opts)

            -- Code actions
            vim.keymap.set("n", "<leader>ca", function() vim.lsp.buf.code_action() end, opts)

            -- Find references
            vim.keymap.set("n", "gr", function() vim.lsp.buf.references() end, opts)

            -- Show diagnostics in floating window
            vim.keymap.set("n", "<leader>d", function() vim.diagnostic.open_float() end, opts)

            -- Go to next/previous diagnostic
            vim.keymap.set("n", "[d", function() vim.diagnostic.goto_next() end, opts)
            vim.keymap.set("n", "]d", function() vim.diagnostic.goto_prev() end, opts)

            -- Go to file under cursor (great for import paths!)
            vim.keymap.set("n", "gf", "<cmd>edit <cfile><cr>", opts)

            if client.server_capabilities and client.server_capabilities.documentHighlightProvider then
                local grp = vim.api.nvim_create_augroup('LspDocHighlight_' .. bufnr, { clear = true })
                vim.api.nvim_create_autocmd({'CursorHold','CursorHoldI'}, {
                    group = grp,
                    buffer = bufnr,
                    callback = vim.lsp.buf.document_highlight,
                    desc = 'LSP: document highlight (buffer-local)',
                })
                vim.api.nvim_create_autocmd({'CursorMoved','CursorMovedI','BufLeave'}, {
                    group = grp,
                    buffer = bufnr,
                    callback = vim.lsp.buf.clear_references,
                    desc = 'LSP: clear highlights (buffer-local)',
                })
            end
        end
        -- -------------------------------------------------------

        require("fidget").setup({})
        require("mason").setup()
        require("mason-lspconfig").setup({
            ensure_installed = {
                "lua_ls",
                "rust_analyzer",
                "gopls",
                "ts_ls",
                "pylsp",
                "clangd",
                "html",
                "cssls",         -- added cssls so plain .css files have a server
                "cssmodules_ls",
                "sqls",
                "tailwindcss",
                -- "eslint",
                "jsonls",
                "texlab",
                "ocamllsp",
                "svelte",
            },
            handlers = {
                -- default handler for all servers: apply capabilities + on_attach
                function(server_name)
                    if vim.lsp.config then
                        vim.lsp.config(server_name, {
                            capabilities = capabilities,
                            on_attach = on_attach,
                        })
                    else
                        require("lspconfig")[server_name].setup {
                            capabilities = capabilities,
                            on_attach = on_attach,
                        }
                    end
                end,

                zls = function()
                    -- your zls config
                end,

                ["lua_ls"] = function()
                    -- your lua_ls config
                end,

                ["pylsp"] = function()
                    local lspconfig = require("lspconfig")
                    lspconfig.pylsp.setup({
                        capabilities = capabilities,
                        on_attach = on_attach,
                        settings = {
                            pylsp = {
                                plugins = {
                                    pycodestyle = {
                                        ignore = { "E501", "E302" },
                                        -- maxLineLength = 120,
                                    },
                                },
                            },
                        },
                    })
                end,

                ["html"] = function()
                    require("lspconfig").html.setup({
                        capabilities = capabilities,
                        on_attach = on_attach,
                        settings = {
                            html = {
                                validate = { scripts = true, styles = false },
                            }
                        }
                    })
                end,
            },
        })

        -- Manual config for djlsp since mason-lspconfig doesn't support it.
        if vim.fn.executable("djlsp") == 1 then
            if vim.lsp.config then
                vim.lsp.config("djlsp", {
                    cmd = { "djlsp" },
                    capabilities = capabilities,
                    on_attach = on_attach,
                })
            else
                require("lspconfig").djlsp.setup({
                    cmd = { "djlsp" },
                    capabilities = capabilities,
                    on_attach = on_attach,
                })
            end
        end

        local cmp_select = { behavior = cmp.SelectBehavior.Select }

        cmp.setup({
            snippet = {
                expand = function(args)
                    require('luasnip').lsp_expand(args.body) -- For `luasnip` users.
                end,
            },
            mapping = cmp.mapping.preset.insert({
                ['<C-p>'] = cmp.mapping.select_prev_item(cmp_select),
                ['<C-n>'] = cmp.mapping.select_next_item(cmp_select),
                ['<CR>'] = cmp.mapping.confirm({ select = true }),
                ['<Tab>'] = cmp.mapping(function(fallback)
                    if cmp.visible() then
                        cmp.confirm({ select = true })
                    else
                        fallback()
                    end
                end, { 'i', 's' }),
                ["<C-Space>"] = cmp.mapping.complete(),
            }),
            sources = cmp.config.sources({
                { name = 'nvim_lsp' },
                { name = 'luasnip' }, -- For luasnip users.
            }, {
                { name = 'buffer' },
            })
        })

        vim.diagnostic.config({
            -- update_in_insert = true,
            -- ========================================
            -- true = show diagnostics, false = hide diagnostics
            -- ========================================
            virtual_text = false,  -- Show/hide inline error text
            signs = false,         -- Show/hide error signs in gutter
            underline = false,     -- Show/hide error underlines
            -- ========================================
            -- End diagnostic display settings
            -- ========================================
            float = {
                focusable = false,
                style = "minimal",
                border = "rounded",
                source = "always",
                header = "",
                prefix = "",
            },
        })

        -- ========================================
        -- LSP Document Highlighting (moved to on_attach)
        -- The previous global CursorHold autocmds were removed.
        -- Document highlighting is now set per-buffer in `on_attach`
        -- ========================================
    end
}
