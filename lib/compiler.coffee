#Module dependencies
nodes = require './nodes'
filters = require('./filters').filters
doctypes = require './doctypes'
selfClosing = require './self-closing'
runtime = require './runtime'
utils = require './utils'


class Compiler
	###*
	 * Initialize `Compiler` with the given `node`
	 * @param  {Node}   node    [description]
	 * @param  {Object} options [description]
	 * @private
	###
	constructor: (node, options) ->
		@options = options or {}

		#char used for indentation of outputted HTML
		@INDENT = options.indent or '\t'
		@node = node
		@hasCompiledDoctype = false
		@hasCompiledTag = false
		@pp = options.pretty or false
		@debug = false isnt options.compileDebug

		#indentation of HTML
		@indents = 0
		@parent_indents = 0

		#indentation of the outputted CoffeeScript
		@code_indents = 0

		@setDoctype options.doctype if options.doctype

	###*
	 * Compile parse tree to JavaScript.
	 * @public
	###
	compile: ->
		@buf = []

		@push '__indent = []' if @pp
		@lastBufferedIdx = -1
		@visit @node
		return @buf.join '\n'

	###*
	 * add elements to the array (@buf) holding the compiled SJ code (which is
       actually CoffeeScript). this function also adds indentation to the
       lines that are added based on the value of @code_indents
	 * @param {[type]} args... elements to be added to @buf
	 * @return {Integer} length of @buf
	###
	push: (args...) =>
		#add intentation to each line of each element
		for i in [0...args.length]
			args[i] = utils.indent(args[i], @code_indents)

		return Array.prototype.push.apply @buf, args

	###*
	 * Sets the default doctype `name`. Sets terse mode to `true` when html 5
       is used, causing self-closing tags to end with '>' vs "/>", and boolean
       attributes are not mirrored.
	 * @param {String} name [description]
	 * @public
	###
	setDoctype: (name) ->
		name = (name and name.toLowerCase()) or 'default'
		@doctype = doctypes[name] or "<!DOCTYPE #{name}>"
		@terse = @doctype.toLowerCase() is '<!doctype html>'
		@xml = 0 is @doctype.indexOf('<?xml')

	###*
	 * Buffer the given `str` optionally escaped. Used to combine multiple
       strings of HTML into a single buf.push call in the resulting code.
	 * @param  {String}  str [description]
	 * @param  {Boolean} escape escape double quotes. set to false if they are
       already escaped
	 * @public
	###
	buffer: (str, escape=true) ->
		if escape
			str = utils.escape_quotes(str)

		if @lastBufferedIdx is @buf.length
			#combine with the last entry to the buffer
			@lastBuffered += str
			@buf.remove @lastBufferedIdx - 1
		else
			@lastBuffered = str

		@push "buf.push(\"#{@lastBuffered}\")"
		@lastBufferedIdx = @buf.length

	###*
	 * prevent additional strings from being added to the current buffer
	 * @return {[type]} [description]
	###
	flush_buffer: ->
		@lastBufferedIdx = -1

	###
	Buffer an indent based on the current `indent`
	property and an additional `offset`.

	@param {Number} offset
	@param {Boolean} newline
	@public
	###
	prettyIndent: (offset, newline) ->
		offset = offset or 0
		newline = (if newline then '\\n' else '')
		@buffer newline + Array(@indents + offset).join(@INDENT)
		@push 'buf.push.apply(buf, __indent)' if @parent_indents

	###
	Visit `node`.

	@param {Node} node
	@public
	###

	visit: (node) ->
		if @debug
			@push """
			__jade.unshift(
				lineno:#{node.line}
				filename:#{
					if node.filename
						JSON.stringify(node.filename)
					else
						'__jade[0].filename'
				}
			)
			"""
	
		# Massive hack to fix our context
		# stack for - else[ if] etc
		# TODO: Remove????
		if @debug and node.debug is false
			@buf.pop()
			@buf.pop()
		@visitNode node
		@push '__jade.shift()' if @debug

	###
	Visit `node`.

	@param {Node} node
	@public
	###
	visitNode: (node) ->
		#fix way this is none... make less hackish
		name = node.constructor.name or node.constructor.toString().match(/function ([^(\s]+)()/)[1]
		@["visit#{name}"] node

	###
	Visit literal `node`.

	@param {Literal} node
	@public
	###
	visitLiteral: (node) ->
		str = node.str.replace(/\n/g, "\\\\n")
		@buffer str

	###
	Visit all nodes in `block`.

	@param {Block} block
	@public
	###
	visitBlock: (block) ->
		# Block keyword has a special meaning in mixins
		if @parent_indents and block.mode
			@push "__indent.push('#{Array(@indents + 1).join(@INDENT)}')" if @pp
			@push 'block && block()'
			@push '__indent.pop()' if @pp
			return
		
		len = block.nodes.length

		if @pp and len > 1 and not @escape and block.nodes[0].isText and block.nodes[1].isText
			# Pretty print multi-line text
			@prettyIndent 1, true

		for i in [0...len]
			if @pp and i > 0 and not @escape and block.nodes[i].isText and block.nodes[i - 1].isText
				# Pretty print text
				@prettyIndent 1, false

			@visit block.nodes[i]

			if block.nodes[i + 1] and block.nodes[i].isText and block.nodes[i + 1].isText
				# Multiple text nodes are separated by newlines
				@buffer '\\n'

	###
	Visit `doctype`. Sets terse mode to `true` when html 5
	is used, causing self-closing tags to end with '>' vs "/>",
	and boolean attributes are not mirrored.

	@param {Doctype} doctype
	@public
	###
	visitDoctype: (doctype) ->
		if doctype and (doctype.val or not @doctype)
			@setDoctype doctype.val or 'default'
		if @doctype
			@buffer @doctype
		@hasCompiledDoctype = true

	###
	Visit `mixin`, generating a function that
	may be called within the template.

	@param {Mixin} mixin
	@public
	###
	visitMixin: (mixin) ->
		name = mixin.name
		args = mixin.args or ''
		block = mixin.block
		attrs = mixin.attrs

		if mixin.call
			@push "__indent.push('#{Array(@indents + 1).join(@INDENT)}')" if @pp
			if block or attrs.length
				@push "#{name}.call"
				@code_indents++
				@parent_indents++
				if block
					@push 'block: ->'
					@code_indents++
					# Render block with no indents, dynamically added when rendered
					@parent_indents++
					_indents = @indents
					@indents = 0
					@visit mixin.block
					@indents = _indents
					@parent_indents--
					@flush_buffer()
					@code_indents--
				if attrs.length
					val = @attrs(attrs)
					if val.inherits
						@push """
						attributes: merge {#{val.buf}}, attributes
						escaped: merge #{val.escaped}, escaped, true
						"""
					else
						@push """
						attributes: {#{val.buf}}
						escaped: #{val.escaped}
						"""

				@parent_indents--
				if args
					@push "#{args}"

				@code_indents--
			else
				@push "#{name}(#{args})"

			@push '__indent.pop()' if @pp
		else
			@push "#{name} = (#{args}) ->"
			@code_indents++
			@push 'block = @block; attributes = @attributes or {}; escaped = @escaped or {}'
			@parent_indents++
			@visit block
			@parent_indents--
			@flush_buffer()
			@code_indents--


	###
	Visit `tag` buffering tag markup, generating
	attributes, visiting the `tag`'s code and block.

	@param {Tag} tag
	@public
	###
	visitTag: (tag) ->
		@indents++
		name = tag.name
		name = '#{' + name + '}' if tag.buffer
		unless @hasCompiledTag
			@visitDoctype() if not @hasCompiledDoctype and 'html' is name
			@hasCompiledTag = true
		
		# pretty print
		@prettyIndent 0, true if @pp and not tag.isInline()
		if (~selfClosing.indexOf(name) or tag.selfClosing) and not @xml
			@buffer "<#{name}"
			@visitAttributes tag.attrs
			if @terse then @buffer('>') else @buffer('/>')
		else
			# Optimize attributes buffering
			if tag.attrs.length
				@buffer "<#{name}"
				@visitAttributes tag.attrs if tag.attrs.length
				@buffer '>'
			else
				@buffer "<#{name}>"
			@visitCode tag.code if tag.code
			@escape = 'pre' is tag.name  # TODO: make pre tag into mixin... more semantic
			@visit tag.block
			
			# pretty print
			if @pp and not tag.isInline() and 'pre' isnt tag.name and not tag.canInline()
				@prettyIndent 0, true

			@buffer "</#{name}>"
		@indents--


	###
	Visit `text` node.

	@param {Text} text
	@public
	###
	visitText: (text) ->
		text = utils.interpolate text.val

		#NOTE: escape and interpolate probably can't be mixed together...
		#maybe use escape at run-time?
		if @escape then text =  '#{' + "escape(\"#{text}\")" + '}'
		@buffer text, escape=false

	###
	Visit a `comment`, only buffering when the buffer flag is set.

	@param {Comment} comment
	@public
	###
	visitComment: (comment) ->
		return unless comment.buffer
		@prettyIndent 1, true if @pp
		@buffer "<!--#{comment.val}-->"

	###
	Visit a `BlockComment`.

	@param {Comment} comment
	@public
	###
	visitBlockComment: (comment) ->
		return unless comment.buffer

		# detect IE 'if' filters
		if 0 is comment.val.trim().indexOf('if')
			@buffer "<!--[#{comment.val.trim()}]>"
			@visit comment.block
			@buffer '<![endif]-->'
		else
			@buffer "<!--#{comment.val}"
			@visit comment.block
			@buffer '-->'

	###
	Visit `code`, respecting buffer / escape flags.
	If the code is followed by a block, wrap it in
	a self-calling function.

	@param {Code} code
	@public
	###
	visitCode: (code) ->
		# Buffer code
		if code.buffer
			val = code.val.trimLeft() # TODO: what does this line do?
			@push "__val__ = #{val}" # so it is only evaluated once
			val = 'if __val__ is null or not __val__? then \'\' else __val__'
			val = "escape(#{val})" if code.escape
			@push "buf.push(#{val})"
		else
			@push code.val

		# Block support
		if code.block
			@code_indents++
			@visit code.block
			@flush_buffer()
			@code_indents--

	###
	Visit `attrs`.

	@param {Array} attrs
	@public
	###
	visitAttributes: (attrs) ->
		val = @attrs(attrs)
		if val.inherits
			@push "buf.push(attrs(merge({#{val.buf}}, attributes), merge(#{val.escaped}, escaped, true)))"
		else if val.constant
			eval "buf={#{val.buf}}"
			@buffer runtime.attrs(buf, JSON.parse(val.escaped)), true
		else
			@push "buf.push(attrs({#{val.buf}}, #{val.escaped}))"

	#Compile attributes
	attrs: (attrs) ->
		#TODO switch to coffee script attributes handeling
		buf = []
		classes = []
		escaped = {}
		constants = attrs.every((attr) ->
			isConstant attr.val
		)
		inherits = false
		buf.push 'terse: true' if @terse
		for attr in attrs
			if attr.name is 'attributes'
				inherits = true
				break

			escaped[attr.name] = attr.escaped
			if attr.name is 'class'
				classes.push "#{attr.val}"
			else
				buf.push "'#{attr.name}':(#{attr.val})"

		if classes.length
			classes = classes.join(' + \' \' + ')
			buf.push "class: #{classes}"
		buf: buf.join(', ').replace('class:', '\"class\":')
		escaped: JSON.stringify(escaped)
		inherits: inherits
		constant: constants

module.exports = Compiler

###
Check if expression can be evaluated to a constant

@param {String} expression
@return {Boolean}
@private
###
isConstant = (val) ->
	# Check strings/literals
	return true if /^ *("([^"\\]*(\\.[^"\\]*)*)"|'([^'\\]*(\\.[^'\\]*)*)'|true|false|null|undefined) *$/i.test(val)
	
	# Check numbers
	return true unless isNaN(Number(val))
	
	# Check arrays
	if matches = /^ *\[(.*)\] *$/.exec(val)
		return matches[1].split(',').every(isConstant)
	false

###
Escape the given string of `html`.

@param {String} html
@return {String}
@private
###
escape = (html) ->
	String(html)
		.replace /&/g, '&amp;'
		.replace /</g, '&lt;'
		.replace />/g, '&gt;'
		.replace /"/g, '&quot;'