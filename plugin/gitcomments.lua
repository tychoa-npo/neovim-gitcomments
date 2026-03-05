-- plugin/gitcomments.lua
-- Entry point loaded by Neovim's plugin runtime. Sets up commands and
-- optional auto-load behaviour after the plugin is configured via setup().

if vim.g.loaded_gitcomments then
  return
end
vim.g.loaded_gitcomments = true

local function get_gitcomments()
  return require("gitcomments")
end

-- ── Commands ──────────────────────────────────────────────────────────────────

--- :GitComments — show comment at the current cursor line
vim.api.nvim_create_user_command("GitComments", function()
  get_gitcomments().show_comment(vim.api.nvim_get_current_buf())
end, { desc = "Show PR comment at cursor line" })

--- :GitCommentsLoad — (re)fetch PR comments for the current repo
vim.api.nvim_create_user_command("GitCommentsLoad", function()
  get_gitcomments().load_comments(vim.api.nvim_get_current_buf(), { force = true })
end, { desc = "Fetch (or refresh) PR comments for the current repo" })

--- :GitCommentsClear — remove signs and clear cache
vim.api.nvim_create_user_command("GitCommentsClear", function()
  get_gitcomments().clear(vim.api.nvim_get_current_buf())
end, { desc = "Clear all PR comment signs and cache" })

-- ── Autocommands ──────────────────────────────────────────────────────────────

local augroup = vim.api.nvim_create_augroup("GitComments", { clear = true })

-- Auto-load comments when opening a real file buffer.
-- The `auto_load` option is checked at runtime so it respects the user's setup() call.
vim.api.nvim_create_autocmd("BufReadPost", {
  group = augroup,
  callback = function(ev)
    -- Only act on normal file buffers
    if vim.bo[ev.buf].buftype ~= "" then return end
    if vim.api.nvim_buf_get_name(ev.buf) == "" then return end

    vim.schedule(function()
      local ok, gc = pcall(require, "gitcomments")
      if not ok then return end
      local cfg = require("gitcomments.config")
      if cfg.options.auto_load then
        gc.load_comments(ev.buf, {})
      end
    end)
  end,
  desc = "Auto-load PR comments on buffer open",
})
