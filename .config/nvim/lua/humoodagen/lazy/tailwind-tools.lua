return {
  "luckasRanarison/tailwind-tools.nvim",
  name = "tailwind-tools",
  build = ":UpdateRemotePlugins",
  ft = { "html", "css", "scss", "sass", "javascript", "javascriptreact", "typescript", "typescriptreact", "svelte", "vue", "astro", "php", "blade", "heex", "templ" },
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "nvim-telescope/telescope.nvim", -- optional
    "neovim/nvim-lspconfig", -- optional
  },
  opts = {
    server = {
      -- Neovim 0.11 uses `vim.lsp.config()`. The plugin's built-in override
      -- still calls legacy `lspconfig.tailwindcss.setup(...)`, so keep LSP
      -- setup in our main LSP config and disable the plugin override.
      override = false,
    },
  }
}
