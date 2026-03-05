# gitcomments.nvim

A Neovim plugin that surfaces **GitHub Pull Request review comments** directly in your editor — floating windows on the commented lines, just like VS Code.

![Neovim PR comment floating window](https://via.placeholder.com/600x200.png?text=floating+comment+window+screenshot)

---

## Requirements

| Dependency | Version |
|---|---|
| Neovim | ≥ 0.8 (uses `vim.system`) |
| [GitHub CLI (`gh`)](https://cli.github.com/) | any recent version, authenticated |
| Git | any |

Make sure you are authenticated with `gh`:
```sh
gh auth login
```

---

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)
```lua
{
  "tatsma/neovim-gitcomments",
  event = "BufReadPost",
  config = function()
    require("gitcomments").setup()
  end,
}
```

### [packer.nvim](https://github.com/wbthomason/packer.nvim)
```lua
use {
  "tatsma/neovim-gitcomments",
  config = function()
    require("gitcomments").setup()
  end,
}
```

---

## Quick Start

1. Open a file in a repository that has an **open Pull Request** on GitHub.
2. Comments are fetched automatically and a `💬` sign appears in the sign column.
3. Move your cursor to a signed line and press `<leader>gc` (or run `:GitComments`).
4. A floating window pops up with the full PR review thread.

---

## Configuration

Call `setup()` with any options you want to override. All fields are optional.

```lua
require("gitcomments").setup({
  -- Automatically fetch PR comments when opening a buffer (default: true)
  auto_load = true,

  -- Keymap to show the comment at the cursor line (default: "<leader>gc")
  -- Set to "" to disable
  keymap = "<leader>gc",

  -- Text shown in the sign column for lines with comments (default: "💬")
  sign_text = "💬",

  -- Highlight group for the sign column marker (default: links to DiagnosticInfo)
  sign_hl = "GitCommentsSign",

  -- Maximum width of the floating comment window (default: 80)
  max_comment_width = 80,

  -- Maximum height of the floating comment window (default: 20)
  max_comment_height = 20,

  -- Whether to show resolved review threads (default: false)
  resolved_threads = false,
})
```

### Custom highlight groups

Override these after calling `setup()`:

```lua
vim.api.nvim_set_hl(0, "GitCommentsSign",        { fg = "#61afef" })
vim.api.nvim_set_hl(0, "GitCommentsFloat",        { bg = "#282c34" })
vim.api.nvim_set_hl(0, "GitCommentsFloatBorder",  { fg = "#61afef" })
```

---

## Commands

| Command | Description |
|---|---|
| `:GitComments` | Show the PR comment thread at the cursor line |
| `:GitCommentsLoad` | (Re)fetch PR comments for the current repository |
| `:GitCommentsClear` | Remove all comment signs and clear the cache |

---

## How It Works

1. On `BufReadPost`, the plugin detects the git repo root and current branch.
2. `gh pr list --head <branch>` finds the open PR number.
3. `gh pr view <number> --json reviewThreads` fetches all review threads.
4. Threads are indexed by `file:line` and signs are placed in the sign column.
5. Pressing `<leader>gc` opens a floating window rendered as Markdown.
6. The window auto-closes when the cursor moves.

All `gh` calls are **asynchronous** — your editor never blocks.

---

## FAQ

**Q: My PR comments aren't loading.**  
A: Run `:GitCommentsLoad` and check that `gh pr list --head <your-branch>` returns your PR in a terminal.

**Q: Can I use this with GitLab or Bitbucket?**  
A: Not yet — only GitHub via `gh` CLI is supported.

**Q: Comments load but no signs appear.**  
A: The plugin matches by the file path stored in the PR review thread. Make sure the file you have open is the same path that was reviewed (relative to the repository root).

---

## License

MIT
