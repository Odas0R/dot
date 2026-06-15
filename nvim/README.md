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
│   ├── lsp/                         # shared LSP wiring
│   │   ├── attach.lua               # LspAttach keymaps and per-client hooks
│   │   ├── capabilities.lua         # shared client capabilities
│   │   ├── patches.lua              # small LSP compatibility patches
│   │   └── servers.lua              # enabled LSP server list
│   ├── features/                    # custom/local Neovim features
│   │   ├── init.lua
│   │   ├── pi_review.lua
│   │   ├── checkbox.lua
│   │   ├── exec.lua
│   │   ├── refactor.lua
│   │   ├── replace.lua
│   │   └── terminal/
│   ├── lib/                         # reusable helpers by domain
│   │   ├── git.lua
│   │   ├── loclist.lua
│   │   ├── path.lua
│   │   ├── text.lua
│   │   ├── util.lua
│   │   └── window.lua
│   └── snippets/
├── after/
│   ├── lsp/                         # per-server native LSP overrides
│   └── queries/
```

## LSP configs

This config uses the modern Neovim LSP API:

- Shared setup lives in `lua/odas0r/lsp/`.
- Enabled servers are listed in `lua/odas0r/lsp/servers.lua`.
- Server-specific overrides live in `after/lsp/<server>.lua`.
- `neovim/nvim-lspconfig` supplies default server definitions; our files only override what we need.

To add a new LSP server:

1. Install the language server executable and make sure it is on `$PATH`.
2. Add the server name to `lua/odas0r/lsp/servers.lua`:

   ```lua
   return {
     "lua_ls",
     "gopls",
     "new_server_name",
   }
   ```

3. If the default `nvim-lspconfig` config is enough, stop there.
4. If you need custom settings, create `after/lsp/new_server_name.lua`:

   ```lua
   return {
     settings = {
       newServerName = {
         -- server-specific settings
       },
     },
   }
   ```

5. Restart Neovim and run `:checkhealth vim.lsp` or `:LspInfo` to verify it attaches.

Use `:help lspconfig-all` to find the exact server name, install command, default filetypes, root markers, and supported settings.

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
