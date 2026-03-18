local M = {}

local cache = nil

local function read_file(path)
    if type(path) ~= "string" or path == "" then
        return nil
    end

    local ok, lines = pcall(vim.fn.readfile, path)
    if not ok or type(lines) ~= "table" then
        return nil
    end

    return table.concat(lines, "\n")
end

local function strip_json_comments(text)
    local out = {}
    local i = 1
    local len = #text
    local in_string = false
    local escaped = false

    while i <= len do
        local c = text:sub(i, i)
        local n = text:sub(i + 1, i + 1)

        if in_string then
            out[#out + 1] = c
            if escaped then
                escaped = false
            elseif c == "\\" then
                escaped = true
            elseif c == "\"" then
                in_string = false
            end
            i = i + 1
        elseif c == "\"" then
            in_string = true
            out[#out + 1] = c
            i = i + 1
        elseif c == "/" and n == "/" then
            i = i + 2
            while i <= len do
                local ch = text:sub(i, i)
                if ch == "\n" or ch == "\r" then
                    out[#out + 1] = ch
                    i = i + 1
                    break
                end
                i = i + 1
            end
        elseif c == "/" and n == "*" then
            i = i + 2
            while i <= len do
                local ch = text:sub(i, i)
                local next_ch = text:sub(i + 1, i + 1)
                if ch == "\n" or ch == "\r" then
                    out[#out + 1] = ch
                end
                if ch == "*" and next_ch == "/" then
                    i = i + 2
                    break
                end
                i = i + 1
            end
        else
            out[#out + 1] = c
            i = i + 1
        end
    end

    return table.concat(out)
end

local function strip_trailing_commas(text)
    local out = {}
    local i = 1
    local len = #text
    local in_string = false
    local escaped = false

    while i <= len do
        local c = text:sub(i, i)

        if in_string then
            out[#out + 1] = c
            if escaped then
                escaped = false
            elseif c == "\\" then
                escaped = true
            elseif c == "\"" then
                in_string = false
            end
            i = i + 1
        elseif c == "\"" then
            in_string = true
            out[#out + 1] = c
            i = i + 1
        elseif c == "," then
            local j = i + 1
            while j <= len do
                local ch = text:sub(j, j)
                if ch:match("%s") then
                    j = j + 1
                else
                    break
                end
            end

            local next_ch = text:sub(j, j)
            if next_ch ~= "}" and next_ch ~= "]" then
                out[#out + 1] = c
            end
            i = i + 1
        else
            out[#out + 1] = c
            i = i + 1
        end
    end

    return table.concat(out)
end

local function decode_json(text, allow_comments)
    if type(text) ~= "string" or text == "" then
        return nil
    end

    local decoded = text
    if allow_comments then
        decoded = strip_trailing_commas(strip_json_comments(decoded))
    end

    local ok, data = pcall(vim.json.decode, decoded)
    if not ok then
        return nil
    end

    return data
end

local function normalize_hex(hex, bg_hex)
    if type(hex) ~= "string" or hex == "" or hex == "NONE" then
        return nil
    end

    if hex:match("^#%x%x%x%x%x%x$") then
        return hex:upper()
    end

    if not hex:match("^#%x%x%x%x%x%x%x%x$") then
        return nil
    end

    local bg = bg_hex
    if type(bg) ~= "string" or not bg:match("^#%x%x%x%x%x%x$") then
        return ("#" .. hex:sub(2, 7)):upper()
    end

    local function byte(str, first)
        return tonumber(str:sub(first, first + 1), 16) or 0
    end

    local fg_r, fg_g, fg_b = byte(hex, 2), byte(hex, 4), byte(hex, 6)
    local bg_r, bg_g, bg_b = byte(bg, 2), byte(bg, 4), byte(bg, 6)
    local alpha = (byte(hex, 8) or 255) / 255

    local function blend(fg_chan, bg_chan)
        return math.floor((fg_chan * alpha) + (bg_chan * (1 - alpha)) + 0.5)
    end

    return string.format("#%02X%02X%02X", blend(fg_r, bg_r), blend(fg_g, bg_g), blend(fg_b, bg_b))
end

function M.to_int(hex)
    local normalized = normalize_hex(hex)
    if not normalized then
        return nil
    end

    return tonumber(normalized:sub(2), 16)
end

local function list_theme_files()
    local home = vim.env.HOME or ""
    local roots = {
        "/Applications/Visual Studio Code.app/Contents/Resources/app/extensions",
        "/Applications/Visual Studio Code - Insiders.app/Contents/Resources/app/extensions",
    }

    if home ~= "" then
        roots[#roots + 1] = home .. "/.vscode/extensions"
        roots[#roots + 1] = home .. "/.vscode-insiders/extensions"
    end

    local files = {}
    local seen = {}

    for _, root in ipairs(roots) do
        if vim.fn.isdirectory(root) == 1 then
            local matches = vim.fn.globpath(root, "*/themes/*.json", true, true)
            for _, match in ipairs(matches) do
                if not seen[match] then
                    seen[match] = true
                    files[#files + 1] = match
                end
            end
        end
    end

    return files
end

local function resolve_theme_file(theme_name)
    if type(theme_name) ~= "string" or theme_name == "" then
        return nil
    end

    for _, file in ipairs(list_theme_files()) do
        local data = decode_json(read_file(file), false)
        if type(data) == "table" and data.name == theme_name then
            return file
        end
    end

    return nil
end

local function load_theme_file(path, seen)
    if type(path) ~= "string" or path == "" then
        return nil
    end

    seen = seen or {}
    if seen[path] then
        return nil
    end
    seen[path] = true

    local data = decode_json(read_file(path), false)
    if type(data) ~= "table" then
        return nil
    end

    local merged = {
        name = data.name,
        path = path,
        colors = {},
        tokenColors = {},
        semanticTokenColors = {},
    }

    if type(data.include) == "string" and data.include ~= "" then
        local include_path = vim.fn.fnamemodify(path, ":h") .. "/" .. data.include
        local base = load_theme_file(include_path, seen)
        if type(base) == "table" then
            merged.colors = vim.tbl_deep_extend("force", merged.colors, base.colors or {})
            merged.semanticTokenColors = vim.tbl_deep_extend("force", merged.semanticTokenColors, base.semanticTokenColors or {})
            for _, item in ipairs(base.tokenColors or {}) do
                merged.tokenColors[#merged.tokenColors + 1] = item
            end
        end
    end

    merged.colors = vim.tbl_deep_extend("force", merged.colors, data.colors or {})
    merged.semanticTokenColors = vim.tbl_deep_extend("force", merged.semanticTokenColors, data.semanticTokenColors or {})

    for _, item in ipairs(data.tokenColors or {}) do
        merged.tokenColors[#merged.tokenColors + 1] = item
    end

    return merged
end

local function split_scopes(scope)
    if type(scope) == "table" then
        return scope
    end

    if type(scope) ~= "string" or scope == "" then
        return {}
    end

    local scopes = {}
    for part in scope:gmatch("[^,]+") do
        scopes[#scopes + 1] = vim.trim(part)
    end
    return scopes
end

local function scope_matches(selector, wanted)
    if selector == wanted then
        return true
    end

    return wanted:sub(1, #selector + 1) == (selector .. ".")
end

local function find_token_color(theme, wanted_scopes)
    if type(theme) ~= "table" then
        return nil
    end

    for _, wanted in ipairs(wanted_scopes) do
        for idx = #(theme.tokenColors or {}), 1, -1 do
            local item = theme.tokenColors[idx]
            local settings = type(item) == "table" and item.settings or nil
            if type(settings) == "table" and type(settings.foreground) == "string" then
                for _, selector in ipairs(split_scopes(item.scope)) do
                    if scope_matches(selector, wanted) then
                        return normalize_hex(settings.foreground, theme.ui and theme.ui.editor_background or nil)
                    end
                end
            end
        end
    end

    return nil
end

local function semantic_color(theme, key)
    if type(theme) ~= "table" or type(key) ~= "string" or key == "" then
        return nil
    end

    local value = theme.semanticTokenColors and theme.semanticTokenColors[key] or nil
    if type(value) == "string" then
        return normalize_hex(value, theme.ui and theme.ui.editor_background or nil)
    end
    if type(value) == "table" and type(value.foreground) == "string" then
        return normalize_hex(value.foreground, theme.ui and theme.ui.editor_background or nil)
    end

    return nil
end

local function theme_name_from_settings()
    local home = vim.env.HOME or ""
    if home == "" then
        return nil
    end

    local settings_path = home .. "/Library/Application Support/Code/User/settings.json"
    local settings = decode_json(read_file(settings_path), true)
    if type(settings) ~= "table" then
        return nil
    end

    return settings["workbench.colorTheme"]
end

local function extract_ui(theme)
    local bg = normalize_hex(theme.colors["editor.background"])
    local function color(key, fallback)
        return normalize_hex(theme.colors[key], bg) or fallback
    end

    return {
        editor_background = bg,
        editor_foreground = color("editor.foreground", normalize_hex(theme.colors.foreground, bg)),
        line_number = color("editorLineNumber.foreground"),
        line_number_active = color("editorLineNumber.activeForeground"),
        selection = color("editor.selectionBackground", color("editor.inactiveSelectionBackground")),
        inactive_selection = color("editor.inactiveSelectionBackground"),
        widget_background = color("editorWidget.background", color("quickInput.background")),
        tab_active_background = color("tab.activeBackground", bg),
        tab_inactive_background = color("tab.inactiveBackground", color("sideBar.background")),
        side_bar_background = color("sideBar.background", color("statusBar.background")),
        status_bar_background = color("statusBar.background", color("sideBar.background")),
        border = color("editorGroup.border", color("panel.border", color("sideBar.border"))),
        cursor = color("terminalCursor.foreground"),
        list_hover_background = color("list.hoverBackground"),
        list_active_selection_background = color("list.activeSelectionBackground"),
        line_highlight = color("editor.lineHighlightBackground"),
        focus_border = color("focusBorder"),
    }
end

local function extract_tokens(theme)
    return {
        comment = find_token_color(theme, { "comment" }),
        string = semantic_color(theme, "stringLiteral") or find_token_color(theme, { "string" }),
        number = semantic_color(theme, "numberLiteral") or find_token_color(theme, { "constant.numeric", "number" }),
        func = find_token_color(theme, { "entity.name.function", "support.function" }),
        keyword = find_token_color(theme, { "keyword.control", "keyword.other.operator", "entity.name.operator" }),
        variable = find_token_color(theme, { "variable", "meta.definition.variable.name", "entity.name.variable" }),
        constant = find_token_color(theme, { "variable.other.constant", "variable.other.enummember" }),
        property = find_token_color(theme, { "meta.object-literal.key" }),
        type = find_token_color(theme, { "support.class", "support.type", "entity.name.type", "entity.name.class" }),
    }
end

local function tbl_with_values(input)
    local out = {}
    for key, value in pairs(input or {}) do
        if value ~= nil then
            out[key] = value
        end
    end
    return out
end

function M.current()
    if cache ~= nil then
        return cache or nil
    end

    local theme_name = theme_name_from_settings()
    local theme_file = resolve_theme_file(theme_name)
    local theme = load_theme_file(theme_file)

    if type(theme) ~= "table" then
        cache = false
        return nil
    end

    theme.name = theme_name
    theme.path = theme_file
    theme.ui = extract_ui(theme)
    theme.tokens = extract_tokens(theme)

    cache = theme
    return theme
end

function M.refresh()
    cache = nil
    return M.current()
end

function M.color_overrides(theme)
    theme = theme or M.current()
    if type(theme) ~= "table" then
        return {}
    end

    local ui = theme.ui or {}
    local tokens = theme.tokens or {}

    return tbl_with_values({
        vscFront = ui.editor_foreground,
        vscBack = ui.editor_background,
        vscLineNumber = ui.line_number,
        vscCursorDark = ui.cursor,
        vscCursorDarkDark = ui.line_highlight or ui.tab_inactive_background or ui.widget_background,
        vscPopupFront = ui.editor_foreground,
        vscPopupBack = ui.widget_background,
        vscPopupHighlightGray = ui.list_hover_background or ui.list_active_selection_background,
        vscSelection = ui.selection or ui.inactive_selection,
        vscTabCurrent = ui.tab_active_background,
        vscTabOther = ui.tab_inactive_background,
        vscTabOutside = ui.side_bar_background or ui.status_bar_background,
        vscLeftDark = ui.side_bar_background or ui.status_bar_background,
        vscLeftMid = ui.side_bar_background or ui.status_bar_background,
        vscLeftLight = ui.side_bar_background or ui.status_bar_background,
        vscSplitDark = ui.border,
        vscSplitLight = ui.border,
        vscGreen = tokens.comment,
        vscOrange = tokens.string,
        vscLightRed = tokens.string,
        vscLightGreen = tokens.number,
        vscYellow = tokens.func,
        vscPink = tokens.keyword,
        vscLightBlue = tokens.variable,
    })
end

local function text_hl(fg)
    if not fg then
        return nil
    end

    return { fg = fg, bg = "NONE" }
end

local function background_hl(bg)
    if not bg then
        return nil
    end

    return { bg = bg }
end

function M.highlight_overrides(theme)
    theme = theme or M.current()
    if type(theme) ~= "table" then
        return {}
    end

    local ui = theme.ui or {}
    local tokens = theme.tokens or {}
    local property = tokens.property or tokens.variable

    return tbl_with_values({
        Normal = tbl_with_values({ fg = ui.editor_foreground, bg = ui.editor_background }),
        NormalFloat = background_hl(ui.widget_background),
        CursorLine = background_hl(ui.line_highlight or ui.tab_inactive_background or ui.widget_background),
        ColorColumn = background_hl(ui.line_highlight or ui.tab_inactive_background or ui.widget_background),
        Visual = background_hl(ui.selection or ui.inactive_selection),
        LineNr = tbl_with_values({ fg = ui.line_number, bg = ui.editor_background }),
        LineNrAbove = tbl_with_values({ fg = ui.line_number, bg = ui.editor_background }),
        LineNrBelow = tbl_with_values({ fg = ui.line_number, bg = ui.editor_background }),
        FoldColumn = tbl_with_values({ fg = ui.line_number, bg = ui.editor_background }),
        CursorLineNr = tbl_with_values({ fg = ui.line_number_active or ui.editor_foreground, bg = ui.editor_background }),

        Comment = text_hl(tokens.comment),
        SpecialComment = text_hl(tokens.comment),
        ["@comment"] = text_hl(tokens.comment),

        String = text_hl(tokens.string),
        Character = text_hl(tokens.string),
        ["@string"] = text_hl(tokens.string),

        Number = text_hl(tokens.number),
        Float = text_hl(tokens.number),
        ["@number"] = text_hl(tokens.number),
        ["@number.float"] = text_hl(tokens.number),

        Function = text_hl(tokens.func),
        ["@function"] = text_hl(tokens.func),
        ["@function.builtin"] = text_hl(tokens.func),
        ["@function.macro"] = text_hl(tokens.func),
        ["@function.method"] = text_hl(tokens.func),
        ["@lsp.type.function"] = text_hl(tokens.func),
        ["@lsp.type.method"] = text_hl(tokens.func),

        Statement = text_hl(tokens.keyword),
        Conditional = text_hl(tokens.keyword),
        Repeat = text_hl(tokens.keyword),
        Label = text_hl(tokens.keyword),
        Keyword = text_hl(tokens.keyword),
        Exception = text_hl(tokens.keyword),
        PreProc = text_hl(tokens.keyword),
        Include = text_hl(tokens.keyword),
        Define = text_hl(tokens.keyword),
        Macro = text_hl(tokens.keyword),
        ["@keyword"] = text_hl(tokens.keyword),
        ["@keyword.conditional"] = text_hl(tokens.keyword),
        ["@keyword.repeat"] = text_hl(tokens.keyword),
        ["@keyword.return"] = text_hl(tokens.keyword),
        ["@keyword.exception"] = text_hl(tokens.keyword),
        ["@keyword.import"] = text_hl(tokens.keyword),
        ["@lsp.type.keyword"] = text_hl(tokens.keyword),
        ["@lsp.typemod.keyword.controlFlow"] = text_hl(tokens.keyword),

        Identifier = text_hl(tokens.variable),
        ["@variable"] = text_hl(tokens.variable),
        ["@variable.parameter"] = text_hl(tokens.variable),
        ["@variable.parameter.reference"] = text_hl(tokens.variable),
        ["@variable.member"] = text_hl(property),
        ["@property"] = text_hl(property),
        ["@label"] = text_hl(tokens.variable),
        ["@lsp.type.variable"] = text_hl(tokens.variable),
        ["@lsp.type.parameter"] = text_hl(tokens.variable),
        ["@lsp.type.property"] = text_hl(property),

        Constant = text_hl(tokens.constant),
        Boolean = text_hl(tokens.constant),
        ["@constant"] = text_hl(tokens.constant),
        ["@constant.builtin"] = text_hl(tokens.constant),
        ["@lsp.type.enumMember"] = text_hl(tokens.constant),
        ["@lsp.typemod.variable.readonly"] = text_hl(tokens.constant),
        ["@lsp.typemod.property.readonly"] = text_hl(tokens.constant),
        ["@lsp.typemod.variable.constant"] = text_hl(tokens.constant),

        Type = text_hl(tokens.type),
        StorageClass = text_hl(tokens.type),
        Typedef = text_hl(tokens.type),
        ["@type"] = text_hl(tokens.type),
        ["@type.builtin"] = text_hl(tokens.type),
        ["@constructor"] = text_hl(tokens.type),
        ["@lsp.type.type"] = text_hl(tokens.type),
        ["@lsp.type.typeParameter"] = text_hl(tokens.type),
        ["@lsp.type.class"] = text_hl(tokens.type),
        ["@lsp.type.interface"] = text_hl(tokens.type),
        ["@lsp.type.enum"] = text_hl(tokens.type),
    })
end

function M.apply(theme)
    theme = theme or M.current()
    if type(theme) ~= "table" then
        return
    end

    for group, spec in pairs(M.highlight_overrides(theme)) do
        if type(spec) == "table" and next(spec) ~= nil then
            pcall(vim.api.nvim_set_hl, 0, group, spec)
        end
    end
end

function M.setup()
    local group = vim.api.nvim_create_augroup("HumoodagenVsCodeThemeSync", { clear = true })
    vim.api.nvim_create_autocmd("ColorScheme", {
        group = group,
        callback = function()
            M.apply()
        end,
    })
end

return M
