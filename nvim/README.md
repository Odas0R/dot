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
- `<leader>pr` / `:PiReviewOpen` opens `.pi/review.md`.
- In Diffview, `<leader>c` / `:PiReviewComment` appends a normal or visual-range review comment to `.pi/review.md`.
- From Pi, `/review-diff` opens Diffview in a kitty overlay pane, `/review-apply` sends unchecked review comments back to Pi, and `/review-clean` clears the review file.

## References

- lazy.nvim structuring: https://lazy.folke.io/usage/structuring
- LazyVim config layout: https://www.lazyvim.org/configuration
- LazyVim starter: https://github.com/LazyVim/starter
- Kickstart.nvim: https://github.com/nvim-lua/kickstart.nvim
- `:help lua-guide`
