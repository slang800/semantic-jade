###
Indent a string by adding indents before each newline in the string

@param {String} str
@return {String}
@private
###
exports.indent = (str, indents = 1) ->
	indentation = Array(indents + 1).join('\t')
	return indentation + str.replace /\n/g, '\n' + indentation

###
Escape double quotes in `str`.

@param {String} str
@return {String}
@api private
###
exports.escape_quotes = (str) ->
	str.replace /"/g, "\\\""

###
Convert interpolation in the given string to JavaScript.

@param {String} str
@return {String}
@api private
###
interpolate = exports.interpolate = (str) ->
	str = str
		.replace(/\\/g, '_SLASH_')

	str = str.replace(
		/([#!]){(.*?)}/g,
		(str, flag, code) ->
			# convert all the slashes & quotes in the interpolated parts back to regular
			code = code
				.replace(/_SLASH_/g, "\\")

			'#{' + "#{
				if '!' is flag
					''
				else
					'escape'
			}(if (interp = #{code}) is null then '' else interp)" + '}'
	)

	# escape any slashes that are not in the interpolated part
	return str
		.replace(/_SLASH_/g, '\\\\')


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

Array::remove = (from, to) ->
	rest = @slice((to or from) + 1 or @length)
	@length = (if from < 0 then @length + from else from)
	@push.apply @, rest