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
function M.load_comments(bufnr, opts)
  opts = opts or {}

  get_repo_root(bufnr, function(root)
    local ok, err = pcall(function()
    if not root then return end

    -- Don't double-fetch unless forced
    if comments.has_cache(root) and not opts.force then
      refresh_signs(bufnr, root)
      return
    end

    if loading[root] then return end
    loading[root] = true

    github.get_current_branch(root, function(branch)
      local ok2, err2 = pcall(function()
      if not branch or branch == "HEAD" then
        loading[root] = false
        return
      end

      github.find_pr_for_branch(branch, function(pr_number, pr_err)
        local ok3, err3 = pcall(function()
        if not pr_number then
          loading[root] = false
          if pr_err then
            vim.notify("[gitcomments] " .. pr_err, vim.log.levels.INFO)
          end
          return
        end

        vim.notify(string.format("[gitcomments] Loading comments for PR #%d…", pr_number), vim.log.levels.INFO)

        github.get_repo_info(root, function(repo_info, info_err)
          local ok4, err4 = pcall(function()
          if not repo_info then
            loading[root] = false
            vim.notify("[gitcomments] " .. (info_err or "Could not determine repo"), vim.log.levels.ERROR)
            return
          end

          github.fetch_review_comments(pr_number, repo_info.owner, repo_info.name, function(raw_comments, fetch_err)
            local ok5, err5 = pcall(function()
            loading[root] = false
            if not raw_comments then
              vim.notify("[gitcomments] Failed to fetch PR comments: " .. (fetch_err or ""), vim.log.levels.ERROR)
              return
            end

            comments.store(root, raw_comments, config.options.resolved_threads)

            -- Refresh signs in all buffers belonging to this repo
            for _, b in ipairs(vim.api.nvim_list_bufs()) do
              if vim.api.nvim_buf_is_loaded(b) then
                refresh_signs(b, root)
              end
            end

            local count = #comments.all_locations(root)
            vim.notify(string.format("[gitcomments] Loaded %d commented line(s) from PR #%d", count, pr_number), vim.log.levels.INFO)
            end) if not ok5 then loading[root] = false; vim.notify("[gitcomments] ERROR (fetch): " .. tostring(err5), vim.log.levels.ERROR) end
          end)
          end) if not ok4 then loading[root] = false; vim.notify("[gitcomments] ERROR (repo_info): " .. tostring(err4), vim.log.levels.ERROR) end
        end)
        end) if not ok3 then loading[root] = false; vim.notify("[gitcomments] ERROR (pr): " .. tostring(err3), vim.log.levels.ERROR) end
      end)
      end) if not ok2 then loading[root] = false; vim.notify("[gitcomments] ERROR (branch): " .. tostring(err2), vim.log.levels.ERROR) end
    end)
    end) if not ok then vim.notify("[gitcomments] ERROR (root): " .. tostring(err), vim.log.levels.ERROR) end
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
        M.load_comments(bufnr, {})
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
