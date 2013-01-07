utils = require './utils'

class Lexer
	###*
	 * Initialize `Lexer` with the given `str`
	 * @param {String} str
	 * @param {Object} options
	 * @private
	###
	constructor: (str, options) ->
		options = options or {}
		@input = str.replace(/\r\n|\r/g, '\n')
		@deferredTokens = []
		@lastIndents = 0
		@lineno = 1
		@stash = []
		@indentStack = []
		@indentRe = null
		@pipeless = false

	###*
	 * Construct a token with the given `type` and `val`
	 * @param {String} type
	 * @param {String} val
	 * @private
	###
	tok: (type, val) ->
		type: type
		line: @lineno
		val: val

	
	###
	Consume the given `len` of input.
	
	@param {Number} len
	@private
	###
	consume: (len) ->
		@input = @input.substr(len)

	###*
	 * Scan with the given `regexp`. Pass the matches from the regular
			 expression to the `callback`. The `callback` should return a tok
	 * @param {RegExp} regexp
	 * @param {Function} callback
	 * @return {Array or null}
	 * @private
	###
	capture: (regexp, callback) ->
		captures = regexp.exec(@input)
		unless captures is null
			@consume captures[0].length
			return callback(captures)
		return null

	###
	Scan for `type` with the given `regexp`.
	Return a token
	
	@param {String} type
	@param {RegExp} regexp
	@return {Object}
	@private
	###
	scan: (regexp, type) ->
		@capture(
			regexp,
			(captures) =>
				@tok type, captures[1]
		)

	###
	Defer the given `tok`.
	
	@param {Object} tok
	@private
	###
	defer: (tok) ->
		@deferredTokens.push tok

	deferred: ->
		@deferredTokens.length and @deferredTokens.shift()

	###
	Lookahead `n` tokens and stash results
	
	@param {Number} n
	@return {Object}
	@private
	###
	lookahead: (n) ->
		fetch = n - @stash.length
		@stash.push @next() while fetch-- > 0
		@stash[--n]

	stashed: ->
		@stash.length and @stash.shift()
	
	#end-of-source
	eos: ->
		return if @input.length
		if @indentStack.length
			@indentStack.shift()
			@tok 'outdent'
		else
			@tok 'eos'

	#Blank line
	blank: ->
		if captures = /^\n *\n/.exec(@input)
			@consume captures[0].length - 1
			++@lineno
			return @tok("text", '') if @pipeless
			@next()

	comment: ->
		@capture(
			/^ *\/\/(-)?([^\n]*)/,
			(captures) =>
				tok = @tok("comment", captures[2])
				tok.buffer = "-" isnt captures[1]
				tok
		)

	tag: ->
		@capture(
			/^(\w[\-:\w]*)(\/?)/,
			(captures) =>
				name = captures[1]
				if ':' is name[name.length - 1]
					name = name.slice(0, -1)
					tok = @tok('tag', name)
					@defer @tok(':')
					@input = @input.substr(1) while @input[0] is " "
				else
					tok = @tok('tag', name)
				tok.selfClosing = !!captures[2]
				tok
		)

	doctype: ->
		@scan /^(?:!!!|doctype) *([^\n]+)?/, "doctype"

	id: ->
		@scan /^#([\w-]+)/, "id"

	className: ->
		@scan /^\.([\w-]+)/, "class"

	text: ->
		@scan /^(?:\| ?| ?)?([^\n]+)/, "text"

	extends: ->
		@scan /^extends? +([^\n]+)/, "extends"

	
	#Block prepend
	prepend: ->
		@capture(
			/^prepend +([^\n]+)/,
			(captures) =>
				mode = 'prepend'
				name = captures[1]
				tok = @tok('block', name)
				tok.mode = mode
				tok
		)

	
	#Block append
	append: ->
		@capture(
			/^append +([^\n]+)/,
			(captures) =>
				mode = 'append'
				name = captures[1]
				tok = @tok('block', name)
				tok.mode = mode
				tok
		)

	block: ->
		@capture(
			/^block\b *(?:(prepend|append) +)?([^\n]*)/,
			(captures) =>
				mode = captures[1] or 'replace'
				name = captures[2]
				tok = @tok('block', name)
				tok.mode = mode
				tok
		)

	yield: ->
		@scan /^yield */, "yield"

	include: ->
		@scan /^include +([^\n]+)/, "include"

	#Call mixin
	call: ->
		@capture(
			/^\+([\-\w]+)/,
			(captures) =>
				tok = @tok('call', captures[1])

				if @input[0] is '('
					str = utils.balance_string @input, ')'
					unless /^ *[-\w]+ *=|^ *attributes *(?:,|$)/.test str[1...-1]
						@consume str.length
						tok.args = str[1...-1]
				tok
		)

	mixin: ->
		@capture(
			/^mixin +([\-\w]+)/,
			(captures) =>
				tok = @tok('mixin', captures[1])
				if @input[0] is '('
					str = utils.balance_string(@input, ')')
					@consume str.length
					tok.args = str[1...-1]
				tok
		)

	code: ->
		@capture(
			/^(!?=|-)([^\n]+)/,
			(captures) =>
				flags = captures[1]
				tok = @tok("code", captures[2])
				tok.escape = flags.charAt(0) is '='
				tok.buffer = flags.charAt(0) is '=' or flags.charAt(1) is '='
				tok
		)

	attrs: ->
		if '(' isnt @input[0]
			return
		str = utils.balance_string @input, ')'
		@consume str.length
		str = str[1...-1].trim()

		if str is ''
			#for empty attribute containers like `p()`
			return @next()

		attrs = {}
		escape = {}
		# TODO: remove that escaped attr thing... not used
		value = 'true'
		key = ''
		escape_attr = true

		if str[str.length - 1] not in ['\n', ',']
			#add an end_delemeter at the end if there isn't one
			str += ','

		while str isnt ''
			matches = utils.match_delimiters(str, '', [',', '\n', '='])
			str = str.substr(matches[0].length).trim() #consume
			matches[1] = matches[1].trim()

			if matches[0][matches[0].length - 1] in [',', '\n']
				if key is ''
					# if a key is not followed by a value
					key = matches[1]
				else
					# key was already specified
					value = matches[1]
				attrs[key] = value
				escape[key] = escape_attr

				escape_attr = true # default
				value = 'true'
				key = ''
			else
				# ends in a `=`. store key and wait for value
				key = matches[1]

				if key[key.length - 1] is '!'
					key = key.substr(0,key.length - 1) #consume `!` (unescape symbol)
					escape_attr = false
		tok = @tok(
			'attrs',
			attrs: attrs
			escape: escape
		)
		#TODO: make self-closing get detected while parsing tag
		if '/' is @input.charAt(0)
			@consume 1
			tok.selfClosing = true # moved over to the tag during parsing
		return tok

	#Indent | Outdent | Newline
	indent: ->
		# established regexp
		if @indentRe
			captures = @indentRe.exec(@input)
		
		# determine regexp
		else
			# tabs
			re = /^\n(\t*) */
			captures = re.exec(@input)
			
			# spaces
			if captures and not captures[1].length
				re = /^\n( *)/
				captures = re.exec(@input)
			
			# established
			@indentRe = re if captures and captures[1].length

		if captures
			indents = captures[1].length
			++@lineno
			@consume indents + 1
			throw new Error("Invalid indentation, you can use tabs or spaces but not both") if ' ' is @input[0] or "\t" is @input[0]
			
			# blank line
			return @tok('newline') if '\n' is @input[0]
			
			# outdent
			if @indentStack.length and indents < @indentStack[0]
				while @indentStack.length and @indentStack[0] > indents
					@stash.push @tok("outdent")
					@indentStack.shift()
				tok = @stash.pop()
			
			# indent
			else if indents and indents isnt @indentStack[0]
				@indentStack.unshift indents
				tok = @tok("indent", indents)
			
			# newline
			else
				tok = @tok('newline')
			tok

	#Pipe-less text consumed only when `pipeless` is true
	pipelessText: ->
		if @pipeless
			return if '\n' is @input[0]
			i = @input.indexOf('\n')
			i = @input.length if -1 is i
			str = @input.substr(0, i)
			@consume str.length
			@tok "text", str

	#':'
	colon: ->
		@scan /^: */, ':'

	###
	Return the next token object.

	@return {Object}
	@private
	###
	next: ->
		@stashed() or
		@deferred() or
		@blank() or
		@eos() or
		@pipelessText() or
		@yield() or
		@doctype() or
		@extends() or
		@append() or
		@prepend() or
		@block() or
		@include() or
		@mixin() or
		@call() or
		@tag() or
		@code() or
		@id() or
		@className() or
		@attrs() or
		@indent() or
		@comment() or
		@colon() or
		@text()

exports = module.exports = Lexer