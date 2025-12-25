local function ColorMyPencils()
  vim.api.nvim_set_hl(0, "Normal", { bg = "none", fg = "#1f2328" })
  vim.api.nvim_set_hl(0, "NormalFloat", { bg = "#e8e8e8", fg = "#1f2328" })
  vim.api.nvim_set_hl(0, "FloatBorder", { bg = "#e8e8e8", fg = "#808080" })
  vim.api.nvim_set_hl(0, "ColorColumn", { bg = "#e8e8e8" })
  vim.api.nvim_set_hl(0, "MiniPickNormal", { bg = "#e8e8e8", fg = "#1f2328" })
  vim.api.nvim_set_hl(0, "MiniPickPrompt", { bg = "#e8e8e8", fg = "#1f2328" })
  vim.api.nvim_set_hl(0, "MiniPickBorder", { bg = "#e8e8e8", fg = "#808080" })
  vim.api.nvim_set_hl(0, "MiniPickHeader", { bg = "#e8e8e8", fg = "#0969da" })
  vim.api.nvim_set_hl(0, "MiniPickMatchRanges", { bg = "#dbeafe", fg = "#1f2328" })
  vim.api.nvim_set_hl(0, "MiniPickMatchCurrent", { bg = "#c8e1ff", fg = "#1f2328" })
  vim.api.nvim_set_hl(0, "MiniPickIconDirectory", { bg = "#e8e8e8", fg = "#0969da" })
  vim.api.nvim_set_hl(0, "MiniPickIconFile", { bg = "#e8e8e8", fg = "#1f2328" })

  -- --- GIT DIFF HIGHLIGHTS ---
  -- These ensure diffs are visible even with transparency
  vim.api.nvim_set_hl(0, "DiffAdd",    { fg = "#22863a", bg = "#f0fff4" }) -- Green
  vim.api.nvim_set_hl(0, "DiffDelete", { fg = "#d73a49", bg = "#ffeef0" }) -- Red
  vim.api.nvim_set_hl(0, "DiffChange", { fg = "#005cc5", bg = "#f1f8ff" }) -- Blue
  vim.api.nvim_set_hl(0, "DiffText",   { fg = "#032f62", bg = "#dbedff" }) -- Dark Blue
end

return {
  {
    "Mofiqul/vscode.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require('vscode').setup({
        style = 'light',
        transparent = true,
        italic_comments = true,
        disable_nvimtree_bg = true,
      })
      require('vscode').load()
      ColorMyPencils()
    end,
  },
}
