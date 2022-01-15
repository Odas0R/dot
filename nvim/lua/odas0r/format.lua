local home = os.getenv("HOME")
require("format").setup({
  ["*"] = {
    { cmd = { "sed -i 's/[ \t]*$//'" }, tmpfile_dir = "/tmp/" }, -- remove trailing whitespace
  },
  vim = {
    {
      cmd = { "stylua --indent-type Spaces --indent-width 2" },
      start_pattern = "^lua << EOF$",
      end_pattern = "^EOF$",
    },
  },
  lua = {
    {
      cmd = { "stylua --indent-type Spaces --indent-width 2" },
    },
  },
  java = {
    { cmd = { "javafmt --skip-javadoc-formatting -r" }, tmpfile_dir = "/tmp/" },
  },
  go = {
    {
      cmd = { "gofmt -w", "goimports -w" },
      tempfile_postfix = ".tmp",
    },
  },
  sh = {
    { cmd = { "shfmt -i 2 -w" } },
  },
  python = {
    { cmd = { "autopep8 -i" } },
  },
  javascript = {
    { cmd = { "prettier -w", "eslint_d --cache --cache-location /tmp/ --fix" } },
  },
  javascriptreact = {
    { cmd = { "prettier -w", "eslint_d --cache --cache-location /tmp/ --fix" } },
  },
  typescript = {
    { cmd = { "prettier -w", "eslint_d --cache --cache-location /tmp/ --fix" } },
  },
  typescriptreact = {
    { cmd = { "prettier -w", "eslint_d --cache --cache-location /tmp/ --fix" } },
  },
  json = {
    { cmd = { "fixjson -w", "prettier -w" } },
  },
  jsonc = {
    { cmd = { "fixjson -w", "prettier -w" } },
  },
  html = {
    { cmd = { "prettier -w" } },
  },
  css = {
    { cmd = { "prettier -w", "stylelint --fix" } },
  },
  scss = {
    { cmd = { "prettier -w", "stylelint --fix" } },
  },
  markdown = {
    {
      { cmd = { "shfmt -i 2 -w" } },
      start_pattern = "^```bash$",
      end_pattern = "^```$",
      target = "current",
    },
  },
})
