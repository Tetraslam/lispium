; Treat (define ...) forms as functions for maf/mif and ]f/[f navigation
((list . (symbol) @_head) @function.around
  (#eq? @_head "define"))
((list . (symbol) @_head) @function.inside
  (#eq? @_head "define"))

; Lambdas too
((list . (symbol) @_head) @function.around
  (#eq? @_head "lambda"))

(comment) @comment.inside
(comment)+ @comment.around

; Every list element is a "parameter" for mip/]a style hops
(list (_) @parameter.inside)
