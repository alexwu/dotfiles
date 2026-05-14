; Override of helix's just/injections.scm for use with tree-sitter CLI.
; Identical to helix's queries/just/injections.scm except the final
; rule, which uses helix-only `@injection.shebang` predicate that
; tree-sitter CLI silently ignores. We replace it with a standard
; `@injection.language` capture against the (shebang_shell) node so
; bash code below the shebang gets highlighted in tree-sitter CLI.

; ================ Always applicable ================

((comment) @injection.content
  (#set! injection.language "comment"))

((regex
  (_) @injection.content)
  (#set! injection.language "regex"))

; ================ Global defaults ================

(recipe_body
  !shebang
  (#set! injection.language "bash")
  (#set! injection.include-children)) @injection.content

(external_command
  (content) @injection.content
  (#set! injection.language "bash"))

; ================ Global shell setting ================

(file
  (setting "shell" ":=" "[" (string) @_langstr
    (#match? @_langstr ".*(powershell|pwsh|cmd).*")
    (#set! injection.language "powershell"))
  [
    (recipe
      (recipe_body
        !shebang
        (#set! injection.include-children)) @injection.content)

    (assignment
      (expression
        (value
          (external_command
            (content) @injection.content))))
  ])

(file
  (setting "shell" ":=" "[" (string) @injection.language
    (#not-match? @injection.language ".*(powershell|pwsh|cmd).*"))
  [
    (recipe
      (recipe_body
        !shebang
        (#set! injection.include-children)) @injection.content)

    (assignment
      (expression
        (value
          (external_command
            (content) @injection.content))))
  ])

; ================ Recipe shebang ================
; Replaces helix's `@injection.shebang` rule. The `(shebang_shell)` node
; carries the language name (e.g. "bash" from `#!/usr/bin/env bash`).
(recipe_body
  (shebang_line (shebang_shell) @injection.language)
  (#set! injection.include-children)) @injection.content
