Lexer = require './lexer'
nodes = require './nodes'
utils = require './utils'

class Parser
	###*
	 * Initialize `Parser` with the given input `str` and `filename`.
	 * @param {String} str
	 * @param {String} filename
	 * @param {Object} options
	 * @private
	###
	constructor: (str, filename, options) ->
		@input = str
		@lexer = new Lexer(str, options)
		@filename = filename
		@blocks = {}
		@mixins = {}
		@options = options
		@contexts = [this]

	###*
	 * Push `parser` onto the context stack, or pop and return a `Parser`.
	 * @param {[type]} parser [description]
	 * @return {[type]} [description]
	###
	context: (parser) ->
		if parser
			@contexts.push parser
		else
			@contexts.pop()

	###*
	 * Return the next token object.
	 * @return {Object}
	 * @private
	###
	advance: ->
		@lexer.next()

	###*
	 * Skip `n` tokens.
	 * @param {Number} n
	 * @private
	###
	skip: (n) ->
		@advance() while n--

	###*
	 * Single token lookahead.
	 * @return {Object}
	 * @private
	###
	peek: ->
		@lookahead 1

	###*
	 * Return lexer lineno.
	 * @return {Number}
	 * @private
	###
	line: ->
		@lexer.lineno

	###*
	 * `n` token lookahead.
	 * @param {Number} n
	 * @return {Object}
	 * @private
	###
	lookahead: (n) ->
		@lexer.lookahead n

	###*
	 * Parse input returning a string of CoffeeScript for evaluation.
	 * @return {String}
	 * @private
	###
	parse: ->
		block = new nodes.Block
		block.line = @line()
		until 'eos' is @peek().type
			if 'newline' is @peek().type
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

	###*
	 * Expect the given type, or throw an exception.
	 * @param {String} type
	 * @private
	###
	expect: (type) ->
		if @peek().type is type
			@advance()
		else
			throw new Error("expected \"#{type}\", but got \"#{@peek().type}\"")

	###*
	 * Accept the given `type`.
	 * @param {String} type
	 * @private
	###
	accept: (type) ->
		@advance() if @peek().type is type

	parseExpr: ->
		switch @peek().type
			when 'tag'
				@parseTag()
			when 'mixin'
				@parseMixin()
			when 'block'
				@parseBlock()
			when 'extends'
				@parseExtends()
			when 'include'
				@parseInclude()
			when 'doctype'
				@parseDoctype()
			when 'comment'
				@parseComment()
			when 'text'
				@parseText()
			when 'code'
				@parseCode()
			when 'call'
				@parseCall()
			when 'yield'
				@advance()
				block = new nodes.Block
				block.yield_tok = true
				block
			when 'id', 'class'
				tok = @advance()
				@lexer.defer @lexer.tok('tag', 'div')
				@lexer.defer tok
				@parseExpr()
			else
				throw new Error("unexpected token \"#{@peek().type}\"")

	parseText: ->
		tok = @expect('text')
		node = new nodes.Text(tok.val)
		node.line = @line()
		node

	###
	':' expr
	| block
	###
	parseBlockExpansion: ->
		if ':' is @peek().type
			@advance()
			new nodes.Block(@parseExpr())
		else
			@block()

	parseCode: ->
		tok = @expect('code')
		node = new nodes.Code(tok.val, tok.buffer, tok.escape)
		i = 1
		node.line = @line()

		while @lookahead(i) and 'newline' is @lookahead(i).type
			++i

		block = @lookahead(i)? and 'indent' is @lookahead(i).type
		if block
			@skip i - 1
			node.block = @block()
		node

	parseComment: ->
		tok = @expect('comment')
		if 'indent' is @peek().type
			node = new nodes.BlockComment(tok.val, @block(), tok.buffer)
		else
			node = new nodes.Comment(tok.val, tok.buffer)
		node.line = @line()
		node

	parseDoctype: ->
		tok = @expect('doctype')
		node = new nodes.Doctype(tok.val)
		node.line = @line()
		node

	parseExtends: ->
		path = require('path')
		fs = require('fs')
		dirname = path.dirname
		basename = path.basename
		join = path.join
		unless @filename
			throw new Error('the \"filename\" option is required to extend templates')
		path = @expect('extends').val.trim()
		dir = dirname(@filename)
		path = join(dir, "#{path}.jade")
		str = fs.readFileSync(path, 'utf8')
		parser = new Parser(str, path, @options)
		parser.blocks = @blocks
		parser.contexts = @contexts
		@extending = parser
		
		# TODO: null node
		new nodes.Literal('')

	###
	'block' name block
	###
	parseBlock: ->
		block = @expect('block')
		mode = block.mode
		name = block.val.trim()
		block = (
			if 'indent' is @peek().type
				@block()
			else
				new nodes.Block(new nodes.Literal(''))
		)
		prev = @blocks[name]
		if prev
			switch prev.mode
				when 'append'
					block.nodes = block.nodes.concat(prev.nodes)
					prev = block
				when 'prepend'
					block.nodes = prev.nodes.concat(block.nodes)
					prev = block
		block.mode = mode
		@blocks[name] = prev or block

	###
	include block?
	###
	parseInclude: ->
		path = require('path')
		fs = require('fs')

		unless @filename
			throw new Error('the \"filename\" option is required to use includes')
		dir = path.dirname(@filename)

		include_filename = @expect('include').val.trim()
		extname = path.extname(include_filename)

		if extname is '' # no extension defaults to jade
			extname = '.jade'
			include_filename += '.jade'

		include_filepath = path.join(dir, include_filename)
		str = fs.readFileSync(include_filepath, 'utf8')
		
		if '.jade' isnt extname # non-jade
			return new nodes.Literal(str)

		block = undefined
		parentBlocks = @blocks
		parser = new Parser(str, include_filepath, @options)

		if 'indent' is @peek().type
			block = new nodes.Block()
			@blocks = block.blocks = {}
			block.push @block().prune()

		parser.blocks = utils.merge {}, @blocks
		parser.mixins = @mixins

		@context parser
		ast = parser.parse()
		@context()
		ast.filename = include_filepath

		if block
			ast.includeBlock().push block
		@blocks = parentBlocks
		return ast

	###
	call indent block
	###
	parseCall: ->
		tok = @expect('call')
		name = tok.val
		args = tok.args
		mixin = new nodes.Mixin(name, args, new nodes.Block, true)
		@attrs mixin
		mixin.block = null if mixin.block.isEmpty()
		mixin

	###
	mixin block
	###
	parseMixin: ->
		tok = @expect('mixin')
		name = tok.val
		args = tok.args
		
		# definition
		if 'indent' is @peek().type
			mixin = new nodes.Mixin(name, args, @block(), false)
			@mixins[name] = mixin
			mixin
		
		# call
		else
			new nodes.Mixin(name, args, null, true)

	# indent (text | newline)* outdent
	parseTextBlock: ->
		block = new nodes.Block
		block.line = @line()
		spaces = @expect('indent').val
		if not @_spaces? then @_spaces = spaces
		indent = Array(spaces - @_spaces + 1).join(' ')
		while 'outdent' isnt @peek().type
			if @peek().type is 'newline'
				@advance()
			else if @peek().type is 'indent'
				@parseTextBlock().nodes.forEach (node) ->
					block.push(node)
			else
				text = new nodes.Text(indent + @advance().val)
				text.line = @line()
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
		@expect 'indent'
		until 'outdent' is @peek().type
			if 'newline' is @peek().type
				@advance()
			else
				block.push @parseExpr()
		@expect 'outdent'
		block

	###
	tag (attrs | class | id)* (text | code | ':')? newline* block?
	###
	parseTag: ->
		tok = @advance()
		tag = new nodes.Tag(tok.val)
		tag.selfClosing = tok.selfClosing
		tag.line = @line()
		@attrs tag

	# (attrs | class | id)*
	attrs: (tag) ->
		continue_loop = true
		while continue_loop
			switch @peek().type
				when 'class', 'id'
					tok = @advance()
					tag.setAttribute(tok.type, "\'#{tok.val}\'")
				when 'attrs'
					tok = @advance()
					if tok.selfClosing then tag.selfClosing = true

					for key, value of tok.val['attrs']
						tag.setAttribute(key, value, tok.val['escape'][key])
				else
					#break doesn't work since it's in a switch
					continue_loop = false

		# check immediate '.'
		if '.' is @peek().val
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
		
		# newline*
		@advance() while 'newline' is @peek().type
		
		# block?
		if 'indent' is @peek().type
			if tag.textOnly
				@lexer.pipeless = true
				tag.block = @parseTextBlock()
				@lexer.pipeless = false
			else
				block = @block()
				if tag.block

					for node in block.nodes
						tag.block.push node
				else
					tag.block = block
		return tag

module.exports = Parser