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

MATCHING_DELIMITER = {
	'{': '}',
	'[': ']',
	'(': ')',
	'\"': '\"',
	'\'': '\'',
}

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
balance_string = (str, end=MATCHING_DELIMITER[str[0]]) ->
	continueCount = 0
	stack = [end]
	for i in [1...str.length]
		if continueCount
			--continueCount
			continue
		letter = str.charAt i
		if letter is '\\'
			++continueCount
			continue
		if letter is end
			stack.pop()
			unless stack.length
				return str[0..i]
			end = stack[stack.length - 1]
			continue

		if end in [']', '}', ')']
			if letter in ['\"', '\'']
				stack.push end = letter
			else if letter in ['[', '{', '('] and end is MATCHING_DELIMITER[letter]
				stack.push end
			else if letter is '/' and match = (HEREGEX.exec(str[i..]) or REGEX.exec(str[i..]))
				continueCount += match[0].length - 1
		else if end is '"' and prev in ['#','!'] and letter is '{'
			stack.push end = '}'
		prev = letter
	throw new Error "missing #{stack.pop()}, starting"

exports.balance_string = balance_string

###*
 * Search through a string until an end delimiter is found, but ignore
   characters within balanced groups, like quoted strings within the string
   being matched.
 * @param {String} str The string to search in.
 * @param {Array} end The end delimiters to look for
 * @return {String} All of the characters from the beginning of the string to
   the first valid end delimiter that is found (including the end delimiter).
   Each delimiter must have a length > 0
###
search = (str, end) ->
	while i < str.length
		for delimiter in end
			if str[i...i + delimiter.length] is delimiter
				return str[0...i + delimiter.length]

	if end.length > 1
		searched_for = end[0...-1].join('", "') + '", or "' + end[-1..]
	else
		searched_for = end[0]
	searched_for = "\"#{searched_for}\""

	throw new Error "could not find #{searched_for}"

exports.search = search

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
			interp_part = balance_string str[1..]
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