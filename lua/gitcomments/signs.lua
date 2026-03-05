local M = {}

-- Use the modern extmark API (available since Neovim 0.6) instead of the
-- deprecated vim.fn.sign_* functions which can cause TUI rendering issues
-- in Neovim 0.10+.
local ns = nil

local sign_text = ">>"
local sign_hl   = "GitCommentsSign"

local function get_ns()
  if not ns then
    ns = vim.api.nvim_create_namespace("gitcomments")
  end
  return ns
end

--- Configure sign appearance (idempotent).
---@param text string
---@param hl string
function M.define(text, hl)
  sign_text = text ~= "" and text or ">>"
  sign_hl   = hl

  -- Ensure the highlight group exists
  if vim.fn.hlexists(sign_hl) == 0 then
    vim.api.nvim_set_hl(0, sign_hl, { link = "DiagnosticInfo", default = true })
  end
end

--- Place signs for all given locations in a buffer.
---@param bufnr integer
---@param locations {path: string, line: integer}[]
---@param buf_rel_path string
function M.place(bufnr, locations, buf_rel_path)
  M.clear(bufnr)

  for _, loc in ipairs(locations) do
    if loc.path == buf_rel_path then
      local row = loc.line - 1 -- extmarks are 0-indexed
      if row >= 0 then
        pcall(vim.api.nvim_buf_set_extmark, bufnr, get_ns(), row, 0, {
          sign_text     = sign_text,
          sign_hl_group = sign_hl,
          priority      = 10,
        })
      end
    end
  end
end

--- Remove all gitcomments extmark signs from a buffer.
---@param bufnr integer
function M.clear(bufnr)
  pcall(vim.api.nvim_buf_clear_namespace, bufnr, get_ns(), 0, -1)
end

--- Remove all gitcomments extmark signs from every buffer.
function M.clear_all()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      pcall(vim.api.nvim_buf_clear_namespace, bufnr, get_ns(), 0, -1)
    end
  end
end

return M
