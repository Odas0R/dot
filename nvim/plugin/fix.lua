vim.api.nvim_create_user_command("Fix", function(opts)
  -- if the current buffer is a typescript file
  if vim.bo.filetype == "typescript" or vim.bo.filetype == "typescriptreact" then
    vim.cmd([[
    TypescriptRemoveUnused
    TypescriptOrganizeImports
    TypescriptFixAll
    EslintFixAll
  ]])
  end
end, {
  desc = "Fix the current buffer",
})
