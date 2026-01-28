local M = {}

local function is_visual_mode(mode)
    local m = mode or vim.api.nvim_get_mode().mode
    local prefix = m:sub(1, 1)
    return prefix == "v" or prefix == "V" or m == "\22"
end

local function get_visual_range()
    local start = vim.api.nvim_buf_get_mark(0, "<")
    local finish = vim.api.nvim_buf_get_mark(0, ">")
    if start[1] == 0 or finish[1] == 0 then
        return nil
    end

    if start[1] > finish[1] or (start[1] == finish[1] and start[2] > finish[2]) then
        start, finish = finish, start
    end

    return { start = start, ["end"] = finish }
end

local function parse_fence_line(line)
    local indent, fence = line:match("^([ \t]*)([`~]{3,})")
    if not fence then
        return nil
    end

    local info = line:sub(#indent + #fence + 1):gsub("^%s*", "")

    return {
        indent = indent,
        fence_char = fence:sub(1, 1),
        fence_len = #fence,
        info = info,
    }
end

local function fence_language(info)
    if type(info) ~= "string" or info == "" then
        return nil
    end

    -- Support quarto-style {python} fences too.
    local first = info:match("^(%S+)")
    if not first then
        return nil
    end

    first = first:gsub("^%{", ""):gsub("%}$", "")
    first = first:match("^(%S+)")
    return first ~= "" and first or nil
end

local function find_fenced_code_block(bufnr, line0)
    local max = vim.api.nvim_buf_line_count(bufnr)
    if max == 0 then
        return nil
    end

    local target = math.min(math.max(line0, 0), max - 1)

    -- Scan from the start of the buffer to determine whether we're currently
    -- inside a fenced code block at {target}. This avoids confusing a closing
    -- fence for an opening fence.
    local to_target = vim.api.nvim_buf_get_lines(bufnr, 0, target + 1, false)
    local inside = false
    local open = nil

    for i, line in ipairs(to_target) do
        local fence = parse_fence_line(line)
        if fence then
            local lnum = i - 1
            if not inside then
                inside = true
                open = vim.tbl_extend("force", fence, { open_line = lnum })
            else
                if open and fence.fence_char == open.fence_char and fence.fence_len >= open.fence_len then
                    inside = false
                    open = nil
                end
            end
        end
    end

    if not inside or not open then
        return nil
    end

    local rest = vim.api.nvim_buf_get_lines(bufnr, open.open_line + 1, -1, false)
    for idx, line in ipairs(rest) do
        local fence = parse_fence_line(line)
        if fence and fence.fence_char == open.fence_char and fence.fence_len >= open.fence_len then
            local close_line = open.open_line + idx
            return {
                open_line = open.open_line,
                close_line = close_line,
                indent = open.indent or "",
                info = open.info or "",
            }
        end
    end

    return nil
end

local function format_with_conform(bufnr, range)
    local ok, conform = pcall(require, "conform")
    if not ok then
        return false
    end

    local opts = {
        bufnr = bufnr,
        async = false,
        timeout_ms = 3000,
        quiet = true,
        lsp_format = "fallback",
    }

    if range then
        opts.range = range
    end

    return conform.format(opts) == true
end

local function format_temp_buffer(parent_bufnr, ft, lines)
    local tmp = vim.api.nvim_create_buf(false, false)

    vim.bo[tmp].bufhidden = "wipe"
    vim.bo[tmp].swapfile = false
    vim.bo[tmp].undofile = false
    vim.bo[tmp].modifiable = true

    vim.api.nvim_buf_set_lines(tmp, 0, -1, false, lines)

    local parent_name = vim.api.nvim_buf_get_name(parent_bufnr)
    local dir = parent_name ~= "" and vim.fn.fnamemodify(parent_name, ":h") or vim.fn.getcwd()
    local ext = ft and ft ~= "" and ft or "txt"

    pcall(vim.api.nvim_buf_set_name, tmp, string.format("%s/.nvim_fence_format_%d.%s", dir, vim.uv.hrtime(), ext))

    if ft and ft ~= "" then
        vim.bo[tmp].filetype = ft
    end

    local did_attempt = format_with_conform(tmp)

    if not did_attempt then
        vim.api.nvim_buf_call(tmp, function()
            vim.cmd("silent normal! gg=G")
        end)
    end

    local formatted = vim.api.nvim_buf_get_lines(tmp, 0, -1, false)
    pcall(vim.api.nvim_buf_delete, tmp, { force = true })

    return formatted
end

local function format_markdown_fence()
    local bufnr = vim.api.nvim_get_current_buf()
    local row0 = vim.api.nvim_win_get_cursor(0)[1] - 1

    local fence = find_fenced_code_block(bufnr, row0)
    if not fence and row0 > 0 then
        fence = find_fenced_code_block(bufnr, row0 - 1)
    end
    if not fence then
        return false
    end

    local lang = fence_language(fence.info)
    if not lang then
        vim.notify("No language on this fenced code block (e.g. ```lua)", vim.log.levels.WARN)
        return false
    end

    local ft = vim.filetype.match({ filename = "fence." .. lang })
    if not ft or ft == "" then
        ft = lang
    end

    local content_start = fence.open_line + 1
    local content_end = fence.close_line
    if content_end <= content_start then
        return true
    end

    local indent_prefix = fence.indent or ""
    local content = vim.api.nvim_buf_get_lines(bufnr, content_start, content_end, false)

    local stripped = {}
    for _, line in ipairs(content) do
        if indent_prefix ~= "" and line:sub(1, #indent_prefix) == indent_prefix then
            table.insert(stripped, line:sub(#indent_prefix + 1))
        else
            table.insert(stripped, line)
        end
    end

    local formatted = format_temp_buffer(bufnr, ft, stripped)

    local reindented = {}
    for _, line in ipairs(formatted) do
        if line ~= "" and indent_prefix ~= "" then
            table.insert(reindented, indent_prefix .. line)
        else
            table.insert(reindented, line)
        end
    end

    vim.api.nvim_buf_set_lines(bufnr, content_start, content_end, false, reindented)
    return true
end

function M.format()
    local bufnr = vim.api.nvim_get_current_buf()
    local ft = vim.bo[bufnr].filetype
    local mode = vim.api.nvim_get_mode().mode

    if ft == "markdown" or ft == "quarto" or ft == "rmd" then
        if format_markdown_fence() then
            return
        end
    end

    if is_visual_mode(mode) then
        format_with_conform(bufnr, get_visual_range())
        return
    end

    format_with_conform(bufnr)
end

function M.equalize()
    local bufnr = vim.api.nvim_get_current_buf()
    local ft = vim.bo[bufnr].filetype

    if ft == "markdown" or ft == "quarto" or ft == "rmd" then
        if format_markdown_fence() then
            return
        end
    end

    vim.cmd("normal! =")
end

function M.setup()
    local group = vim.api.nvim_create_augroup("HumoodagenMarkdownFenceFormat", { clear = true })
    vim.api.nvim_create_autocmd("FileType", {
        group = group,
        pattern = { "markdown", "quarto", "rmd" },
        callback = function(args)
            vim.keymap.set("x", "=", function()
                require("humoodagen.format").equalize()
            end, { buffer = args.buf, desc = "Indent (format fenced blocks when possible)" })
        end,
    })
end

return M
