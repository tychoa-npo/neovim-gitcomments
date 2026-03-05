local M = {}

-- Cache: repo_root -> { ["rel/path:line"] -> thread[] }
local cache = {}

--- Build a lookup key from a relative file path and line number.
---@param rel_path string
---@param line integer
---@return string
local function key(rel_path, line)
  return rel_path .. ":" .. tostring(line)
end

--- Store parsed review comments for a repo root.
--- Accepts the flat list returned by the REST API and groups them into
--- threads by (path, line), linking replies via in_reply_to_id.
---@param repo_root string
---@param raw_comments table[] Flat comment objects from the REST API
---@param include_resolved boolean (unused for REST API — resolved state not available)
function M.store(repo_root, raw_comments, _include_resolved)
  -- Index all comments by id so we can resolve reply chains
  local by_id = {}
  for _, c in ipairs(raw_comments) do
    by_id[c.id] = c
  end

  local store = {}

  for _, c in ipairs(raw_comments) do
    -- Walk up the reply chain to find the root (top-level) comment
    local root = c
    local visited = {}
    while root.in_reply_to_id and by_id[root.in_reply_to_id] and not visited[root.id] do
      visited[root.id] = true
      root = by_id[root.in_reply_to_id]
    end

    local line = root.line or root.original_line
    if root.path and line then
      local k = key(root.path, line)
      if not store[k] then
        store[k] = {
          path = root.path,
          line = line,
          isResolved = false,
          comments = {},
          _seen = {},
        }
      end
      if not store[k]._seen[c.id] then
        store[k]._seen[c.id] = true
        table.insert(store[k].comments, {
          author = { login = (c.user and c.user.login) or "unknown" },
          body = c.body or "",
          createdAt = c.created_at or "",
        })
      end
    end
  end

  -- Sort each thread's comments chronologically and drop helper field
  local final = {}
  for k, thread in pairs(store) do
    table.sort(thread.comments, function(a, b)
      return (a.createdAt or "") < (b.createdAt or "")
    end)
    thread._seen = nil
    final[k] = thread
  end

  cache[repo_root] = final
end

--- Clear cached comments for a repo root.
---@param repo_root string
function M.clear(repo_root)
  cache[repo_root] = nil
end

--- Get threads for a specific file line.
---@param repo_root string
---@param rel_path string Path relative to repo root
---@param line integer 1-based line number
---@return table[]|nil  Array with one thread, or nil if no comment on that line
function M.get(repo_root, rel_path, line)
  local store = cache[repo_root]
  if not store then return nil end
  local thread = store[key(rel_path, line)]
  if not thread then return nil end
  return { thread }
end

--- Return all (rel_path, line) pairs that have comments for the given repo root.
---@param repo_root string
---@return {path: string, line: integer}[]
function M.all_locations(repo_root)
  local store = cache[repo_root]
  if not store then return {} end
  local result = {}
  for k, _ in pairs(store) do
    local path, line = k:match("^(.+):(%d+)$")
    if path and line then
      table.insert(result, { path = path, line = tonumber(line) })
    end
  end
  return result
end

--- Return true if there is cached data for this repo root.
---@param repo_root string
---@return boolean
function M.has_cache(repo_root)
  return cache[repo_root] ~= nil
end

return M
