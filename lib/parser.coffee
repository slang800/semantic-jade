"use strict"
Lexer = require './lexer'
nodes = require './nodes'
utils = require './utils'
filters = require './filters'
path = require 'path'
constantinople = require 'constantinople'
parseJSExpression = require('character-parser').parseMax

###*
 * Parser prototype.
###
class Parser
  ###*
   * Initialize `Parser` with the given input `str` and `filename`.
   * @param {String} str
   * @param {String} filename
   * @param {Object} options
   * @api public
  ###
  constructor: (str, filename, options) ->
    #Strip any UTF-8 BOM off of the start of `str`, if it exists.
    @input = str.replace(/^\uFEFF/, '')
    @lexer = new Lexer(@input, filename)
    @filename = filename
    @blocks = {}
    @mixins = {}
    @options = options
    @contexts = [this]
    @inMixin = false
    @dependencies = []
    return

  ###*
   * Push `parser` onto the context stack, or pop and return a `Parser`.
  ###
  context: (parser) ->
    if parser
      @contexts.push parser
    else
      return @contexts.pop()
    return

  ###*
   * Return the next token object.
   * @return {Object}
   * @api private
  ###
  advance: ->
    @lexer.advance()

  ###*
   * Single token lookahead.
   * @return {Object}
   * @api private
  ###
  peek: ->
    @lookahead 1

  ###
   * Return lexer lineno.
   * @return {Number}
   * @api private
  ###
  line: ->
    @lexer.lineno

  ###*
   * `n` token lookahead.
   * @param {Number} n
   * @return {Object}
   * @api private
  ###
  lookahead: (n) ->
    @lexer.lookahead n

  ###*
   * Parse input returning a string of js for evaluation.
   * @return {String}
   * @api public
  ###
  parse: ->
    block = new nodes.Block
    parser = undefined
    block.line = 0
    block.filename = @filename
    until @peek().type is 'eos'
      if @peek().type is 'newline'
        @advance()
      else
        next = @peek()
        expr = @parseExpr()
        expr.filename = expr.filename or @filename
        expr.line = next.line
        block.push expr
    if parser = @extending
      @context parser
      ast = parser.parse()
      @context()

      # hoist mixins
      for name of @mixins
        ast.unshift(@mixins[name])
      return ast
    if not @extending and not @included and Object.keys(@blocks).length
      blocks = []
      utils.walkAST block, (node) ->
        blocks.push node.name if node.type is 'Block' and node.name
        return

      Object.keys(@blocks).forEach ((name) =>
        if blocks.indexOf(name) is -1
          console.warn "Warning: Unexpected block \"#{name}\" on line #{@blocks[name].line} of #{@blocks[name].filename}. This block is never used. This warning will be an error in v2.0.0"
        return
      )
    block

  ###*
   * Expect the given type, or throw an exception.
   * @param {String} type
   * @api private
  ###
  expect: (type) ->
    if @peek().type is type
      return @advance()
    else
      throw new Error("expected \"#{type}\", but got \"#{@peek().type}\"")

  ###*
   * Accept the given `type`.
   * @param {String} type
   * @api private
  ###
  accept: (type) ->
    @advance() if @peek().type is type

  ###*
   * tag
   * | doctype
   * | mixin
   * | include
   * | filter
   * | comment
   * | text
   * | each
   * | code
   * | yield
   * | id
   * | class
   * | interpolation
  ###
  parseExpr: ->
    switch @peek().type
      when 'tag'
        return @parseTag()
      when 'mixin'
        return @parseMixin()
      when 'block'
        return @parseBlock()
      when 'mixin-block'
        return @parseMixinBlock()
      when 'case'
        return @parseCase()
      when 'extends'
        return @parseExtends()
      when 'include'
        return @parseInclude()
      when 'doctype'
        return @parseDoctype()
      when 'filter'
        return @parseFilter()
      when 'comment'
        return @parseComment()
      when 'text'
        return @parseText()
      when 'each'
        return @parseEach()
      when 'code'
        return @parseCode()
      when 'call'
        return @parseCall()
      when 'interpolation'
        return @parseInterpolation()
      when 'yield'
        @advance()
        block = new nodes.Block
        block.yield = true
        block
      when 'id', 'class'
        tok = @advance()
        @lexer.defer @lexer.tok('tag', 'div')
        @lexer.defer tok
        @parseExpr()
      else
        throw new Error("unexpected token \"#{@peek().type}\"")

  ###*
   * Text
  ###
  parseText: ->
    tok = @expect 'text'
    tokens = @parseInlineTagsInText(tok.val)
    return tokens[0] if tokens.length is 1
    node = new nodes.Block
    for i in [0...tokens.length]
      node.push tokens[i]
    node

  ###*
   * ':' expr
   * | block
  ###
  parseBlockExpansion: ->
    if @peek().type is ':'
      @advance()
      new nodes.Block(@parseExpr())
    else
      @block()

  ###*
   * case
  ###
  parseCase: ->
    val = @expect('case').val
    node = new nodes.Case(val)
    node.line = @line()
    block = new nodes.Block
    block.line = @line()
    block.filename = @filename
    @expect 'indent'
    until @peek().type is 'outdent'
      switch @peek().type
        when 'newline'
          @advance()
        when 'when'
          block.push @parseWhen()
        when 'default'
          block.push @parseDefault()
        else
          throw new Error("""
            Unexpected token "#{@peek().type}", expected "when", "default" or "newline"
          """)
    @expect 'outdent'
    node.block = block
    node

  ###*
   * when
  ###
  parseWhen: ->
    val = @expect('when').val
    if @peek().type isnt 'newline'
      new nodes.Case.When(val, @parseBlockExpansion())
    else
      new nodes.Case.When(val)

  ###*
   * default
  ###
  parseDefault: ->
    @expect 'default'
    new nodes.Case.When('default', @parseBlockExpansion())

  ###*
   * code
  ###
  parseCode: (afterIf) ->
    tok = @expect 'code'
    node = new nodes.Code(tok.val, tok.buffer, tok.escape)
    block = undefined
    node.line = @line()

    # throw an error if an else does not have an if
    if tok.isElse and not tok.hasIf
      throw new Error('Unexpected else without if')

    # handle block
    block = @peek().type is 'indent'
    node.block = @block() if block

    # handle missing block
    if tok.requiresBlock and not block
      node.block = new nodes.Block()

    # mark presense of if for future elses
    if tok.isIf and @peek().isElse
      @peek().hasIf = true
    else if tok.isIf and @peek().type is 'newline' and @lookahead(2).isElse
        @lookahead(2).hasIf = true
    node

  ###*
   * comment
  ###
  parseComment: ->
    tok = @expect 'comment'
    node = undefined
    block = undefined
    if block = @parseTextBlock()
      node = new nodes.BlockComment(tok.val, block, tok.buffer)
    else
      node = new nodes.Comment(tok.val, tok.buffer)
    node.line = @line()
    node

  ###*
   * doctype
  ###
  parseDoctype: ->
    tok = @expect 'doctype'
    node = new nodes.Doctype(tok.val)
    node.line = @line()
    node

  ###*
   * filter attrs? text-block
  ###
  parseFilter: ->
    tok = @expect 'filter'
    attrs = @accept 'attrs'
    block = undefined
    block = @parseTextBlock() or new nodes.Block()
    options = {}
    if attrs
      attrs.attrs.forEach (attribute) ->
        options[attribute.name] = constantinople.toConstant(attribute.val)
        return

    node = new nodes.Filter(tok.val, block, options)
    node.line = @line()
    node

  ###*
   * each block
  ###
  parseEach: ->
    tok = @expect 'each'
    node = new nodes.Each(tok.code, tok.val, tok.key)
    node.line = @line()
    node.block = @block()
    if @peek().type is 'code' and @peek().val is 'else'
      @advance()
      node.alternative = @block()
    node

  ###*
   * Resolves a path relative to the template for use in includes and extends
   * @param {String}  path
   * @param {String}  purpose  Used in error messages.
   * @return {String}
   * @api private
  ###
  resolvePath: (path, purpose) ->
    p = require 'path'
    dirname = p.dirname
    basename = p.basename
    join = p.join
    if path[0] isnt '/' and not @filename
      throw new Error("""
        the "filename" option is required to use "#{purpose}" with "relative" paths
      """)
    if path[0] is '/' and not @options.basedir
      throw new Error("""
        the "basedir" option is required to use "#{purpose}" with "absolute" paths
      """)
    path = join(
      (if path[0] is '/' then @options.basedir else dirname(@filename))
      path
    )
    path += '.jade' if basename(path).indexOf('.') is -1
    path

  ###*
   * 'extends' name
  ###
  parseExtends: ->
    fs = require('fs')
    path = @resolvePath(@expect('extends').val.trim(), 'extends')
    path += '.jade'  unless '.jade' is path.substr(-5)
    @dependencies.push path
    str = fs.readFileSync(path, 'utf8')
    parser = new Parser(str, path, @options)
    parser.dependencies = @dependencies
    parser.blocks = @blocks
    parser.contexts = @contexts
    @extending = parser

    # TODO: null node
    new nodes.Literal('')

  ###*
   * 'block' name block
  ###
  parseBlock: ->
    block = @expect 'block'
    mode = block.mode
    name = block.val.trim()
    block = (
      if @peek().type is 'indent'
        @block()
      else
        new nodes.Block(new nodes.Literal(''))
    )
    block.name = name
    prev = @blocks[name] or
      prepended: []
      appended: []

    if prev.mode is 'replace'
      return @blocks[name] = prev
    allNodes = prev.prepended.concat(block.nodes).concat(prev.appended)
    switch mode
      when 'append'
        prev.appended = (
          if prev.parser is this
            prev.appended.concat(block.nodes)
          else
            block.nodes.concat(prev.appended)
        )
      when 'prepend'
        prev.prepended = (
          if prev.parser is this
            block.nodes.concat(prev.prepended)
          else
            prev.prepended.concat(block.nodes)
        )
    block.nodes = allNodes
    block.appended = prev.appended
    block.prepended = prev.prepended
    block.mode = mode
    block.parser = this
    @blocks[name] = block

  parseMixinBlock: ->
    block = @expect('mixin-block')
    unless @inMixin
      throw new Error(
        'Anonymous blocks are not allowed unless they are part of a mixin.'
      )
    new nodes.MixinBlock()

  ###*
   * include block?
  ###
  parseInclude: ->
    fs = require 'fs'
    tok = @expect 'include'
    path = @resolvePath(tok.val.trim(), 'include')
    @dependencies.push path

    # has-filter
    if tok.filter
      str = fs.readFileSync(path, 'utf8').replace(/\r/g, '')
      options = filename: path
      if tok.attrs
        tok.attrs.attrs.forEach (attribute) ->
          options[attribute.name] = constantinople.toConstant(attribute.val)
          return

      str = filters(tok.filter, str, options)
      return new nodes.Literal(str)

    # non-jade
    unless '.jade' is path.substr(-5)
      str = fs.readFileSync(path, 'utf8').replace(/\r/g, '')
      return new nodes.Literal(str)
    str = fs.readFileSync(path, 'utf8')
    parser = new Parser(str, path, @options)
    parser.dependencies = @dependencies
    parser.blocks = utils.merge({}, @blocks)
    parser.included = true
    parser.mixins = @mixins
    @context parser
    ast = parser.parse()
    @context()
    ast.filename = path
    if @peek().type is 'indent' then ast.includeBlock().push @block()
    ast

  ###*
   * call ident block
  ###
  parseCall: ->
    tok = @expect 'call'
    name = tok.val
    args = tok.args
    mixin = new nodes.Mixin(name, args, new nodes.Block, true)
    @tag mixin
    if mixin.code
      mixin.block.push mixin.code
      mixin.code = null
    mixin.block = null if mixin.block.isEmpty()
    mixin

  ###*
   * mixin block
  ###
  parseMixin: ->
    tok = @expect 'mixin'
    name = tok.val
    args = tok.args
    mixin = undefined

    # definition
    if @peek().type is 'indent'
      @inMixin = true
      mixin = new nodes.Mixin(name, args, @block(), false)
      @mixins[name] = mixin
      @inMixin = false
      return mixin

    # call
    else
      return new nodes.Mixin(name, args, null, true)

  parseInlineTagsInText: (str) ->
    line = @line()
    match = /(\\)?#\[((?:.|\n)*)$/.exec(str)
    if match
      if match[1] # escape
        text = new nodes.Text(str.substr(0, match.index) + '#[')
        text.line = line
        rest = @parseInlineTagsInText(match[2])
        if rest[0].type is 'Text'
          text.val += rest[0].val
          rest.shift()
        [text].concat rest
      else
        text = new nodes.Text(str.substr(0, match.index))
        text.line = line
        buffer = [text]
        rest = match[2]
        range = parseJSExpression(rest)
        inner = new Parser(range.src, @filename, @options)
        buffer.push inner.parse()
        buffer.concat @parseInlineTagsInText(rest.substr(range.end + 1))
    else
      text = new nodes.Text(str)
      text.line = line
      [text]

  ###*
   * indent (text | newline)* outdent
  ###
  parseTextBlock: ->
    block = new nodes.Block
    block.line = @line()
    body = @peek()
    return if body.type isnt 'pipeless-text'
    @advance()
    block.nodes = body.val.reduce(((accumulator, text) =>
      accumulator.concat @parseInlineTagsInText(text)
    ), [])
    block

  ###*
   * indent expr* outdent
  ###
  block: ->
    block = new nodes.Block
    block.line = @line()
    block.filename = @filename
    @expect 'indent'
    until @peek().type is 'outdent'
      if @peek().type is 'newline'
        @advance()
      else
        expr = @parseExpr()
        expr.filename = @filename
        block.push expr
    @expect 'outdent'
    block

  ###*
   * interpolation (attrs | class | id)* (text | code | ':')? newline* block?
  ###
  parseInterpolation: ->
    tok = @advance()
    tag = new nodes.Tag(tok.val)
    tag.buffer = true
    @tag tag

  ###*
   * tag (attrs | class | id)* (text | code | ':')? newline* block?
  ###
  parseTag: ->
    tok = @advance()
    tag = new nodes.Tag(tok.val)
    tag.selfClosing = tok.selfClosing
    @tag tag

  tag: (tag) ->
    tag.line = @line()

    seenAttrs = false
    breakOut = false
    until breakOut
      switch @peek().type
        when 'class', 'id'
          tok = @advance();
          tag.setAttribute(tok.type, "'#{tok.val}'")
        when 'attrs'
          if seenAttrs
            console.warn("""
              #{@filename}, line #{@peek().line}:
              You should not have jade tags with multiple attributes.
            """)
          seenAttrs = true
          tok = @advance()
          attrs = tok.attrs
          if tok.selfClosing then tag.selfClosing = true
          for i in [0...attrs.length]
            tag.setAttribute attrs[i].name, attrs[i].val, attrs[i].escaped
        when '&attributes'
          tok = @advance()
          tag.addAttributes(tok.val)
        else
          breakOut = true

    # check immediate '.'
    if @peek().type is 'dot'
      tag.textOnly = true
      @advance()

    # (text | code | ':')?
    switch @peek().type
      when 'text'
        tag.block.push @parseText()
      when 'code'
        tag.code = @parseCode()
      when ':'
        @advance()
        tag.block = new nodes.Block
        tag.block.push @parseExpr()
      when 'newline', 'indent', 'outdent', 'eos', 'pipeless-text'
      else
        throw new Error("Unexpected token `#{@peek().type}` expected `text`, `code`, `:`, `newline` or `eos`")
    # newline*
    @advance() while @peek().type is 'newline'

    # block?
    if tag.textOnly
      tag.block = @parseTextBlock()
    else if @peek().type is 'indent'
      for node in @block().nodes
        tag.block.push node
    return tag

module.exports = Parser
