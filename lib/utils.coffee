###
Convert interpolation in the given string to JavaScript.

@param {String} str
@return {String}
@api private
###
interpolate = exports.interpolate = (str) ->
	str.replace /(_SLASH_)?([#!]){(.*?)}/g, (str, escape, flag, code) ->
		code = code.replace(/\\'/g, "'").replace(/_SLASH_/g, "\\")
		
		if escape
			return str.slice(7)
		else
			return "' + #{if "!" is flag then "" else "escape"}((interp = #{code}) == null ? '' : interp) + '"

###
Indent all lines in a given string

@param {String} str
@return {String}
@private
###
exports.indent = (str) ->
	'\t' + str.replace /\n/g, '\n\t'

###
Escape single quotes in `str`.

@param {String} str
@return {String}
@api private
###
escape = exports.escape = (str) ->
	str.replace /'/g, "\\'"


###
Interpolate, and escape the given `str`.

@param {String} str
@return {String}
@api private
###
exports.text = (str) ->
	interpolate escape(str)


###
Merge `b` into `a`.

@param {Object} a
@param {Object} b
@return {Object}
@api public
###
exports.merge = (a, b) ->
	for key of b
		a[key] = b[key]
	a
