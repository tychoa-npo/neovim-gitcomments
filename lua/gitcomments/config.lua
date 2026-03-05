local M = {}

---@class GitCommentsConfig
---@field auto_load boolean Automatically load comments when entering a buffer
---@field keymap string Keymap to show comment at cursor line
---@field sign_text string Text shown in sign column for commented lines
---@field sign_hl string Highlight group for the sign
---@field max_comment_width integer Max width of the floating comment window
---@field max_comment_height integer Max height of the floating comment window
---@field resolved_threads boolean Whether to show resolved review threads

local defaults = {
  auto_load = false,
  keymap = "<leader>gc",
  sign_text = ">>",
  sign_hl = "GitCommentsSign",
  max_comment_width = 80,
  max_comment_height = 20,
  resolved_threads = false,
}

---@type GitCommentsConfig
M.options = {}

---Merge user config with defaults.
---@param user_config table|nil
function M.setup(user_config)
  M.options = vim.tbl_deep_extend("force", {}, defaults, user_config or {})
end

return M
