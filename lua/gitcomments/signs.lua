local M = {}

local SIGN_GROUP = "gitcomments"
local SIGN_NAME = "GitCommentsSign"

local initialized = false

--- Define the sign (idempotent).
---@param sign_text string
---@param sign_hl string
function M.define(sign_text, sign_hl)
  if initialized then return end
  initialized = true

  -- Ensure the highlight group exists (link to a sensible default if not set)
  if vim.fn.hlexists(sign_hl) == 0 then
    vim.api.nvim_set_hl(0, sign_hl, { link = "DiagnosticInfo", default = true })
  end

  vim.fn.sign_define(SIGN_NAME, {
    text = sign_text,
    texthl = sign_hl,
  })
end

--- Place signs for all given locations in a buffer.
---@param bufnr integer
---@param locations {path: string, line: integer}[] Locations relative to repo root
---@param buf_rel_path string The relative path of this buffer inside the repo
function M.place(bufnr, locations, buf_rel_path)
  -- Clear existing signs for this buffer first
  M.clear(bufnr)

  for _, loc in ipairs(locations) do
    if loc.path == buf_rel_path then
      vim.fn.sign_place(0, SIGN_GROUP, SIGN_NAME, bufnr, { lnum = loc.line, priority = 10 })
    end
  end
end

--- Remove all gitcomments signs from a buffer.
---@param bufnr integer
function M.clear(bufnr)
  vim.fn.sign_unplace(SIGN_GROUP, { buffer = bufnr })
end

--- Remove all gitcomments signs globally.
function M.clear_all()
  vim.fn.sign_unplace(SIGN_GROUP)
end

return M
