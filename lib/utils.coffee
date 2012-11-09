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
Escape single quotes in `str`.

@param {String} str
@return {String}
@api private
###
exports.escape = (str) ->
	str.replace /'/g, "\\'"

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