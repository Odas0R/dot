local M = {}

function M.setup()
  -- Astro's language server sometimes returns versioned edits computed from
  -- a stale virtual TypeScript document. Neovim refuses those edits with:
  -- "Buffer <uri> newer than edits." Keep the version guard everywhere else,
  -- but treat Astro edits as unversioned so auto-import code actions can apply.
  if vim.g.astro_stale_workspace_edit_patch then
    return
  end

  vim.g.astro_stale_workspace_edit_patch = true

  local util = vim.lsp.util
  local apply_text_document_edit = util.apply_text_document_edit

  util.apply_text_document_edit = function(
    text_document_edit,
    index,
    position_encoding,
    change_annotations
  )
    local text_document = text_document_edit.textDocument

    if
      text_document
      and text_document.uri
      and text_document.version ~= vim.NIL
    then
      local version = text_document.version
      local bufnr = vim.uri_to_bufnr(text_document.uri)
      local current_version = util.buf_versions[bufnr]

      if
        type(version) == "number"
        and version > 0
        and current_version
        and current_version > version
        and vim.bo[bufnr].filetype == "astro"
      then
        text_document_edit = vim.deepcopy(text_document_edit)
        text_document_edit.textDocument.version = vim.NIL
      end
    end

    return apply_text_document_edit(
      text_document_edit,
      index,
      position_encoding,
      change_annotations
    )
  end
end

return M
