nodes = require './nodes'
filters = require './filters'
doctypes = require './doctypes'
runtime = require './runtime'
utils = require './utils'
selfClosing = require './self-closing'
parseJSExpression = require('character-parser').parseMax
constantinople = require 'constantinople'

isConstant = (src) ->
  constantinople src,
    jade: runtime
    jade_interp: undefined

toConstant = (src) ->
  constantinople.toConstant src,
    jade: runtime
    jade_interp: undefined

errorAtNode = (node, error) ->
  error.line = node.line
  error.filename = node.filename
  error

###
 * Initialize `Compiler` with the given `node`.
 * @param {Node} node
 * @param {Object} options
 * @api public
###
Compiler = module.exports = Compiler = (node, options) ->
  @options = options = options or {}
  @node = node
  @hasCompiledDoctype = false
  @hasCompiledTag = false
  @pp = options.pretty or false
  @debug = false isnt options.compileDebug
  @indents = 0
  @parentIndents = 0
  @terse = false
  @mixins = {}
  @dynamicMixins = false
  @setDoctype options.doctype if options.doctype
  return

###
 * Compiler prototype.
###
Compiler:: =
  ###
   * Compile parse tree to JavaScript.
   * @api public
  ###
  compile: ->
    @buf = []
    @buf.push 'var jade_indent = [];'  if @pp
    @lastBufferedIdx = -1
    @visit @node
    unless @dynamicMixins

      # if there are no dynamic mixins we can remove any un-used mixins
      mixinNames = Object.keys(@mixins)
      i = 0

      while i < mixinNames.length
        mixin = @mixins[mixinNames[i]]
        unless mixin.used
          x = 0

          while x < mixin.instances.length
            y = mixin.instances[x].start

            while y < mixin.instances[x].end
              @buf[y] = ''
              y++
            x++
        i++
    @buf.join '\n'


  ###
  Sets the default doctype `name`. Sets terse mode to `true` when
  html 5 is used, causing self-closing tags to end with ">" vs "/>",
  and boolean attributes are not mirrored.

   * @param {string} name
   * @api public
  ###
  setDoctype: (name) ->
    @doctype = doctypes[name.toLowerCase()] or "<!DOCTYPE #{name}>"
    @terse = @doctype.toLowerCase() is '<!doctype html>'
    @xml = 0 is @doctype.indexOf('<?xml')
    return


  ###
  Buffer the given `str` exactly as is or with interpolation

   * @param {String} str
   * @param {Boolean} interpolate
   * @api public
  ###
  buffer: (str, interpolate) ->
    self = this
    if interpolate
      match = /(\\)?([#!]){((?:.|\n)*)$/.exec(str)
      if match
        @buffer str.substr(0, match.index), false
        if match[1] # escape
          @buffer match[2] + '{', false
          @buffer match[3], true
          return
        else
          rest = match[3]
          range = parseJSExpression(rest)
          code = (if '!' is match[2] then '' else 'jade.escape') + "((jade_interp = #{range.src}) == null ? '' : jade_interp)"
          @bufferExpression code
          @buffer rest.substr(range.end + 1), true
          return
    str = JSON.stringify(str)
    str = str.substr(1, str.length - 2)
    if @lastBufferedIdx is @buf.length
      @lastBuffered += " + \""  if @lastBufferedType is 'code'
      @lastBufferedType = 'text'
      @lastBuffered += str
      @buf[@lastBufferedIdx - 1] = "buf.push(#{@bufferStartChar}#{@lastBuffered}\");"
    else
      @buf.push "buf.push(\"#{str}\");"
      @lastBufferedType = 'text'
      @bufferStartChar = "\""
      @lastBuffered = str
      @lastBufferedIdx = @buf.length
    return


  ###
   * Buffer the given `src` so it is evaluated at run time
   * @param {String} src
   * @api public
  ###
  bufferExpression: (src) ->
    if isConstant(src)
      return @buffer(toConstant(src) + '', false)
    if @lastBufferedIdx is @buf.length
      @lastBuffered += "\"" if @lastBufferedType is 'text'
      @lastBufferedType = 'code'
      @lastBuffered += " + (#{src})"
      @buf[@lastBufferedIdx - 1] = "buf.push(#{@bufferStartChar}#{@lastBuffered});"
    else
      @buf.push "buf.push(#{src});"
      @lastBufferedType = 'code'
      @bufferStartChar = ''
      @lastBuffered = "(#{src})"
      @lastBufferedIdx = @buf.length
    return


  ###
   * Buffer an indent based on the current `indent` property and an additional `offset`.
   * @param {Number} offset
   * @param {Boolean} newline
   * @api public
  ###
  prettyIndent: (offset, newline) ->
    offset = offset or 0
    newline = (if newline then '\n' else '')
    @buffer newline + Array(@indents + offset).join("  ")
    @buf.push "buf.push.apply(buf, jade_indent);"  if @parentIndents
    return


  ###
   * Visit `node`.
   * @param {Node} node
   * @api public
  ###
  visit: (node) ->
    debug = @debug
    if debug
      @buf.push """
        jade_debug.unshift({
          lineno: #{node.line},
          filename: #{
            if node.filename
              JSON.stringify(node.filename)
            else
              'jade_debug[0].filename'
          }
        });
      """

    # Massive hack to fix our context
    # stack for - else[ if] etc
    if false is node.debug and @debug
      @buf.pop()
      @buf.pop()
    @visitNode node
    @buf.push "jade_debug.shift();"  if debug
    return


  ###
   * Visit `node`.
   * @param {Node} node
   * @api public
  ###
  visitNode: (node) ->
    this['visit' + node.type] node


  ###
   * Visit case `node`.
   * @param {Literal} node
   * @api public
  ###
  visitCase: (node) ->
    _ = @withinCase
    @withinCase = true
    @buf.push "switch (#{node.expr}){"
    @visit node.block
    @buf.push '}'
    @withinCase = _
    return


  ###
   * Visit when `node`.
   * @param {Literal} node
   * @api public
  ###
  visitWhen: (node) ->
    if 'default' is node.expr
      @buf.push 'default:'
    else
      @buf.push "case #{node.expr}:"
    if node.block
      @visit node.block
      @buf.push "  break;"
    return


  ###
   * Visit literal `node`.
   * @param {Literal} node
   * @api public
  ###
  visitLiteral: (node) ->
    @buffer node.str
    return


  ###
   * Visit all nodes in `block`.
   * @param {Block} block
   * @api public
  ###
  visitBlock: (block) ->
    len = block.nodes.length

    # Pretty print multi-line text
    if @pp and len > 1 and not @escape and block.nodes[0].isText and block.nodes[1].isText
      @prettyIndent 1, true

    for i in [0...len]
      # Pretty print text
      if @pp and i > 0 and not @escape and block.nodes[i].isText and block.nodes[i - 1].isText
        @prettyIndent 1, false
      @visit block.nodes[i]

      # Multiple text nodes are separated by newlines
      if block.nodes[i + 1] and block.nodes[i].isText and block.nodes[i + 1].isText
        @buffer '\n'
    return


  ###
   * Visit a mixin's `block` keyword.
   * @param {MixinBlock} block
   * @api public
  ###
  visitMixinBlock: (block) ->
    if @pp
      @buf.push "jade_indent.push('#{Array(@indents + 1).join('  ')}');"
    @buf.push 'block && block();'
    if @pp
      @buf.push 'jade_indent.pop();'
    return


  ###
   * Visit `doctype`. Sets terse mode to `true` when html 5 is used, causing self-closing tags to end with ">" vs "/>", and boolean attributes are not mirrored.
   * @param {Doctype} doctype
   * @api public
  ###
  visitDoctype: (doctype) ->
    @setDoctype doctype.val or 'default'  if doctype and (doctype.val or not @doctype)
    @buffer @doctype if @doctype
    @hasCompiledDoctype = true
    return


  ###
   * Visit `mixin`, generating a function that may be called within the template.
   * @param {Mixin} mixin
   * @api public
  ###
  visitMixin: (mixin) ->
    name = 'jade_mixins['
    args = mixin.args or ''
    block = mixin.block
    attrs = mixin.attrs
    attrsBlocks = mixin.attributeBlocks
    dynamic = mixin.name[0] is '#'
    key = mixin.name
    @dynamicMixins = true if dynamic
    name += (
      if dynamic
        mixin.name.substr(2, mixin.name.length - 3)
      else
        "\"#{mixin.name}\""
    ) + ']'
    @mixins[key] = @mixins[key] or
      used: false
      instances: []

    if mixin.call
      @mixins[key].used = true
      if @pp
        @buf.push "jade_indent.push('#{Array(@indents + 1).join('  ')}');"
      if block or attrs.length or attrsBlocks.length
        @buf.push name + '.call({'
        if block
          @buf.push 'block: function(){'

          # Render block with no indents, dynamically added when rendered
          @parentIndents++
          _indents = @indents
          @indents = 0
          @visit mixin.block
          @indents = _indents
          @parentIndents--
          if attrs.length or attrsBlocks.length
            @buf.push '},'
          else
            @buf.push '}'
        if attrsBlocks.length
          if attrs.length
            val = @attrs(attrs)
            attrsBlocks.unshift val
          @buf.push "attributes: jade.merge([#{attrsBlocks.join(",")}])"
        else if attrs.length
          val = @attrs(attrs)
          @buf.push "attributes: #{val}"
        if args
          @buf.push "}, #{args});"
        else
          @buf.push '});'
      else
        @buf.push name + "(#{args});"
      if @pp
        @buf.push 'jade_indent.pop();'
    else
      mixin_start = @buf.length
      @buf.push "#{name} = function(#{args}){"
      @buf.push 'var block = (this && this.block), attributes = (this && this.attributes) || {};'
      @parentIndents++
      @visit block
      @parentIndents--
      @buf.push "};"
      mixin_end = @buf.length
      @mixins[key].instances.push
        start: mixin_start
        end: mixin_end

    return


  ###
   * Visit `tag` buffering tag markup, generating attributes, visiting the `tag`'s code and block.
   * @param {Tag} tag
   * @api public
  ###
  visitTag: (tag) ->
    bufferName = ->
      if tag.buffer
        self.bufferExpression name
      else
        self.buffer name
      return
    @indents++
    name = tag.name
    pp = @pp
    self = this
    @escape = true if 'pre' is tag.name
    unless @hasCompiledTag
      @visitDoctype()  if not @hasCompiledDoctype and 'html' is name
      @hasCompiledTag = true

    # pretty print
    @prettyIndent 0, true if pp and not tag.isInline()
    if tag.selfClosing or (not @xml and selfClosing.indexOf(tag.name) isnt -1)
      @buffer '<'
      bufferName()
      @visitAttributes tag.attrs, tag.attributeBlocks
      (if @terse then @buffer('>') else @buffer('/>'))

      # if it is non-empty throw an error
      if tag.block and
         not (tag.block.type is 'Block' and tag.block.nodes.length is 0) and
         tag.block.nodes.some((tag) ->
          tag.type isnt 'Text' or not /^\s*$/.test(tag.val)
         )
        throw errorAtNode(tag, new Error("#{name} is self closing and should not have content."))
    else

      # Optimize attributes buffering
      @buffer '<'
      bufferName()
      @visitAttributes tag.attrs, tag.attributeBlocks
      @buffer '>'
      @visitCode tag.code if tag.code
      @visit tag.block

      # pretty print
      @prettyIndent 0, true if pp and not tag.isInline() and 'pre' isnt tag.name and not tag.canInline()
      @buffer '</'
      bufferName()
      @buffer '>'
    @escape = false if 'pre' is tag.name
    @indents--
    return


  ###
  Visit `filter`, throwing when the filter does not exist.

   * @param {Filter} filter
   * @api public
  ###
  visitFilter: (filter) ->
    text = filter.block.nodes.map((node) ->
      node.val
    ).join('\n')
    filter.attrs.filename = @options.filename
    try
      @buffer filters(filter.name, text, filter.attrs), true
    catch err
      throw errorAtNode(filter, err)
    return


  ###
  Visit `text` node.

   * @param {Text} text
   * @api public
  ###
  visitText: (text) ->
    @buffer text.val, true
    return


  ###
  Visit a `comment`, only buffering when the buffer flag is set.

   * @param {Comment} comment
   * @api public
  ###
  visitComment: (comment) ->
    return  unless comment.buffer
    @prettyIndent 1, true if @pp
    @buffer "<!--#{comment.val}-->"
    return


  ###
  Visit a `BlockComment`.

   * @param {Comment} comment
   * @api public
  ###
  visitBlockComment: (comment) ->
    return  unless comment.buffer
    @prettyIndent 1, true if @pp
    @buffer "<!--#{comment.val}"
    @visit comment.block
    @prettyIndent 1, true if @pp
    @buffer '-->'
    return


  ###
   * Visit `code`, respecting buffer / escape flags. If the code is followed by
     a block, wrap it in a self-calling function.
   * @param {Code} code
   * @api public
  ###
  visitCode: (code) ->

    # Wrap code blocks with {}.
    # we only wrap unbuffered code blocks ATM
    # since they are usually flow control

    # Buffer code
    if code.buffer
      val = code.val.trimLeft()
      val = "null == (jade_interp = #{val}) ? \"\" : jade_interp"
      if code.escape
        val = "jade.escape(#{val})"
      @bufferExpression val
    else
      @buf.push code.val

    # Block support
    if code.block
      unless code.buffer
        @buf.push '{'
      @visit code.block
      unless code.buffer
        @buf.push '}'
    return


  ###
   * Visit `each` block.
   * @param {Each} each
   * @api public
  ###
  visitEach: (each) ->
    @buf.push """
      // iterate #{each.obj}
      ;(function(){
        var $$obj = #{each.obj};
        if ('number' == typeof $$obj.length) {
      """
    if each.alternative
      @buf.push '  if ($$obj.length) {'
    @buf.push """
          for (var #{each.key} = 0, $$l = $$obj.length; #{each.key} < $$l; #{each.key}++) {
            var #{each.val} = $$obj[#{each.key}];
      """
    @visit each.block
    @buf.push '    }\n'
    if each.alternative
      @buf.push '  } else {'
      @visit each.alternative
      @buf.push '  }'
    @buf.push """
        } else {
          var $$l = 0;
          for (var #{each.key} in $$obj) {
            $$l++;
            var #{each.val} = $$obj[#{each.key}];
      """
    @visit each.block
    @buf.push '    }\n'
    if each.alternative
      @buf.push '    if ($$l === 0) {'
      @visit each.alternative
      @buf.push '    }'
    @buf.push '  }\n}).call(this);\n'
    return


  ###
   * Visit `attrs`.
   * @param {Array} attrs
   * @api public
  ###
  visitAttributes: (attrs, attributeBlocks) ->
    if attributeBlocks.length
      if attrs.length
        val = @attrs(attrs)
        attributeBlocks.unshift val
      @bufferExpression "jade.attrs(jade.merge([#{attributeBlocks.join(",")}]), #{JSON.stringify(@terse)})"
    else @attrs attrs, true if attrs.length
    return


  ###
   * Compile attributes.
  ###
  attrs: (attrs, buffer) ->
    buf = []
    classes = []
    classEscaping = []
    attrs.forEach ((attr) ->
      key = attr.name
      escaped = attr.escaped
      if key is 'class'
        classes.push attr.val
        classEscaping.push attr.escaped
      else if isConstant(attr.val)
        if buffer
          @buffer runtime.attr(key, toConstant(attr.val), escaped, @terse)
        else
          val = toConstant(attr.val)
          if escaped and not (key.indexOf('data') is 0 and typeof val isnt 'string')
            val = runtime.escape(val)
          buf.push JSON.stringify(key) + ": " + JSON.stringify(val)
      else
        if buffer
          @bufferExpression """
            jade.attr(
              \"#{key}\",
              #{attr.val},
              #{JSON.stringify(escaped)},
              #{JSON.stringify(@terse)}
            )
          """
        else
          val = attr.val
          if escaped and (key.indexOf('data') isnt 0)
            val = "jade.escape(#{val})"
          else if escaped
            val = """(
              typeof (jade_interp = #{val}) == \"string\" ? jade.escape(jade_interp) : jade_interp
            )"""
          buf.push "#{JSON.stringify(key)}: #{val}"
      return
    ).bind(this)
    if buffer
      if classes.every(isConstant)
        @buffer runtime.cls(classes.map(toConstant), classEscaping)
      else
        @bufferExpression """
          jade.cls([#{classes.join(",")}], #{JSON.stringify(classEscaping)})
        """
    else if classes.length
      if classes.every(isConstant)
        classes = JSON.stringify(runtime.joinClasses(classes.map(toConstant).map(runtime.joinClasses).map((cls, i) ->
          (if classEscaping[i] then runtime.escape(cls) else cls)
        )))
      else
        classes = """(
          jade_interp = #{JSON.stringify(classEscaping)},
          jade.joinClasses([#{classes.join(",")}]
            .map(jade.joinClasses)
            .map(function (cls, i) {
              return jade_interp[i] ? jade.escape(cls) : cls
            })
          )
        )"""
      if classes.length
        buf.push "\"class\": #{classes}"
    return "{#{buf.join(',')}}"
