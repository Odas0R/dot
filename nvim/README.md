# Neovim config

This config uses a namespaced `lazy.nvim` architecture inspired by current lazy.nvim/LazyVim conventions, but without adopting a full distribution.

## Layout

```text
nvim/
├── init.lua                         # tiny entrypoint
├── lua/odas0r/
│   ├── config/                      # core editor config
│   │   ├── init.lua
│   │   ├── lazy.lua                 # lazy.nvim bootstrap + imports
│   │   ├── options.lua
│   │   ├── autocmds.lua
│   │   ├── keymaps.lua
│   │   └── commands.lua
│   ├── plugins/                     # lazy.nvim plugin specs by domain
│   │   ├── init.lua                 # imports plugin domains
│   │   ├── colorscheme/
│   │   ├── completion/
│   │   ├── lsp/
│   │   ├── treesitter/
│   │   ├── coding/
│   │   ├── editor/
│   │   ├── formatting/
│   │   ├── git/
│   │   ├── search/
│   │   └── ui/
│   ├── features/                    # custom/local Neovim features
│   │   ├── init.lua
│   │   ├── pi_review.lua
│   │   ├── checkbox.lua
│   │   ├── exec.lua
│   │   ├── refactor.lua
│   │   ├── replace.lua
│   │   └── terminal/
│   ├── lib/                         # reusable helpers
│   │   └── util.lua
│   └── snippets/
└── after/queries/
```

## Review workflow

- `<leader>dr` opens `diffview-plus.nvim` for working-tree review.
- `<leader>dR` reviews `origin/main...HEAD`.
- From Pi, `/review-diff` opens Diffview in a kitty overlay pane with a live review bridge.
- In a Pi review Diffview session, `<leader>c` / `:PiReviewComment` adds a pending line or visual-range review comment.
- In a Pi review Diffview session, `<leader>C` / `:PiReviewFileComment` adds a pending whole-file review comment.
- `<leader>l` toggles pending comments in the location list (`:PiReviewList` opens it; `Enter` edits, `d` clears one or a visual selection, `q` closes), and `:PiSubmitReview` writes all pending comments into the Pi input for review, then closes the review overlay.

## References

- lazy.nvim structuring: https://lazy.folke.io/usage/structuring
- LazyVim config layout: https://www.lazyvim.org/configuration
- LazyVim starter: https://github.com/LazyVim/starter
- Kickstart.nvim: https://github.com/nvim-lua/kickstart.nvim
- `:help lua-guide`
