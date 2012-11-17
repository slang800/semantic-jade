###*
 * Indent a string by adding indents before each newline in the string
 * @param {String} str
 * @return {String}
 * @private
###
exports.indent = (str, indents = 1) ->
	indentation = Array(indents + 1).join('\t')
	return indentation + str.replace /\n/g, '\n' + indentation

###*
 * Escape double quotes in `str`.
 * @param {String} str
 * @return {String}
 * @private
###
exports.escape_quotes = (str) ->
	str.replace /"/g, "\\\""

###*
 * Convert interpolation in the given string to CoffeeScript
 * @param {String} str
 * @return {String}
 * @private
###
exports.interpolate = (str) ->
	str = str.replace(/\\/g, '_SLASH_')

	str = str.replace(
		/([#!]){(.*?)}/g,
		(str, flag, code) ->
			# convert all the slashes & quotes in the interpolated parts back to regular
			code = code.replace(/_SLASH_/g, "\\")

			'#{' + "#{
				if '!' is flag
					''
				else
					'escape'
			}(if (interp = #{code}) is null then '' else interp)" + '}'
	)

	# escape any slashes that are not in the interpolated part
	return str.replace(/_SLASH_/g, '\\\\')


###*
 * Merge `b` into `a`.
 * @param {Object} a
 * @param {Object} b
 * @return {Object}
 * @public
###
exports.merge = (a, b) ->
	for key of b
		a[key] = b[key]
	a

###*
 * Match everything in parentheses.
 * We do not include matched delimiters (like "()" or "{}") or delimiters
   contained in quotation marks "(". We also ignore newlines. Otherwise,
   this is similar to using /\((.*)\)/.exec()
 * @param {String} input
 * @return {Array} similar to the output of a regex
 * @private
###
exports.match_delimiters = match_delimiters = (str, start_delimiter='(', end_delimiter=')') ->
	startpos = -1
	while str[++startpos] is ' '
		continue # consume whitespace at start of string
	if str[startpos] isnt start_delimiter
		return null
	endpos = startpos
	ctr = 1
	chr = ''
	quot = ''
	len = str.length - 1
	skip = false
	while (ctr > 0) and (endpos < len)
		chr = str[++endpos]
		if skip
			skip = false
			continue
		switch chr
			when '\\'
				skip = true
			when '\'', '\"'
				if chr is quot
					quot = ''
				else quot = chr if '' is quot
			when start_delimiter
				++ctr unless quot
			when end_delimiter
				--ctr unless quot

	[str.substring(0, endpos + 1), str.substring(startpos + 1, endpos)]

Array::remove = (from, to) ->
	rest = @slice((to or from) + 1 or @length)
	@length = (if from < 0 then @length + from else from)
	@push.apply @, rest