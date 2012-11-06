#Module dependencies
Lexer = require("./lexer")
nodes = require("./nodes")
utils = require("./utils")


class Parser
	###
	Initialize `Parser` with the given input `str` and `filename`.

	@param {String} str
	@param {String} filename
	@param {Object} options
	@api public
	###
	constructor: (str, filename, options) ->
		@input = str
		@lexer = new Lexer(str, options)
		@filename = filename
		@blocks = {}
		@mixins = {}
		@options = options
		@contexts = [this]


	###
	Push `parser` onto the context stack,
	or pop and return a `Parser`.
	###
	context: (parser) ->
		if parser
			@contexts.push parser
		else
			@contexts.pop()

	
	###
	Return the next token object.
	
	@return {Object}
	@api private
	###
	advance: ->
		@lexer.advance()

	
	###
	Skip `n` tokens.
	
	@param {Number} n
	@api private
	###
	skip: (n) ->
		@advance() while n--

	
	###
	Single token lookahead.
	
	@return {Object}
	@api private
	###
	peek: ->
		@lookahead 1

	
	###
	Return lexer lineno.
	
	@return {Number}
	@api private
	###
	line: ->
		@lexer.lineno

	
	###
	`n` token lookahead.
	
	@param {Number} n
	@return {Object}
	@api private
	###
	lookahead: (n) ->
		@lexer.lookahead n

	
	###
	Parse input returning a string of js for evaluation.
	
	@return {String}
	@api public
	###
	parse: ->
		block = new nodes.Block
		parser = undefined
		block.line = @line()
		until "eos" is @peek().type
			if "newline" is @peek().type
				@advance()
			else
				block.push @parseExpr()
		if parser = @extending
			@context parser
			ast = parser.parse()
			@context()
			
			# hoist mixins
			for name of @mixins
				ast.unshift @mixins[name]
			return ast
		block

	
	###
	Expect the given type, or throw an exception.
	
	@param {String} type
	@api private
	###
	expect: (type) ->
		if @peek().type is type
			@advance()
		else
			throw new Error("expected \"" + type + "\", but got \"" + @peek().type + "\"")

	
	###
	Accept the given `type`.
	
	@param {String} type
	@api private
	###
	accept: (type) ->
		@advance() if @peek().type is type

	
	###
	tag
	| doctype
	| mixin
	| include
	| filter
	| comment
	| text
	| each
	| code
	| yield
	| id
	| class
	| interpolation
	###
	parseExpr: ->
		switch @peek().type
			when "tag"
				@parseTag()
			when "mixin"
				@parseMixin()
			when "block"
				@parseBlock()
			when "extends"
				@parseExtends()
			when "include"
				@parseInclude()
			when "doctype"
				@parseDoctype()
			when "filter"
				@parseFilter()
			when "comment"
				@parseComment()
			when "text"
				@parseText()
			when "code"
				@parseCode()
			when "call"
				@parseCall()
			when "interpolation"
				@parseInterpolation()
			when "yield"
				@advance()
				block = new nodes.Block
				block.yield_tok = true
				block
			when "id", "class"
				tok = @advance()
				@lexer.defer @lexer.tok("tag", "div")
				@lexer.defer tok
				@parseExpr()
			else
				throw new Error("unexpected token \"" + @peek().type + "\"")

	
	###
	Text
	###
	parseText: ->
		tok = @expect("text")
		node = new nodes.Text(tok.val)
		node.line = @line()
		node

	
	###
	':' expr
	| block
	###
	parseBlockExpansion: ->
		if ":" is @peek().type
			@advance()
			new nodes.Block(@parseExpr())
		else
			@block()

	
	###
	code
	###
	parseCode: ->
		tok = @expect("code")
		node = new nodes.Code(tok.val, tok.buffer, tok.escape)
		block = undefined
		i = 1
		node.line = @line()
		++i while @lookahead(i) and "newline" is @lookahead(i).type
		block = "indent" is @lookahead(i).type
		if block
			@skip i - 1
			node.block = @block()
		node

	
	###
	comment
	###
	parseComment: ->
		tok = @expect("comment")
		node = undefined
		if "indent" is @peek().type
			node = new nodes.BlockComment(tok.val, @block(), tok.buffer)
		else
			node = new nodes.Comment(tok.val, tok.buffer)
		node.line = @line()
		node

	
	###
	doctype
	###
	parseDoctype: ->
		tok = @expect("doctype")
		node = new nodes.Doctype(tok.val)
		node.line = @line()
		node

	
	###
	filter attrs? text-block
	###
	parseFilter: ->
		block = undefined
		tok = @expect("filter")
		attrs = @accept("attrs")
		@lexer.pipeless = true
		block = @parseTextBlock()
		@lexer.pipeless = false
		node = new nodes.Filter(tok.val, block, attrs and attrs.attrs)
		node.line = @line()
		node


	###
	'extends' name
	###
	parseExtends: ->
		path = require("path")
		fs = require("fs")
		dirname = path.dirname
		basename = path.basename
		join = path.join
		throw new Error("the \"filename\" option is required to extend templates") unless @filename
		path = @expect("extends").val.trim()
		dir = dirname(@filename)
		path = join(dir, path + ".jade")
		str = fs.readFileSync(path, "utf8")
		parser = new Parser(str, path, @options)
		parser.blocks = @blocks
		parser.contexts = @contexts
		@extending = parser
		
		# TODO: null node
		new nodes.Literal("")

	
	###
	'block' name block
	###
	parseBlock: ->
		block = @expect("block")
		mode = block.mode
		name = block.val.trim()
		block = (if "indent" is @peek().type then @block() else new nodes.Block(new nodes.Literal("")))
		prev = @blocks[name]
		if prev
			switch prev.mode
				when "append"
					block.nodes = block.nodes.concat(prev.nodes)
					prev = block
				when "prepend"
					block.nodes = prev.nodes.concat(block.nodes)
					prev = block
		block.mode = mode
		@blocks[name] = prev or block

	
	###
	include block?
	###
	parseInclude: ->
		path = require("path")
		fs = require("fs")

		throw new Error("the \"filename\" option is required to use includes") unless @filename
		dir = path.dirname(@filename)

		include_filename = @expect("include").val.trim()
		extname = path.extname(include_filename)

		if extname is '' # no extension defaults to jade
			extname = ".jade"
			include_filename += ".jade"

		include_filepath = path.join(dir, include_filename)
		str = fs.readFileSync(include_filepath, "utf8")
		
		if ".jade" isnt extname # non-jade
			return new nodes.Literal(str)

		parser = new Parser(str, include_filepath, @options)
		parser.blocks = utils.merge({}, @blocks)
		parser.mixins = @mixins
		@context parser
		ast = parser.parse()
		@context()
		ast.filename = include_filepath
		ast.includeBlock().push @block() if "indent" is @peek().type
		return ast
 
	
	###
	call indent block
	###
	parseCall: ->
		tok = @expect("call")
		name = tok.val
		args = tok.args
		mixin = new nodes.Mixin(name, args, new nodes.Block, true)
		@tag mixin
		mixin.block = null if mixin.block.isEmpty()
		mixin

	
	###
	mixin block
	###
	parseMixin: ->
		tok = @expect("mixin")
		name = tok.val
		args = tok.args
		mixin = undefined
		
		# definition
		if "indent" is @peek().type
			mixin = new nodes.Mixin(name, args, @block(), false)
			@mixins[name] = mixin
			mixin
		
		# call
		else
			new nodes.Mixin(name, args, null, true)

	
	# indent (text | newline)* outdent
	parseTextBlock: ->
		block = new nodes.Block
		block.line = this.line()
		spaces = this.expect('indent').val
		if not @_spaces? then @_spaces = spaces
		indent = Array(spaces - @_spaces + 1).join(' ')
		while 'outdent' isnt @peek().type
			if @peek().type is 'newline'
				@advance()
			else if @peek().type is 'indent'
				@parseTextBlock().nodes.forEach (node) ->
					block.push(node)
			else
				text = new nodes.Text(indent + this.advance().val)
				text.line = this.line()
				block.push(text)


		if spaces is @_spaces then @_spaces = null
		@expect('outdent')
		block

	
	###
	indent expr* outdent
	###
	block: ->
		block = new nodes.Block
		block.line = @line()
		@expect "indent"
		until "outdent" is @peek().type
			if "newline" is @peek().type
				@advance()
			else
				block.push @parseExpr()
		@expect "outdent"
		block

	
	###
	interpolation (attrs | class | id)* (text | code | ':')? newline* block?
	###
	parseInterpolation: ->
		tok = @advance()
		tag = new nodes.Tag(tok.val)
		tag.buffer = true
		@tag tag

	
	###
	tag (attrs | class | id)* (text | code | ':')? newline* block?
	###
	parseTag: ->
		
		# ast-filter look-ahead
		i = 2
		++i if "attrs" is @lookahead(i).type
		tok = @advance()
		tag = new nodes.Tag(tok.val)
		tag.selfClosing = tok.selfClosing
		@tag tag

	
	###
	Parse tag.
	###
	tag: (tag) ->
		dot = undefined
		tag.line = @line()
		
		# (attrs | class | id)*
		loop
			if this.peek().type is 'class' or this.peek().type is 'id'
				tok = this.advance()
				tag.setAttribute(tok.type, "'" + tok.val + "'")
			else if this.peek().type is 'attrs'
				tok = this.advance()
				obj = tok.attrs
				escaped = tok.escaped
				names = Object.keys(obj)

				if tok.selfClosing then tag.selfClosing = true

				for name in names
					tag.setAttribute(name, obj[name], escaped[name])
			else
				break

		# check immediate '.'
		if "." is @peek().val
			dot = tag.textOnly = true
			@advance()
		
		# (text | code | ':')?
		switch @peek().type
			when "text"
				tag.block.push @parseText()
			when "code"
				tag.code = @parseCode()
			when ":"
				@advance()
				tag.block = new nodes.Block
				tag.block.push @parseExpr()
		
		# newline*
		@advance() while "newline" is @peek().type
		
		#script special-case (for non-js scripts?)
		#if 'script' is tag.name
		#	type = tag.getAttribute('type');
		#	if not dot and type and 'text/javascript' isnt type.replace(/^['"]|['"]$/g, '')
		#		tag.textOnly = false;
		
		# block?
		if "indent" is @peek().type
			if tag.textOnly
				@lexer.pipeless = true
				tag.block = @parseTextBlock()
				@lexer.pipeless = false
			else
				block = @block()
				if tag.block
					i = 0
					len = block.nodes.length

					while i < len
						tag.block.push block.nodes[i]
						++i
				else
					tag.block = block
		tag


module.exports = Parser