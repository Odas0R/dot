; extends

; css`...`
(call_expression
 function: ((identifier) @_name (#eq? @_name "css"))
 arguments: ((template_string) @scss
   (#offset! @scss 0 1 0 -1))
)

; Handle member access like foo.html`...` or foo.html(`...`)
(call_expression
  function: (member_expression
    property: (property_identifier) @_html_prop ; Capture the property identifier
    (#eq? @_html_prop "html"))                 ; Check if the property name is "html"
  arguments: [                                 ; Match either arguments(...) or template_string
    (arguments                                 ; Case 1: foo.html(...)
      (template_string) @injection.content)
    (template_string) @injection.content       ; Case 2: foo.html`...`
  ]
  (#offset! @injection.content 0 1 0 -1)        ; Remove backticks ` and `
  (#set! injection.include-children)            ; Include interpolated parts ${...}
  (#set! injection.language "html"))            ; Set the injected language to HTML
