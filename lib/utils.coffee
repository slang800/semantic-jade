# Regex-matching-regexes.
REGEX = /// ^
	(/ (?! [\s=] )   # disallow leading whitespace or equals signs
	[^ [ / \n \\ ]*  # every other thing
	(?:
		(?: \\[\s\S]   # anything escaped
			| \[       # character class
					 [^ \] \n \\ ]*
					 (?: \\[\s\S] [^ \] \n \\ ]* )*
				 ]
		) [^ [ / \n \\ ]*
	)*
	/) ([imgy]{0,4}) (?!\w)
///

HEREGEX = /// ^ /{3} ([\s\S]+?) /{3} ([imgy]{0,4}) (?!\w) ///

###*
 * Matches a balanced group such as a single or double-quoted string. Pass in
 * a series of delimiters, all of which must be nested correctly within the
 * contents of the string. This method allows us to have strings within
 * interpolations within strings, ad infinitum.
 * @param {String} str The string to balance
 * @param {String} end The character that ends the balanced string
 * @return {String} The balanced string with both delimiters still wrapping it
 * @private
###
exports.balance_string = balance_string = (str, end) ->
	continueCount = 0
	stack = [end]
	for i in [1...str.length]
		if continueCount
			--continueCount
			continue
		switch letter = str.charAt i
			when '\\'
				++continueCount
				continue
			when end
				stack.pop()
				unless stack.length
					return str[0..i]
				end = stack[stack.length - 1]
				continue
		if end is '}' and letter in ['"', "'"]
			stack.push end = letter
		else if end is '}' and letter is '/' and match = (HEREGEX.exec(str[i..]) or REGEX.exec(str[i..]))
			continueCount += match[0].length - 1
		else if end is '}' and letter is '{'
			stack.push end = '}'
		else if end is '"' and prev in ['#','!'] and letter is '{'
			stack.push end = '}'
		prev = letter
	throw new Error "missing #{ stack.pop() }, starting"

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
 * Escape double quotes in `str` and convert `!{}` interpolation into standard
   coffee `#{escape()}`. Quotes don't need to be escaped if they are in
   interpolated sections.
 * @param {String} str
 * @return {String}
 * @private
###
exports.process_str = (str) ->
	output = ''
	loop
		if match = /(?:#|!){/.exec(str)
			i = match.index
		else
			#nothing found, escape the rest of the string
			i = str.length

		output += str[0...i]
			.replace(/\\/g, '\\\\')
			.replace(/"/g, '\\"')
			.replace(/\n/g,'\\n')
			.replace(/\t/g,'\\t')

		str = str[i..] # cut off outputted part

		if str is ''
			return output

		if match
			interp_part = balance_string str[1..], '}'
			# remove the interpolated_part from the rest of the string
			str = str[interp_part.length + 1..]
		
			if match[0] is '!{'
				# cut off the delimiters & replace with vanilla coffee
				interp_part = '{escape(' + interp_part[1...-1] + ')}'

			output += '#' + interp_part

			if str is ''
				#replace with literal versions to prevent indentation of code
				#from mixing w/ multi-line strings
				return output

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
   specified delimiter) or delimiters contained in quotation marks `"("`. We
   also ignore newlines. Otherwise, this is similar to using
   `/\((.*)\)/.exec()`
 * This can also be called with start_delimeter as null to get the next
   occurrence of an end_delimiter while excluding the cases mentioned above
 * @param {String} str
 * @param {String} start_delimiter
 * @param {Array} end_delimiters
 * @return {Array} similar to the output of a regex
 * @private
 * @deprecated mostly replaced with balance_string()
###
exports.match_delimiters = match_delimiters = (str, start_delimiter, end_delimiters) ->
	startpos = -1
	while str[++startpos] is ' '
		continue # consume whitespace at start of string
	if str[startpos...startpos + start_delimiter.length] isnt start_delimiter
		return null
	else
		startpos += start_delimiter.length - 1
		endpos = startpos

	ctr = 1
	chr = quot = ''
	len = str.length - 1
	while (ctr > 0) and (endpos < len)
		chr = str[++endpos]
		if chr is '\\'
			++endpos # skip next char
		else if chr in ['\'', '\"', '[', ']', '{', '}']
			if chr is quot or (quot is '[' and chr is ']') or (quot is '{' and chr is '}')
				quot = ''
			else if quot is '' and chr not in [']', '}']
				quot = chr
			#ignore if it's already inside quotes
		else if str[endpos...start_delimiter.length - 1] is start_delimiter
			endpos += start_delimiter.length
			++ctr unless quot
		else if chr in end_delimiters
			--ctr unless quot
	
	if startpos < 0 then startpos = 0
	#chr will be the end_delimiter that ended the string
	[
		str[...endpos + chr.length]
		str[startpos + start_delimiter.length...endpos]
	]

###
Escape the given string of `html`.

@param {String} html
@return {String}
@private
###
exports.escape = (html) ->
	if typeof html is 'string'
		return html
			.replace(/&/g, '&amp;')
			.replace(/"/g, '&quot;')
			.replace(/</g, '&lt;')
			.replace(/>/g, '&gt;')

Array::remove = (from, to) ->
	rest = @slice((to or from) + 1 or @length)
	@length = (if from < 0 then @length + from else from)
	@push.apply @, rest