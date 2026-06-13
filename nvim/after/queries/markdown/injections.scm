; @Source: https://phelipetls.github.io/posts/mdx-syntax-highlight-treesitter-nvim/
;
; extends

; MDX-style top-level ESM lines in markdown.
((inline) @injection.content
  (#match? @injection.content "^(import|export)")
  (#set! injection.language "tsx"))
