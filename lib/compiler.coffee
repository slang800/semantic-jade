#Module dependencies
nodes = require("./nodes")
filters = require("./filters").filters
doctypes = require("./doctypes")
selfClosing = require("./self-closing")
runtime = require("./runtime")
utils = require("./utils")

class Compiler
	###*
	 * Initialize `Compiler` with the given `node`
	 * @param  {Node}   node    [description]
	 * @param  {Object} options [description]
	 * @private
	###
	constructor: (node, options) ->
		@options = options = options or {}
		@node = node
		@hasCompiledDoctype = false
		@hasCompiledTag = false
		@pp = options.pretty or false
		@debug = false isnt options.compileDebug
		@indents = 0
		@parentIndents = 0
		@setDoctype options.doctype if options.doctype

	###*
	 * Compile parse tree to JavaScript.
	 * @public
	###
	compile: ->
		@buf = ["var interp;"]
		@buf.push "var __indent = [];" if @pp
		@lastBufferedIdx = -1
		@visit @node
		@buf.join "\n"

	###*
	 * Sets the default doctype `name`. Sets terse mode to `true` when html 5
       is used, causing self-closing tags to end with ">" vs "/>", and boolean
       attributes are not mirrored.
	 * @param {String} name [description]
	 * @public
	###
	setDoctype: (name) ->
		name = (name and name.toLowerCase()) or "default"
		@doctype = doctypes[name] or "<!DOCTYPE #{name}>"
		@terse = @doctype.toLowerCase() is "<!doctype html>"
		@xml = 0 is @doctype.indexOf("<?xml")

	###*
	 * Buffer the given `str` optionally escaped.
	 * @param  {String}  str [description]
	 * @param  {Boolean} esc [description]
	 * @return {[type]}
	 * @public
	###
	buffer: (str, esc) ->
		str = utils.escape(str) if esc
		if @lastBufferedIdx is @buf.length
			@lastBuffered += str
			@buf[@lastBufferedIdx - 1] = "buf.push('#{@lastBuffered}');"
		else
			@buf.push "buf.push('#{str}');"
			@lastBuffered = str
			@lastBufferedIdx = @buf.length

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
		@buffer newline + Array(@indents + offset).join('  ')
		@buf.push 'buf.push.apply(buf, __indent);' if @parentIndents

	###
	Visit `node`.

	@param {Node} node
	@public
	###

	# Massive hack to fix our context
	# stack for - else[ if] etc
	visit: (node) ->
		debug = @debug
		if debug
			@buf.push "__jade.unshift({ lineno: #{node.line}, filename: #{((if node.filename then JSON.stringify(node.filename) else "__jade[0].filename"))} });"
		if false is node.debug and @debug
			@buf.pop()
			@buf.pop()
		@visitNode node
		@buf.push "__jade.shift();" if debug

	###
	Visit `node`.

	@param {Node} node
	@public
	###
	visitNode: (node) ->
		name = node.constructor.name or node.constructor.toString().match(/function ([^(\s]+)()/)[1]
		this["visit#{name}"] node

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
		escape = @escape
		pp = @pp

		# Block keyword has a special meaning in mixins
		if @parentIndents and block.mode
			@buf.push "__indent.push('#{Array(@indents + 1).join("  ")}');" if pp
			@buf.push "block && block();"
			@buf.push "__indent.pop();" if pp
			return
		
		len = block.nodes.length

		# Pretty print multi-line text
		@prettyIndent 1, true if pp and len > 1 and not escape and block.nodes[0].isText and block.nodes[1].isText
		i = 0

		while i < len
			# Pretty print text
			@prettyIndent 1, false if pp and i > 0 and not escape and block.nodes[i].isText and block.nodes[i - 1].isText
			@visit block.nodes[i]

			# Multiple text nodes are separated by newlines
			@buffer "\\n" if block.nodes[i + 1] and block.nodes[i].isText and block.nodes[i + 1].isText
			++i

	###
	Visit `doctype`. Sets terse mode to `true` when html 5
	is used, causing self-closing tags to end with ">" vs "/>",
	and boolean attributes are not mirrored.

	@param {Doctype} doctype
	@public
	###
	visitDoctype: (doctype) ->
		@setDoctype doctype.val or "default" if doctype and (doctype.val or not @doctype)
		@buffer @doctype if @doctype
		@hasCompiledDoctype = true

	###
	Visit `mixin`, generating a function that
	may be called within the template.

	@param {Mixin} mixin
	@public
	###
	visitMixin: (mixin) ->
		name = "#{mixin.name.replace(/-/g, "_")}_mixin"
		args = mixin.args or ""
		block = mixin.block
		attrs = mixin.attrs
		pp = @pp
		if mixin.call
			@buf.push "__indent.push('#{Array(@indents + 1).join("  ")}');" if pp
			if block or attrs.length
				@buf.push "#{name}.call({"
				if block
					@buf.push "block: function(){"
					@parentIndents++
					_indents = @indents
					@indents = 0
					@visit mixin.block
					@indents = _indents
					@parentIndents--
					if attrs.length
						@buf.push "},"
					else
						@buf.push "}"
				if attrs.length
					val = @attrs(attrs)
					if val.inherits
						@buf.push "attributes: merge({#{val.buf}}, attributes), escaped: merge(#{val.escaped}, escaped, true)"
					else
						@buf.push "attributes: {#{val.buf}}, escaped: #{val.escaped}"
				if args
					@buf.push "}, #{args});"
				else
					@buf.push "});"
			else
				@buf.push "#{name}(#{args});"
			@buf.push "__indent.pop();" if pp
		else
			@buf.push "var #{name} = function(#{args}){"
			@buf.push "var block = this.block, attributes = this.attributes || {}, escaped = this.escaped || {};"
			@parentIndents++
			@visit block
			@parentIndents--
			@buf.push "};"

	# Render block with no indents, dynamically added when rendered

	###
	Visit `tag` buffering tag markup, generating
	attributes, visiting the `tag`'s code and block.

	@param {Tag} tag
	@public
	###
	visitTag: (tag) ->
		@indents++
		name = tag.name
		pp = @pp
		name = "' + (#{name}) + '" if tag.buffer
		unless @hasCompiledTag
			@visitDoctype() if not @hasCompiledDoctype and 'html' is name
			@hasCompiledTag = true
		@prettyIndent 0, true if pp and not tag.isInline()
		if (~selfClosing.indexOf(name) or tag.selfClosing) and not @xml
			@buffer "<#{name}"
			@visitAttributes tag.attrs
			(if @terse then @buffer('>') else @buffer("/>"))
		else
			if tag.attrs.length
				@buffer "<#{name}"
				@visitAttributes tag.attrs if tag.attrs.length
				@buffer ">"
			else
				@buffer "<#{name}>"
			@visitCode tag.code if tag.code
			@escape = "pre" is tag.name
			@visit tag.block
			@prettyIndent 0, true if pp and not tag.isInline() and "pre" isnt tag.name and not tag.canInline()
			@buffer "</#{name}>"
		@indents--

	# pretty print

	# Optimize attributes buffering

	# pretty print

	###
	Visit `filter`, throwing when the filter does not exist.

	@param {Filter} filter
	@public
	###
	visitFilter: (filter) ->
		fn = filters[filter.name]
		unless fn
			throw new Error("unknown filter \":#{filter.name}\"")

		text = filter.block.nodes.map((node) ->
			node.val
		).join("\n")
		filter.attrs = filter.attrs or {}
		filter.attrs.filename = @options.filename
		@buffer utils.text(fn(text, filter.attrs))

	# unknown filter

	###
	Visit `text` node.

	@param {Text} text
	@public
	###
	visitText: (text) ->
		text = utils.text(text.val.replace(/\\/g, "_SLASH_"))
		text = escape(text) if @escape
		text = text.replace(/_SLASH_/g, "\\\\")
		@buffer text

	###
	Visit a `comment`, only buffering when the buffer flag is set.

	@param {Comment} comment
	@public
	###
	visitComment: (comment) ->
		return unless comment.buffer
		@prettyIndent 1, true if @pp
		@buffer "<!--#{utils.escape(comment.val)}-->"

	###
	Visit a `BlockComment`.

	@param {Comment} comment
	@public
	###
	visitBlockComment: (comment) ->
		return unless comment.buffer
		if 0 is comment.val.trim().indexOf("if")
			@buffer "<!--[#{comment.val.trim()}]>"
			@visit comment.block
			@buffer "<![endif]-->"
		else
			@buffer "<!--#{comment.val}"
			@visit comment.block
			@buffer "-->"

	###
	Visit `code`, respecting buffer / escape flags.
	If the code is followed by a block, wrap it in
	a self-calling function.

	@param {Code} code
	@public
	###
	visitCode: (code) ->
		if code.buffer
			val = code.val.trimLeft()
			@buf.push "var __val__ = #{val}"
			val = "null == __val__ ? \"\" : __val__"
			val = "escape(#{val})" if code.escape
			@buf.push "buf.push(#{val});"
		else
			@buf.push code.val
		if code.block
			@buf.push "{" unless code.buffer
			@visit code.block
			@buf.push "}" unless code.buffer

	# Wrap code blocks with {}.
	# we only wrap unbuffered code blocks ATM
	# since they are usually flow control

	# Buffer code

	# Block support

	###
	Visit `attrs`.

	@param {Array} attrs
	@public
	###
	visitAttributes: (attrs) ->
		val = @attrs(attrs)
		if val.inherits
			@buf.push "buf.push(attrs(merge({ #{val.buf} }, attributes), merge(#{val.escaped}, escaped, true)));"
		else if val.constant
			eval "var buf={#{val.buf}};"
			@buffer runtime.attrs(buf, JSON.parse(val.escaped)), true
		else
			@buf.push "buf.push(attrs({ #{val.buf} }, #{val.escaped}));"


	#Compile attributes
	attrs: (attrs) ->
		buf = []
		classes = []
		escaped = {}
		constant = attrs.every((attr) ->
			isConstant attr.val
		)
		inherits = false
		buf.push "terse: true" if @terse
		attrs.forEach (attr) ->
			return inherits = true if attr.name is "attributes"
			escaped[attr.name] = attr.escaped
			if attr.name is "class"
				classes.push "(#{attr.val})"
			else
				pair = "'#{attr.name}':(#{attr.val})"
				buf.push pair

		if classes.length
			classes = classes.join(" + ' ' + ")
			buf.push "class: #{classes}"
		buf: buf.join(", ").replace("class:", "\"class\":")
		escaped: JSON.stringify(escaped)
		inherits: inherits
		constant: constant

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
	matches = undefined
	return matches[1].split(",").every(isConstant) if matches = /^ *\[(.*)\] *$/.exec(val)
	false

###
Escape the given string of `html`.

@param {String} html
@return {String}
@private
###
escape = (html) ->
	String(html).replace(/&(?!\w+;)/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace /"/g, "&quot;"