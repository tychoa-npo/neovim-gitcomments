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

local function call(fn)
  local ok, err = pcall(fn)
  if not ok then
    vim.notify("[gitcomments] ERROR: " .. tostring(err), vim.log.levels.ERROR)
  end
end

--- :GitComments — show comment at the current cursor line
vim.api.nvim_create_user_command("GitComments", function()
  call(function() get_gitcomments().show_comment(vim.api.nvim_get_current_buf()) end)
end, { desc = "Show PR comment at cursor line" })

--- :GitCommentsLoad — (re)fetch PR comments for the current repo
vim.api.nvim_create_user_command("GitCommentsLoad", function()
  call(function() get_gitcomments().load_comments(vim.api.nvim_get_current_buf(), { force = true }) end)
end, { desc = "Fetch (or refresh) PR comments for the current repo" })

--- :GitCommentsClear — remove signs and clear cache
vim.api.nvim_create_user_command("GitCommentsClear", function()
  call(function() get_gitcomments().clear(vim.api.nvim_get_current_buf()) end)
end, { desc = "Clear all PR comment signs and cache" })

--- :GitCommentsDebug — print raw gh output to help diagnose issues
vim.api.nvim_create_user_command("GitCommentsDebug", function()
  local bufnr = vim.api.nvim_get_current_buf()
  local buf_path = vim.api.nvim_buf_get_name(bufnr)
  local dir = vim.fn.fnamemodify(buf_path, ":h")
  vim.notify("[gitcomments] buf=" .. buf_path, vim.log.levels.INFO)
  vim.fn.jobstart({ "git", "-C", dir, "rev-parse", "--show-toplevel" }, {
    stdin = "null",
    on_stdout = function(_, data) vim.schedule(function()
      vim.notify("[gitcomments] repo_root: " .. table.concat(data, " "), vim.log.levels.INFO)
    end) end,
    on_stderr = function(_, data) vim.schedule(function()
      vim.notify("[gitcomments] git err: " .. table.concat(data, " "), vim.log.levels.WARN)
    end) end,
    on_exit = function(_, code) vim.schedule(function()
      vim.notify("[gitcomments] git exit=" .. code, vim.log.levels.INFO)
      vim.fn.jobstart({ "git", "-C", dir, "rev-parse", "--abbrev-ref", "HEAD" }, {
          stdin = "null",
        on_stdout = function(_, d) vim.schedule(function()
          vim.notify("[gitcomments] branch: " .. table.concat(d, " "), vim.log.levels.INFO)
        end) end,
        on_exit = function(_, c) vim.schedule(function()
          vim.notify("[gitcomments] branch exit=" .. c, vim.log.levels.INFO)
        end) end,
      })
    end) end,
  })
end, { desc = "Debug gitcomments setup" })

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

    -- Defer auto-load by 500 ms so the buffer is fully settled and we don't
    -- fire during noice.nvim's CmdlineEnter processing.
    vim.defer_fn(function()
      local ok, gc = pcall(require, "gitcomments")
      if not ok then return end
      local cfg = require("gitcomments.config")
      if cfg.options.auto_load then
        gc.load_comments(ev.buf, {})
      end
    end, 500)
  end,
  desc = "Auto-load PR comments on buffer open",
})
