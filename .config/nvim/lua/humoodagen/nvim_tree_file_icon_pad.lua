---@class (exact) HumoodagenNvimTreeFileIconPad: nvim_tree.api.decorator.UserDecorator
local FileIconPad = require("nvim-tree.api").decorator.UserDecorator:extend()

function FileIconPad:new()
  self.enabled = true
  self.highlight_range = "none"
  self.icon_placement = "none"
end

---@param node nvim_tree.api.Node
---@return nvim_tree.api.HighlightedString? icon_node
function FileIconPad:icon_node(node)
  if not node or node.type ~= "file" then
    return nil
  end

  local ok_core, core = pcall(require, "nvim-tree.core")
  if not ok_core then
    return nil
  end

  local explorer = core.get_explorer()
  local renderer = explorer and explorer.opts and explorer.opts.renderer or nil
  local icons_cfg = renderer and renderer.icons or nil
  if not icons_cfg then
    return nil
  end

  if not icons_cfg.show or icons_cfg.show.file ~= true then
    return nil
  end

  local icon_str, icon_hl

  local web_devicons = icons_cfg.web_devicons
  if web_devicons and web_devicons.file and web_devicons.file.enable then
    local ok_icons, icons = pcall(require, "nvim-tree.renderer.components.devicons")
    if ok_icons then
      icon_str, icon_hl = icons.get_icon(node.name, nil, { default = true })
      if web_devicons.file.color == false then
        icon_hl = nil
      end
    end
  end

  if not icon_str and icons_cfg.glyphs then
    icon_str = icons_cfg.glyphs.default
  end

  if not icon_str or icon_str == "" then
    return nil
  end

  if not icon_hl or icon_hl == "" then
    icon_hl = "NvimTreeFileIcon"
  end

  if icon_str:sub(-1) ~= " " then
    icon_str = icon_str .. " "
  end

  return { str = icon_str, hl = { icon_hl } }
end

return FileIconPad
