coffee_compile = require("coffee-script").compile
fs = require "fs"

exports.selfClosing = require "./self-closing"
exports.doctypes = require "./doctypes"
exports.utils = utils = require "./utils"
exports.Compiler = Compiler = require "./compiler"
exports.Parser = Parser = require "./parser"
exports.Lexer = Lexer = require "./lexer"
exports.nodes = require "./nodes"
exports.runtime = runtime = require "./runtime"
exports.cache = {} #Template function cache

###*
 * Parse the given `str` of jade and return a function body.
 * @param {String} str
 * @param {Object} options
 * @return {String}
 * @private
###
parse = (str, options) ->
	try
		# Parse
		parser = new Parser(str, options.filename, options)
		
		# Compile
		if not options.compiler?
			compiler = new Compiler(parser.parse(), options)
		else
			compiler = new options.compiler(parser.parse(), options)

		js = utils.indent compiler.compile()
		
		# Debug compiler
		if options.debug
			console.error(
				"\nCompiled Function:\n\n\u001b[90m%s\u001b[0m",
				js.replace(/^/g, "  ")
			)

		return """
		buf = []
		_with = (object, block) -> block.call object
		#{
			if options.self
				"self = locals || {}\n#{js}"
			else
				"_with (locals || {}), ->\n#{js}"
		}
		return buf.join('')
		"""
	catch err
		parser = parser.context()
		runtime.rethrow err, parser.filename, parser.lexer.lineno

###*
 * Strip any UTF-8 BOM off of the start of `str`, if it exists.
 * @param {String} str
 * @return {String}
 * @private
###
stripBOM = (str) ->
	if 0xFEFF is str.charCodeAt(0) then str[1..] else str

###*
 * Compile a `Function` representation of the given jade `str`.
 * Options:
 *     - `compileDebug` when `false` debugging code is stripped from the
       compiled template
 *     - `client` when `true` the helper functions `escape()` etc will
       reference `jade.escape()`
 * for use with the Jade client-side runtime.js
 * @param {String} str
 * @param {Options} options
 * @return {Function}
 * @private
###
exports.compile = (str, options) ->
	options = options or {}
	client = options.client
	filename = (
		if options.filename
			JSON.stringify(options.filename)
		else
			'undefined'
	)

	str = stripBOM(String(str))
	fn = parse(str, options)

	if options.compileDebug isnt false
		# wrap in try / catch for debugging
		fn = """
		__jade = [{ lineno: 1, filename: #{filename} }]
		try
		#{utils.indent fn}
		catch err
			rethrow(err, __jade[0].filename, __jade[0].lineno)
		"""

	if client
		fn = """
		attrs = attrs or jade.attrs
		escape = escape or jade.escape
		rethrow = rethrow or jade.rethrow
		merge = merge or jade.merge
		#{fn}
		"""

	fs.writeFileSync("test_out.coffee", fn) # remove
	fn = coffee_compile fn, {bare: true}
	fs.writeFileSync("test_out.js", fn) # remove

	fn = new Function('locals, attrs, escape, rethrow, merge', fn)
	return fn if client

	(locals) ->
		fn locals, runtime.attrs, runtime.escape, runtime.rethrow, runtime.merge

###*
 * Render the given `str` of jade and invoke the callback `fn(err, str)`.
 * Options:
 *    - `cache` enable template caching
 *    - `filename` filename required for `include` / `extends` and caching
 * @param {String} str
 * @param {Object|Function} options or fn
 * @param {Function} fn
 * @private
###
exports.render = (str, options, fn) ->
	# swap args
	if "function" is typeof options
		fn = options
		options = {}
	
	# cache requires .filename
	if options.cache and not options.filename
		return fn(new Error('the "filename" option is required for caching'))
	try
		path = options.filename
		tmpl = (
			if options.cache
				exports.cache[path] or (exports.cache[path] = exports.compile(str, options))
			else
				exports.compile(str, options)
		)
		fn null, tmpl(options)
	catch err
		fn err

###*
 * Render a Jade file at the given `path` and callback `fn(err, str)`.
 * @param {String} path
 * @param {Object|Function} options or callback
 * @param {Function} fn
 * @private
###
exports.renderFile = (path, options, fn) ->
	key = path + ":string"
	if typeof options is 'function'
		fn = options
		options = {}
	try
		options.filename = path
		str = (
			if options.cache
				exports.cache[key] or (exports.cache[key] = fs.readFileSync(path, "utf8"))
			else
				fs.readFileSync(path, "utf8")
		)
		exports.render str, options, fn
	catch err
		fn err

#Express support
exports.__express = exports.renderFile
