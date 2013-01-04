attrs.coffee :
- attributes
  - should support multi-line attrs w/ odd formatting
  - should support shorthands for checkboxes
  - should support expressions in attrs
  - should ignore special chars in keys
  - should ignore special chars in values
  - should support single quoted values
  - should escape attrs
  - should support keys with double quotes
  - should support keys with single quotes
  - should support attrs that contain attr separators
  - should allow ugly spacing
  - should support standard attrs

utils.coffee:
- utils.match_delimiters()
  - should handle matching brackets

- merge(a, b, escaped)
  - should merge classes into strings

lexer.coffee:
- Lexer.attrs()
  - should recognize text attrs
  - should recognize boolean attrs
  - should recognize data attrs

- Lexer
  - should tokenize shorthand ids
  - should tokenize shorthand classes
