local parsers = {
  "astro",
  "bash",
  "css",
  "diff",
  "dockerfile",
  "git_config",
  "git_rebase",
  "gitattributes",
  "gitcommit",
  "gitignore",
  "html",
  "javascript",
  "jsdoc",
  "json",
  "lua",
  "luadoc",
  "markdown",
  "markdown_inline",
  "query",
  "regex",
  "sql",
  "toml",
  "tsx",
  "typescript",
  "vim",
  "vimdoc",
  "yaml",
}

local disabled_filetypes = {
  dockerfile = true,
}

local function should_start(buf, lang)
  if disabled_filetypes[lang] then
    return false
  end

  local name = vim.api.nvim_buf_get_name(buf)
  local ok, stats = pcall(vim.uv.fs_stat, name)
  if ok and stats and stats.size > 100 * 1024 then
    return false
  end

  return vim.api.nvim_buf_line_count(buf) <= 10000
end

local function start_treesitter(args)
  local buf = args.buf
  local lang = vim.treesitter.language.get_lang(vim.bo[buf].filetype)
  if not lang or not should_start(buf, lang) then
    return
  end

  if pcall(vim.treesitter.start, buf, lang) then
    vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
  end
end

return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  lazy = false,
  build = function()
    require("nvim-treesitter").install(parsers):wait(300000)
  end,
  config = function()
    local ok, treesitter = pcall(require, "nvim-treesitter")
    if not ok then
      return
    end

    treesitter.setup({
      install_dir = vim.fn.stdpath("data") .. "/site",
    })

    vim.api.nvim_create_autocmd("FileType", {
      group = vim.api.nvim_create_augroup(
        "odas0r_treesitter",
        { clear = true }
      ),
      callback = start_treesitter,
    })
  end,
}
