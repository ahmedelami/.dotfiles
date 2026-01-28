return {
  "OXY2DEV/markview.nvim",
  ft = { "markdown", "quarto", "rmd" },
  priority = 900,
  dependencies = { "nvim-treesitter/nvim-treesitter" },
  config = function()
	    local function ordered_list_marker_text(buffer, item, delimiter)
      local marker = type(item.marker) == "string" and item.marker or ""
      local marker_col = 0
      local row_start = nil

      if type(item.range) == "table" then
        row_start = item.range.row_start
        if type(item.range.col_start) == "number" then
          marker_col = item.range.col_start + (type(item.indent) == "number" and item.indent or 0)
        end
      end

      local list_index = type(item.n) == "number" and item.n or 1
      local start_num = tonumber(marker:match("^(%d+)[%.%)]$")) or 1

      if list_index > 1 and type(row_start) == "number" then
        local remaining = list_index - 1
        local chunk_end = row_start
        local chunk_size = 200
        local col1 = marker_col + 1

        while remaining > 0 and chunk_end > 0 do
          local chunk_start = math.max(0, chunk_end - chunk_size)
          local lines = vim.api.nvim_buf_get_lines(buffer, chunk_start, chunk_end, false)

          for i = #lines, 1, -1 do
            local line = lines[i]
            local tail = type(line) == "string" and line:sub(col1) or ""
            local num = tail:match("^(%d+)[%.%)]%s") or tail:match("^(%d+)[%.%)]$")

            if num then
              remaining = remaining - 1
              if remaining == 0 then
                start_num = tonumber(num) or start_num
                break
              end
            end
          end

          chunk_end = chunk_start
        end
      end

	      return string.format("%d%s", start_num + (list_index - 1), delimiter)
	    end

    local function unordered_list_marker_text(buffer, item)
      local row = nil
      local col = nil

      if type(item.range) == "table" then
        row = item.range.row_start
        if type(item.range.col_start) == "number" and type(item.indent) == "number" then
          col = item.range.col_start + item.indent
        end
      end

      local depth = 0
      if type(row) == "number" and type(col) == "number" then
        local ok_node, node = pcall(vim.treesitter.get_node, { bufnr = buffer, pos = { row, col } })
        if ok_node and node then
          local count = 0
          while node do
            if node:type() == "list_item" then
              count = count + 1
            end
            node = node:parent()
          end
          depth = math.max(0, count - 1)
        end
      end

      if depth == 0 and type(item.__nested) == "boolean" and item.__nested then
        depth = 1
      end

      if depth == 0 and type(item.indent) == "number" then
        local sw = vim.bo[buffer].shiftwidth
        if sw == 0 then
          sw = vim.bo[buffer].tabstop
        end
        if type(sw) ~= "number" or sw <= 0 then
          sw = 4
        end

        depth = math.floor(item.indent / sw)
      end

      return (depth % 2 == 1) and "○" or "●"
    end

	    require("markview").setup({
	      preview = {
	        modes = { "n", "no", "i" },
	        hybrid_modes = { "n", "i" },
	        linewise_hybrid_mode = true,
	      },
	      renderers = {
	        markdown_setext_heading = function(buffer, item)
	          local range = type(item.range) == "table" and item.range or nil
	          if not range or type(range.row_end) ~= "number" then
	            return
	          end

	          local ok_utils, utils = pcall(require, "markview.utils")
	          if not ok_utils then
	            return
	          end

	          local win = utils.buf_getwin(buffer)
	          if not win or not vim.api.nvim_win_is_valid(win) then
	            return
	          end

	          local width = vim.api.nvim_win_get_width(win)
	          local textoff = vim.fn.getwininfo(win)[1].textoff
	          local count = math.max(0, width - textoff)

	          local marker = type(item.marker) == "string" and item.marker or "---"
	          local ch = marker:match("%=") and "=" or "-"

	          local ns = vim.api.nvim_create_namespace("markview/markdown")
	          vim.api.nvim_buf_set_extmark(buffer, ns, range.row_end - 1, 0, {
	            undo_restore = false,
	            invalidate = true,
	            virt_text_pos = "overlay",
	            virt_text = { { string.rep(ch, count), "Normal" } },
	            hl_mode = "combine",
	          })
	        end,
		        markdown_code_block = function(buffer, item)
		          local ok_md, md = pcall(require, "markview.renderers.markdown")
		          if not ok_md then
		            return
		          end

		          local range = type(item.range) == "table" and item.range or nil
		          if not range or type(range.row_start) ~= "number" or type(range.row_end) ~= "number" then
		            return
		          end

		          local function conceal_line(row, start_col)
		            if type(row) ~= "number" or row < 0 then
		              return
		            end
		            if type(start_col) ~= "number" or start_col < 0 then
		              start_col = 0
		            end

		            local ok_line, lines = pcall(vim.api.nvim_buf_get_lines, buffer, row, row + 1, false)
		            local line = ok_line and type(lines) == "table" and type(lines[1]) == "string" and lines[1] or ""
		            local end_col = #line
		            if start_col >= end_col then
		              return
		            end

		            vim.api.nvim_buf_set_extmark(buffer, md.ns, row, start_col, {
		              undo_restore = false,
		              invalidate = true,
		              end_col = end_col,
		              conceal = "",
		            })
		          end

		          local start_delim = type(item.range) == "table" and item.range.start_delim or nil
		          if type(start_delim) == "table" and type(start_delim[1]) == "number" and type(start_delim[2]) == "number" then
		            conceal_line(start_delim[1], start_delim[2])
		          else
		            conceal_line(range.row_start, 0)
		          end

		          local end_delim = type(item.range) == "table" and item.range.end_delim or nil
		          if type(end_delim) == "table" and type(end_delim[1]) == "number" and type(end_delim[2]) == "number" then
		            conceal_line(end_delim[1], end_delim[2])
		          else
		            conceal_line(range.row_end - 1, 0)
		          end
		        end,
		        markdown_indented_code_block = function(buffer, item)
		          return
		        end,
	        markdown_list_item = function(buffer, item)
	          local ok_spec, spec = pcall(require, "markview.spec")
	          if not ok_spec then
	            return
	          end

	          local main_config = spec.get({ "markdown", "list_items" }, { fallback = nil, eval_args = { buffer, item } })
	          if not main_config then
	            return
	          end

	          local marker = type(item.marker) == "string" and item.marker or ""
	          if marker == "" then
	            return
	          end

	          local marker_config = nil
	          if marker == "-" then
	            marker_config = spec.get({ "marker_minus" }, { source = main_config, eval_args = { buffer, item } })
	          elseif marker == "+" then
	            marker_config = spec.get({ "marker_plus" }, { source = main_config, eval_args = { buffer, item } })
	          elseif marker == "*" then
	            marker_config = spec.get({ "marker_star" }, { source = main_config, eval_args = { buffer, item } })
	          elseif marker:match("%d+%.") then
	            marker_config = spec.get({ "marker_dot" }, { source = main_config, eval_args = { buffer, item } })
	          elseif marker:match("%d+%)") then
	            marker_config = spec.get({ "marker_parenthesis" }, { source = main_config, eval_args = { buffer, item } })
	          end

	          if marker_config and marker_config.enable == false then
	            return
	          end

	          local marker_text = (marker_config and marker_config.text) or marker

	          local hl = (marker_config and marker_config.hl) or "Normal"

	          local range = type(item.range) == "table" and item.range or nil
	          if not range or type(range.row_start) ~= "number" or type(range.col_start) ~= "number" then
	            return
	          end

	          local indent = type(item.indent) == "number" and item.indent or 0
	          local marker_col = range.col_start + indent

	          local line = ""
	          if type(item.text) == "table" and type(item.text[1]) == "string" then
	            line = item.text[1]
	          else
	            local ok_line, lines = pcall(vim.api.nvim_buf_get_lines, buffer, range.row_start, range.row_start + 1, false)
	            if ok_line and type(lines) == "table" and type(lines[1]) == "string" then
	              line = lines[1]
	            end
	          end

	          local after_start = marker_col + #marker + 1
	          local ws = line ~= "" and line:sub(after_start):match("^(%s+)") or nil
	          local ws_len = type(ws) == "string" and #ws or 0

	          local ns = vim.api.nvim_create_namespace("markview/markdown")
	          local virt = { { tostring(marker_text), hl } }
	          if ws_len > 0 then
	            table.insert(virt, { " " })
	          end

	          vim.api.nvim_buf_set_extmark(buffer, ns, range.row_start, marker_col, {
	            undo_restore = false,
	            invalidate = true,
	            end_col = marker_col + #marker + ws_len,
	            conceal = "",
	            virt_text_pos = "inline",
	            virt_text = virt,
	            hl_mode = "combine",
	          })
	        end,
		      },
				      markdown = {
				        code_blocks = {
				          sign = false,
				        },
				        horizontal_rules = {
				          parts = {
				            {
				              type = "repeating",
				              direction = "right",
			              repeat_amount = function(buffer)
			                local ok_utils, utils = pcall(require, "markview.utils")
			                if not ok_utils then
			                  return 0
			                end

			                local win = utils.buf_getwin(buffer)
			                if not win or not vim.api.nvim_win_is_valid(win) then
			                  return 0
			                end

			                local width = vim.api.nvim_win_get_width(win)
			                local textoff = vim.fn.getwininfo(win)[1].textoff
			                return math.max(0, width - textoff)
			              end,
			              text = "-",
			              hl = "Normal",
			            },
			          },
			        },
				        list_items = {
				          marker_minus = { text = function(buffer, item) return unordered_list_marker_text(buffer, item) end, hl = "Normal", add_padding = false },
				          marker_plus = { text = function(buffer, item) return unordered_list_marker_text(buffer, item) end, hl = "Normal", add_padding = false },
				          marker_star = { text = function(buffer, item) return unordered_list_marker_text(buffer, item) end, hl = "Normal", add_padding = false },
			          marker_dot = { text = function(buffer, item) return ordered_list_marker_text(buffer, item, ".") end, hl = "Normal", add_padding = false },
			          marker_parenthesis = { text = function(buffer, item) return ordered_list_marker_text(buffer, item, ")") end, hl = "Normal", add_padding = false },
			        },
	        metadata_minus = { enable = false },
	        metadata_plus = { enable = false },
	      },
    })

	    local function plain_markview_highlights()
      local groups = {}
      local ok, res = pcall(vim.fn.getcompletion, "Markview", "highlight")
      if ok and type(res) == "table" then
        groups = res
      end

	      for _, group in ipairs(groups) do
	        if type(group) == "string" and group:match("^Markview") then
	          vim.api.nvim_set_hl(0, group, { link = "Normal" })
	        end
	      end

	      for _, group in ipairs({
	        "@markup.heading.1",
        "@markup.heading.2",
        "@markup.heading.3",
        "@markup.heading.4",
        "@markup.heading.5",
        "@markup.heading.6",
        "@punctuation.special",
        "@punctuation.special.markdown",
      }) do
        pcall(vim.api.nvim_set_hl, 0, group, { link = "Normal" })
      end
    end

    local augroup = vim.api.nvim_create_augroup("HumoodagenMarkviewPlain", { clear = true })
    vim.api.nvim_create_autocmd({ "VimEnter", "ColorScheme" }, {
      group = augroup,
      callback = function()
        plain_markview_highlights()
        vim.schedule(plain_markview_highlights)
      end,
    })

    vim.api.nvim_create_autocmd("FileType", {
      group = augroup,
      pattern = { "markdown", "quarto", "rmd" },
      callback = function()
        plain_markview_highlights()
      end,
    })
  end,
}
