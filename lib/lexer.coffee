utils = require("./utils")


class Lexer
	
	###
	Initialize `Lexer` with the given `str`.

	@param {String} str
	@param {Object} options
	@api private
	###
	constructor: (str, options) ->
		options = options or {}
		@input = str.replace(/\r\n|\r/g, "\n")
		@deferredTokens = []
		@lastIndents = 0
		@lineno = 1
		@stash = []
		@indentStack = []
		@indentRe = null
		@pipeless = false


	###
	Construct a token with the given `type` and `val`.
	
	@param {String} type
	@param {String} val
	@return {Object}
	@api private
	###
	tok: (type, val) ->
		type: type
		line: @lineno
		val: val

	
	###
	Consume the given `len` of input.
	
	@param {Number} len
	@api private
	###
	consume: (len) ->
		@input = @input.substr(len)


	###
	Scan with the given `regexp`.
	Return the matches to the regular expression (the captures)

	@param {RegExp} regexp
	@return {Array or null}
	@api private
	###
	capture: (regexp) ->
		captures = regexp.exec(@input)
		unless captures is null
			@consume captures[0].length
		return captures


	###
	Scan for `type` with the given `regexp`.
	Return a token
	
	@param {String} type
	@param {RegExp} regexp
	@return {Object}
	@api private
	###
	scan: (regexp, type) ->
		captures = @capture(regexp)
		unless captures is null
			@tok type, captures[1]


	###
	Defer the given `tok`.
	
	@param {Object} tok
	@api private
	###
	defer: (tok) ->
		@deferredTokens.push tok


	###
	Lookahead `n` tokens.
	
	@param {Number} n
	@return {Object}
	@api private
	###
	lookahead: (n) ->
		fetch = n - @stash.length
		@stash.push @next() while fetch-- > 0
		@stash[--n]

	
	###
	Return the indexOf `start` / `end` delimiters.
	
	@param {String} start
	@param {String} end
	@return {Number}
	@api private
	###
	indexOfDelimiters: (start, end) ->
		str = @input
		nstart = 0
		nend = 0
		pos = 0
		i = 0
		len = str.length

		while i < len
			if start is str.charAt(i)
				++nstart
			else if end is str.charAt(i)
				if ++nend is nstart
					pos = i
					break
			++i
		pos


	stashed: ->
		@stash.length and @stash.shift()


	deferred: ->
		@deferredTokens.length and @deferredTokens.shift()

	
	#end-of-source
	eos: ->
		return if @input.length
		if @indentStack.length
			@indentStack.shift()
			@tok "outdent"
		else
			@tok "eos"

	
	#Blank line
	blank: ->
		if captures = /^\n *\n/.exec(@input)
			@consume captures[0].length - 1
			return @tok("text", "") if @pipeless
			@next()


	comment: ->
		captures = @capture /^ *\/\/(-)?([^\n]*)/
		unless captures is null
			tok = @tok("comment", captures[2])
			tok.buffer = "-" isnt captures[1]
			tok

	
	#Interpolated tag
	interpolation: ->
		@scan /^#\{(.*?)\}/, "interpolation"


	tag: ->
		captures = @capture /^(\w[\-:\w]*)(\/?)/
		unless captures is null
			tok = undefined
			name = captures[1]
			if ":" is name[name.length - 1]
				name = name.slice(0, -1)
				tok = @tok("tag", name)
				@defer @tok(":")
				@input = @input.substr(1) while " " is @input[0]
			else
				tok = @tok("tag", name)
			tok.selfClosing = !!captures[2]
			tok


	filter: ->
		@scan /^:(\w+)/, "filter"


	doctype: ->
		@scan /^(?:!!!|doctype) *([^\n]+)?/, "doctype"


	id: ->
		@scan /^#([\w-]+)/, "id"

	
	#Class
	className: ->
		@scan /^\.([\w-]+)/, "class"


	text: ->
		@scan /^(?:\| ?| ?)?([^\n]+)/, "text"


	extends: ->
		@scan /^extends? +([^\n]+)/, "extends"

	
	#Block prepend
	prepend: ->
		captures = @capture /^prepend +([^\n]+)/
		unless captures is null
			mode = "prepend"
			name = captures[1]
			tok = @tok("block", name)
			tok.mode = mode
			tok

	
	#Block append
	append: ->
		captures = @capture /^append +([^\n]+)/
		unless captures is null
			mode = "append"
			name = captures[1]
			tok = @tok("block", name)
			tok.mode = mode
			tok


	block: ->
		captures = @capture /^block\b *(?:(prepend|append) +)?([^\n]*)/
		unless captures is null
			mode = captures[1] or "replace"
			name = captures[2]
			tok = @tok("block", name)
			tok.mode = mode
			tok


	yield: ->
		@scan /^yield */, "yield"


	include: ->
		@scan /^include +([^\n]+)/, "include"


	case: ->
		@scan /^case +([^\n]+)/, "case"


	when: ->
		@scan /^when +([^:\n]+)/, "when"


	default: ->
		@scan /^default */, "default"


	assignment: ->
		captures = @capture /^(\w+) += *([^;\n]+)( *;? *)/
		unless captures is null
			name = captures[1]
			val = captures[2]
			@tok "code", "var " + name + " = (" + val + ");"

	
	#Call mixin
	call: ->
		captures = @capture /^\+([\-\w]+)/
		unless captures is null
			tok = @tok("call", captures[1])
			
			# Check for args (not attributes)
			if captures = /^ *\((.*?)\)/.exec(@input)
				unless /^ *[\-\w]+ *=/.test(captures[1])
					@consume captures[0].length
					tok.args = captures[1]
			tok


	mixin: ->
		captures = @capture /^mixin +([\-\w]+)(?: *\((.*)\))?/
		unless captures is null
			tok = @tok("mixin", captures[1])
			tok.args = captures[2]
			tok


	conditional: ->
		captures = @capture /^(if|unless|else if|else)\b([^\n]*)/
		unless captures is null
			type = captures[1]
			js = captures[2]
			switch type
				when "if"
					js = "if (" + js + ")"
				when "unless"
					js = "if (!(" + js + "))"
				when "else if"
					js = "else if (" + js + ")"
				when "else"
					js = "else"
			@tok "code", js


	while: ->
		captures = @capture /^while +([^\n]+)/
		unless captures is null
			@tok "code", "while (" + captures[1] + ")"


	each: ->
		captures = @capture /^(?:- *)?(?:each|for) +(\w+)(?: *, *(\w+))? * in *([^\n]+)/
		unless captures is null
			tok = @tok("each", captures[1])
			tok.key = captures[2] or "$index"
			tok.code = captures[3]
			tok


	code: ->
		captures = @capture /^(!?=|-)([^\n]+)/
		unless captures is null
			flags = captures[1]
			captures[1] = captures[2]
			tok = @tok("code", captures[1])
			tok.escape = flags.charAt(0) is "="
			tok.buffer = flags.charAt(0) is "=" or flags.charAt(1) is "="
			tok


	attrs: ->
		if "(" is @input.charAt(0)

			index = @indexOfDelimiters("(", ")")
			str = @input.substr(1, index - 1)
			tok = @tok("attrs")
			len = str.length
			states = ["key"]
			escapedAttr = undefined
			key = ""
			val = ""
			quote = undefined
			c = undefined
			p = undefined
			@consume index + 1
			tok.attrs = {}
			tok.escaped = {}

			state = ->
				states[states.length - 1]

			interpolate = (attr) ->
				attr.replace /(\\)?#\{([^}]+)\}/g, (match, escape, expr) ->
					return (
						if escape
							match
						else
							quote + " + (" + expr + ") + " + quote
					)

			parse = (c) ->
				real = c

				switch c
					when ",", "\n"
						switch state()
							when "expr", "array", "string", "object"
								val += c
							else
								states.push "key"
								val = val.trim()
								key = key.trim()
								return if "" is key
								key = key.replace(/^['"]|['"]$/g, "").replace("!", "")
								tok.escaped[key] = escapedAttr
								tok.attrs[key] = (if "" is val then true else interpolate(val))
								key = val = ""
					when "="
						switch state()
							when "key char"
								key += real
							when "val", "expr", "array", "string", "object"
								val += real
							else
								escapedAttr = "!" isnt p
								states.push "val"
					when "("
						states.push "expr" if "val" is state() or "expr" is state()
						val += c
					when ")"
						states.pop() if "expr" is state() or "val" is state()
						val += c
					when "{"
						states.push "object" if "val" is state()
						val += c
					when "}"
						states.pop() if "object" is state()
						val += c
					when "["
						states.push "array" if "val" is state()
						val += c
					when "]"
						states.pop() if "array" is state()
						val += c
					when "\"", "'"
						switch state()
							when "key"
								states.push "key char"
							when "key char"
								states.pop()
							when "string"
								states.pop() if c is quote
								val += c
							else
								states.push "string"
								val += c
								quote = c
					when ""
					else
						switch state()
							when "key", "key char"
								key += c
							else
								val += c
				p = c


			for char in str.split ''
				parse char

			parse ","

			if "/" is @input.charAt(0)
				@consume 1
				tok.selfClosing = true
			tok


	
	#Indent | Outdent | Newline
	indent: ->
		re = undefined
		
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
			tok = undefined
			indents = captures[1].length
			++@lineno
			@consume indents + 1
			throw new Error("Invalid indentation, you can use tabs or spaces but not both") if " " is @input[0] or "\t" is @input[0]
			
			# blank line
			return @tok("newline") if "\n" is @input[0]
			
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
				tok = @tok("newline")
			tok

	
	#Pipe-less text consumed only when `pipeless` is true
	pipelessText: ->
		if @pipeless
			return if "\n" is @input[0]
			i = @input.indexOf("\n")
			i = @input.length if -1 is i
			str = @input.substr(0, i)
			@consume str.length
			@tok "text", str

	
	#':'
	colon: ->
		@scan /^: */, ":"

	
	###
	Return the next token object, or those
	previously stashed by lookahead.
	
	@return {Object}
	@api private
	###
	advance: ->
		@stashed() or @next()

	
	###
	Return the next token object.
	
	@return {Object}
	@api private
	###
	next: ->
		@deferred() or
		@blank() or
		@eos() or
		@pipelessText() or
		@yield() or
		@doctype() or
		@interpolation() or
		@case() or
		@when() or
		@default() or
		@extends() or
		@append() or
		@prepend() or
		@block() or
		@include() or
		@mixin() or
		@call() or
		@conditional() or
		@each() or
		@while() or
		@assignment() or
		@tag() or
		@filter() or
		@code() or
		@id() or
		@className() or
		@attrs() or
		@indent() or
		@comment() or
		@colon() or
		@text()


exports = module.exports = Lexer