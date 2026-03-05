local M = {}

local config = require("gitcomments.config")

-- Track the currently open floating window so we can close it.
local current_win = nil
local current_buf = nil

--- Format a single review thread into markdown lines.
---@param thread table reviewThread object
---@return string[]
local function format_thread(thread)
  local lines = {}

  if thread.isResolved then
    table.insert(lines, "~~**[Resolved]**~~")
    table.insert(lines, "")
  end

  for i, comment in ipairs(thread.comments or {}) do
    local author = (comment.author and comment.author.login) or "unknown"
    local date = ""
    if comment.createdAt then
      date = " · " .. comment.createdAt:match("^(%d%d%d%d%-%d%d%-%d%d)")
    end

    if i > 1 then
      table.insert(lines, "---")
      table.insert(lines, "")
    end

    table.insert(lines, string.format("**@%s**%s", author, date))
    table.insert(lines, "")

    -- Split body into individual lines
    for _, body_line in ipairs(vim.split(comment.body or "", "\n", { plain = true })) do
      table.insert(lines, body_line)
    end
    table.insert(lines, "")
  end

  return lines
end

--- Build the full content for the floating window from one or more threads.
---@param threads table[]
---@return string[]
local function build_lines(threads)
  local lines = {}
  for i, thread in ipairs(threads) do
    if i > 1 then
      table.insert(lines, "═══════════════════")
      table.insert(lines, "")
    end
    vim.list_extend(lines, format_thread(thread))
  end
  -- Remove trailing blank lines
  while #lines > 0 and lines[#lines] == "" do
    table.remove(lines)
  end
  return lines
end

--- Close any existing gitcomments floating window.
function M.close()
  if current_win and vim.api.nvim_win_is_valid(current_win) then
    vim.api.nvim_win_close(current_win, true)
  end
  current_win = nil
  current_buf = nil
end

--- Open a floating window showing the given threads near the cursor line.
---@param threads table[]
function M.show(threads)
  M.close()

  local lines = build_lines(threads)
  if #lines == 0 then return end

  local opts = config.options
  local max_w = opts.max_comment_width
  local max_h = opts.max_comment_height

  -- Calculate window dimensions
  local width = 0
  for _, line in ipairs(lines) do
    -- Strip markdown bold markers for width calculation
    local plain = line:gsub("%*%*", ""):gsub("~~", "")
    width = math.max(width, vim.fn.strdisplaywidth(plain))
  end
  width = math.min(math.max(width, 40), max_w)
  local height = math.min(#lines, max_h)

  -- Position: just below the current cursor line, left-aligned to cursor col
  local cursor = vim.api.nvim_win_get_cursor(0)
  local win_height = vim.api.nvim_win_get_height(0)
  local cursor_row = cursor[1] -- 1-based screen row in window

  -- Decide whether to open above or below
  local row_offset = 1
  local anchor = "NW"
  if cursor_row + height + 1 > win_height then
    row_offset = 0
    anchor = "SW"
  end

  -- Create scratch buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"

  local win = vim.api.nvim_open_win(buf, false, {
    relative = "cursor",
    row = row_offset,
    col = 0,
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    anchor = anchor,
    focusable = false,
  })

  -- Subtle background tint
  vim.api.nvim_win_set_option(win, "winhl", "Normal:GitCommentsFloat,FloatBorder:GitCommentsFloatBorder")

  -- Ensure highlight groups exist
  if vim.fn.hlexists("GitCommentsFloat") == 0 then
    vim.api.nvim_set_hl(0, "GitCommentsFloat", { link = "NormalFloat", default = true })
  end
  if vim.fn.hlexists("GitCommentsFloatBorder") == 0 then
    vim.api.nvim_set_hl(0, "GitCommentsFloatBorder", { link = "FloatBorder", default = true })
  end

  current_win = win
  current_buf = buf

  -- Auto-close when cursor moves away
  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "BufLeave", "InsertEnter" }, {
    once = true,
    callback = function()
      M.close()
    end,
  })
end

return M
