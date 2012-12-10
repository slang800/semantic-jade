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
	# check for null/undefined
	if str is null or not str? or /undefined|null/i.test(str)
		return '\'\''

	if typeof str is 'boolean' or /(true|false)/i.test(str)
		return Boolean(str)

	# check for numbers
	return Number(str) unless isNaN(Number(str))

	remaining = str
		.replace(/\\/g, '_BSLASH_')
		.replace(/"/g, '_DBLQUOTE_')
	processed = ''

	loop
		for flag in ['#','!']
			if start_pos = remaining.indexOf(flag + '{') + 1 then break
			# `+ 1` accounts for the length of the flag

		unless start_pos
			break

		processed += remaining.substring(0, start_pos - 1)
		# `- 1` accounts for the length of the flag

		remaining = remaining.substring(start_pos)

		matches = match_delimiters(remaining, '{', '}')

		unless matches
			break

		# convert all the slashes in the interpolated part back to regular
		code = matches[1]
			.replace(/_BSLASH_/g, '\\')
			.replace(/_DBLQUOTE_/g, '"')

		processed += '#{' + "#{
			if '!' is flag
				'escape'
			else
				''
		}(if (interp = #{code}) is null or not interp? then '' else interp)" + '}'

		remaining = remaining.substring(matches[0].length)

	# escape any slashes that were not in the interpolated parts
	return (processed + remaining)
		.replace(/_BSLASH_/g, '\\\\')
		.replace(/_DBLQUOTE_/g, '\\"')

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
 * We do not include matched delimiters like `()` or `{}` (depending on the
   specified delimeter) or delimiters contained in quotation marks `"("`. We
   also ignore newlines. Otherwise, this is similar to using
   `/\((.*)\)/.exec()`
 * This can also be called with start_delimeter as null to get the next
   occurance of an end_delimiter while excluding the cases mentioned above
 * @param {String} str
 * @param {String} start_delimiter
 * @param {String, Array} end_delimiters
 * @return {Array} similar to the output of a regex
 * @private
###
exports.match_delimiters = match_delimiters = (str, start_delimiter='(', end_delimiters= ')') ->
	startpos = -1
	while str[++startpos] is ' '
		continue # consume whitespace at start of string
	if (start_delimiter isnt '') and (str[startpos] isnt start_delimiter)
		return null
	if typeof end_delimiters is 'string'
		# end_delimiters can be an array of possible delimeters or a string.
		# make into a array if only a string is given
		end_delimiters = [end_delimiters]
	endpos = startpos - 1 # pass over the first char too
	ctr = 1
	chr = ''
	quot = ''
	len = str.length - 1
	skip = false
	while (ctr > 0) and (endpos < len)
		chr = str[++endpos]
		if skip
			skip = false
		else if chr is '\\'
			skip = true
		else if chr in ['\'', '\"', '[', ']', '{', '}']
			if chr is quot or (quot is '[' and chr is ']') or (quot is '{' and chr is '}')
				quot = ''
			else if quot is ''
				quot = chr
			#ignore if it's already inside quotes
		else if chr is start_delimiter
			++ctr unless quot
		else if chr in end_delimiters
			--ctr unless quot

	#chr will be the end_delimiter that ended the string
	[str.substring(0, endpos + chr.length), str.substring(startpos + start_delimiter.length, endpos)]

###
Escape the given string of `html`.

@param {String} html
@return {String}
@private
###
exports.escape = (html) ->
	String(html)
		.replace /&/g, '&amp;'
		.replace /</g, '&lt;'
		.replace />/g, '&gt;'
		.replace /"/g, '&quot;'

Array::remove = (from, to) ->
	rest = @slice((to or from) + 1 or @length)
	@length = (if from < 0 then @length + from else from)
	@push.apply @, rest