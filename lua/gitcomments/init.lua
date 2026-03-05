local M = {}

local config = require("gitcomments.config")
local github = require("gitcomments.github")
local comments = require("gitcomments.comments")
local signs = require("gitcomments.signs")
local ui = require("gitcomments.ui")

-- Track loading state per repo root to avoid duplicate requests.
local loading = {}

--- Get the repository root for the current buffer's directory.
---@param bufnr integer
---@param callback fun(root: string|nil)
local function get_repo_root(bufnr, callback)
  local buf_path = vim.api.nvim_buf_get_name(bufnr)
  if buf_path == "" then
    callback(nil)
    return
  end
  local dir = vim.fn.fnamemodify(buf_path, ":h")
  github.get_repo_root(dir, callback)
end

--- Get the file path of bufnr relative to repo_root.
---@param bufnr integer
---@param repo_root string
---@return string|nil
local function rel_path(bufnr, repo_root)
  local buf_path = vim.api.nvim_buf_get_name(bufnr)
  if buf_path == "" then return nil end
  -- Normalise: strip trailing slash from root then strip prefix
  local root = repo_root:gsub("/$", "")
  if buf_path:sub(1, #root + 1) == root .. "/" then
    return buf_path:sub(#root + 2)
  end
  return nil
end

--- Refresh signs for bufnr given the current comment cache.
---@param bufnr integer
---@param repo_root string
local function refresh_signs(bufnr, repo_root)
  if not vim.api.nvim_buf_is_valid(bufnr) then return end
  local rp = rel_path(bufnr, repo_root)
  if not rp then return end
  local locations = comments.all_locations(repo_root)
  signs.place(bufnr, locations, rp)
end

--- Load (or reload) PR comments for the given buffer.
--- Fetches from GitHub and refreshes signs in all open buffers of this repo.
---@param bufnr integer
---@param opts? {force: boolean}
-- Status per repo root: "loading" | "loaded:N" | "error:msg" | nil
local status = {}

--- Small helper: show a notification only if triggered by the user (not auto-load).
---@param msg string
---@param level integer
---@param user_initiated boolean
local function notify(msg, level, user_initiated)
  if user_initiated then
    vim.notify("[gitcomments] " .. msg, level)
  end
end

function M.load_comments(bufnr, opts)
  opts = opts or {}
  local user = opts.force == true -- force = user explicitly called the command

  get_repo_root(bufnr, function(root)
    if not root then return end

    -- Don't double-fetch unless forced
    if comments.has_cache(root) and not user then
      refresh_signs(bufnr, root)
      return
    end

    if loading[root] then return end
    loading[root] = true
    status[root] = "loading"

    github.get_current_branch(root, function(branch)
      if not branch or branch == "HEAD" then
        loading[root] = false
        status[root] = nil
        return
      end

      github.find_pr_for_branch(branch, function(pr_number, pr_err)
        if not pr_number then
          loading[root] = false
          status[root] = pr_err and ("error:" .. pr_err) or nil
          notify(pr_err or "No open PR found", vim.log.levels.INFO, user)
          return
        end

        notify(string.format("Loading comments for PR #%d…", pr_number), vim.log.levels.INFO, user)

        github.get_repo_info(root, function(repo_info, info_err)
          if not repo_info then
            loading[root] = false
            status[root] = "error:" .. (info_err or "unknown")
            notify(info_err or "Could not determine repo", vim.log.levels.ERROR, user)
            return
          end

          github.fetch_review_comments(pr_number, repo_info.owner, repo_info.name, function(raw_comments, fetch_err)
            loading[root] = false
            if not raw_comments then
              status[root] = "error:" .. (fetch_err or "unknown")
              notify("Failed to fetch PR comments: " .. (fetch_err or ""), vim.log.levels.ERROR, user)
              return
            end

            local ok, err = pcall(function()
              comments.store(root, raw_comments, config.options.resolved_threads)

              for _, b in ipairs(vim.api.nvim_list_bufs()) do
                if vim.api.nvim_buf_is_valid(b) and vim.api.nvim_buf_is_loaded(b) then
                  refresh_signs(b, root)
                end
              end
            end)

            if not ok then
              status[root] = "error:" .. tostring(err)
              notify("Error processing comments: " .. tostring(err), vim.log.levels.ERROR, user)
              return
            end

            local count = #comments.all_locations(root)
            status[root] = string.format("loaded:%d", count)
            notify(string.format("Loaded %d commented line(s) from PR #%d", count, pr_number), vim.log.levels.INFO, user)
          end)
        end)
      end)
    end)
  end)
end

--- Show the comment floating window for the cursor line in bufnr.
---@param bufnr integer
function M.show_comment(bufnr)
  get_repo_root(bufnr, function(root)
    if not root then
      vim.notify("[gitcomments] Not in a git repository", vim.log.levels.WARN)
      return
    end

    local rp = rel_path(bufnr, root)
    if not rp then return end

    local line = vim.api.nvim_win_get_cursor(0)[1]
    local threads = comments.get(root, rp, line)

    if not threads or #threads == 0 then
      -- If no cache yet, try loading first
      if not comments.has_cache(root) then
        M.load_comments(bufnr, { force = true })
        vim.notify("[gitcomments] Fetching PR comments, try again shortly", vim.log.levels.INFO)
      else
        vim.notify("[gitcomments] No PR comment on this line", vim.log.levels.INFO)
      end
      return
    end

    ui.show(threads)
  end)
end

--- Clear all signs and cached comments.
function M.clear(bufnr)
  get_repo_root(bufnr, function(root)
    if root then
      comments.clear(root)
    end
    signs.clear(bufnr)
    ui.close()
  end)
end

--- Plugin setup. Call this once with your config.
---@param user_config table|nil
function M.setup(user_config)
  config.setup(user_config)
  signs.define(config.options.sign_text, config.options.sign_hl)

  -- Set up keymap
  local km = config.options.keymap
  if km and km ~= "" then
    vim.keymap.set("n", km, function()
      M.show_comment(vim.api.nvim_get_current_buf())
    end, { desc = "Show PR comment at cursor", silent = true })
  end
end

return M
